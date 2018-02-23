module Pod
  class Command
    class Ip < Command
      #-----------------------------------------------------------------------#
      #Get a IP + shell from repository
      #-----------------------------------------------------------------------#
      class Get < Ip
        self.summary = 'Download an IP and as well as a compatible shell.'

        self.description = <<-DESC
          Download the IP from one or multiple IP_REPO_NAME(s).
          For each IP, a IP_REPO_VERSION tag can be specified (optional) like [IP_REPO_NAME:IP_REPO_VERSION].
          You can specify a shell using [--shell=SHELL_REPO_NAME] option,  set to "no" if only IP is needed. 
          A [--Y] flag can be applied to use a default shell.
        DESC

        self.arguments = [
          CLAide::Argument.new('IP_REPO_NAME [IP_REPO_NAME] ...', true),
          CLAide::Argument.new('--shell=SHELL_REPO_NAME', false),
          CLAide::Argument.new('--Y', false),
        ]

        def initialize(argv)
          @ip_names = argv.arguments!
          @shell_name = argv.option('shell')
          @yes_download_any_shell = argv.flag?('Y')
          @ip_names.each{
            argv.shift_argument
          }
          super
        end

        def validate!
          super
          help! 'A url for the IP repo is required.' if @ip_names.length <= 0
        end

        def run
          @hcode_file = Hash.new
	        @hcode_file["ip"] = Hash.new
          #Get IPs
          ch_num = 1
          @ip_names.each{|ip_string|
            if(ip_string.include?":")
              repo_name = ip_string.split(":")[0]
              repo_tag = ip_string.split(":")[1]
            else
              repo_name = ip_string
            end
            url = repo_from_name(repo_name, "")
            if !url
              UI.puts "IP #{ip_string} is not found in repo.".red
              exit
            end 
            repo_tag = url["tag"] unless repo_tag

            hcode_item = Hash.new
            hcode_item["name"] = repo_name
            hcode_item["tag"] = repo_tag
            hcode_item["ip_conf"] = ""
            hcode_item["shell_conf"] = ""
            @hcode_file["ip"]["#{ch_num}"] = hcode_item
          
            UI.puts "hCODE: (#{Time.now.to_s}) Get IP #{repo_name}:#{repo_tag}".green

            if(@shell_name == "no")
              clone(url["git"], repo_tag, "#{repo_name}")
            else
              clone(url["git"], repo_tag, "ch#{ch_num}-#{repo_name}")
            end
            ch_num = ch_num + 1
          }

          exit if(@shell_name == "no")

          if(@shell_name)
            #Get specified shell
            if(@shell_name.include?":")
              repo_name = @shell_name.split(":")[0]
              repo_tag = @shell_name.split(":")[1]
            else
              repo_name = @shell_name
            end

            url = repo_from_name(repo_name, "")
            repo_tag = url["tag"] unless repo_tag
            UI.puts "hCODE: (#{Time.now.to_s}) Get shell #{repo_name}:#{repo_tag}".green
            clone(url["git"], repo_tag, "#{repo_name}")

            hcode_item = Hash.new
            hcode_item["name"] = repo_name
            hcode_item["tag"] = repo_tag
            json = File.read("#{repo_name}/hcode.spec")
            spec = JSON.parse(json)
            hcode_item["hardware"] = spec["hardware"]
            hcode_item["conf"] = ""
            @hcode_file["shell"] = hcode_item
            if(spec.has_key?"compatible_shell")
              @hcode_file["shell"]["compatible_shell"] = spec["compatible_shell"].keys[0]
            end
          else
            #Get shell from IP spec
            specs_from_ip
          end

          if (@hcode_file["shell"]["compatible_shell"] == "")
            if(@shell_name)
                shell_in_ip_spec = @shell_name
            else
            	shell_in_ip_spec = @hcode_file["shell"]["name"]
            end
          else
            shell_in_ip_spec = @hcode_file["shell"]["compatible_shell"]
          end

          @hcode_file["ip"].each{ |channel,ip|
              #Get IP configurations for selected shell
              json = File.read("ch#{channel}-#{ip["name"]}/hcode.spec")
              spec = JSON.parse(json)

              spec["shell"][shell_in_ip_spec]["ip_conf"].each{|key, value|
                ip["ip_conf"] += "-#{key} \'#{value}\' "
              }
              ip["ip_conf"] += "-device \'#{@hcode_file["shell"]["hardware"]["device"]}\' "

              ip["shell_conf"] += "-channel \'$ch_num\' "
              spec["shell"][shell_in_ip_spec]["shell_conf"].each{|key, value|
                ip["shell_conf"] += "-#{key} \'#{value}\' "
              }
          }

          require 'json'
          File.open("hcode", 'w') do |file|
            json_str = JSON.pretty_generate(@hcode_file)
            str = file.write(json_str)
          end

          UI.puts ""
          UI.puts "hCODE: (#{Time.now.to_s}) Get success, next you can use \"hcode ip make .\" to compile.".green
        end

        #----------------------------------------#

        # !@group Private helpers
        extend Executable
        executable :git

        def repo_from_name(name, option)
          UI.puts "#{name}#{option}"
          begin
            set = SourcesManager.fuzzy_search_by_name(name)
            set.repo_url
          rescue => e
            UI.puts "Error: Can not find repo for #{name}.".red
            nil
          end
        end

        def specs_from_ip
          UI.puts "Finding compabile shells...".green

          #Read hcode.spec and parse JSON
          json = File.read("ch1-#{@ip_names[0].split(":")[0]}/hcode.spec")
          spec = JSON.parse(json)
          shells = Array.new
          menu = Array.new

          if(spec["type"] == "shell")
            UI.puts "The target is a shell project, please use \"hCODE shell get\" command.".red
            exit
          end

          keys = spec["shell"].keys
              
          #Get shell URLs. If multiple shells are provided, let user choose one.
          spec["shell"].each_with_index{|shell, i|
                if(@ip_names.length > 1)
                  next if !keys[i].include?("#{@ip_names.length}ch")
                end
                repo_url = repo_from_name(keys[i], "")
                if(repo_url != nil)
                  shell_item = Hash.new
                  shell_item["name"]  = keys[i]
                  shell_item["url"]  = repo_url
                  shell_item["compatible_shell"]  = ""
                  shells.push shell_item

                  menu.push "#{shell_item["name"]} : #{shell_item["url"]["tag"]}"
                end
          }

          #Find compatible shells
          spec["shell"].each_with_index{|shell, i|
            compatible_shell = SourcesManager.get_compatible_shell(keys[i])
            if (compatible_shell != nil)
              compatible_shell.each{|k,v|
                if(@ip_names.length > 1)
                  next if !v.include?("#{@ip_names.length}ch")
                else
                  next if v.include?("ch")
                end
                if (!keys.include?k)
                  keys.push k
                  repo_url = repo_from_name(k, "(#{v})")

                  if(repo_url != nil)
                    shell_item = Hash.new
                    shell_item["name"]  = k
                    shell_item["url"]  = repo_url
                    shell_item["compatible_shell"]  = keys[i]
                    shells.push shell_item

                    menu.push "#{shell_item["name"]} : #{shell_item["url"]["tag"]}"
                  end
                end
              }
            end
          }
          menu.push "No Shell"
 
          #Select a shell from compatible shell list
          url_index = 0
          if(!@yes_download_any_shell)
            if menu.length > 1
              message = "Select a shell from the above list:".green
              url_index = UI.choose_from_array(menu, message)
            end
          else
            url_index = 0
          end
          if url_index == menu.length - 1
            UI.puts "Only IP is donwloaded."
            exit
          end

          #Get IP configurations for selected shell
          @shell_name = shells[url_index]["name"]
          clone(shells[url_index]["url"]["git"], shells[url_index]["url"]["tag"], "#{@shell_name}")

          hcode_item = Hash.new
          hcode_item["name"] = @shell_name
          hcode_item["tag"] = shells[url_index]["url"]["tag"]
          json = File.read("#{@shell_name}/hcode.spec")
          spec = JSON.parse(json)
          hcode_item["hardware"] = spec["hardware"]
          hcode_item["compatible_shell"] = shells[url_index]["compatible_shell"]
          hcode_item["conf"] = ""
          @hcode_file["shell"] = hcode_item
        end

        # Clones the repo from the remote in the path directory using
        # the url, tag of IP repo.
        #
        # @return [void]
        #
        def clone(url, tag, dir)
          UI.section("Cloning #{url} of tag #{tag}.") do
            git! ['clone', url, dir]
            Dir.chdir(dir) { git!('checkout', "tags/#{tag}") } if tag
          end
        end

        # Runs the template configuration utilities.
        #
        # @return [void]
        #
        def print_info
          UI.puts "\nTo learn more about the ip see `#{@ip_url}`."
        end
      end
    end
  end
end
