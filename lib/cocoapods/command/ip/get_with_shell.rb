module Pod
  class Command
    class Ip < Command
      #-----------------------------------------------------------------------#
      #Get a IP + shell from repository
      #-----------------------------------------------------------------------#
      class GetWithShell < Ip
        self.summary = 'Download an IP and shell.'

        self.description = <<-DESC
          Download the IP from a given IP_REPO_NAME.
          Download the Shell from a given SHELL_REPO_NAME.
          A IP_REPO_VERSION tag can also be specified.
        DESC

        self.arguments = [
          CLAide::Argument.new('IP_REPO_NAME', true),
          CLAide::Argument.new('SHELL_REPO_NAME', true),
          CLAide::Argument.new('IP_REPO_VERSION', false),
          CLAide::Argument.new('SHELL_REPO_VERSION', false),
        ]

        def initialize(argv)
          @ip_name = argv.shift_argument
          @shell_name = argv.shift_argument
          @ip_tag = argv.shift_argument
          @shell_tag = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A url for the IP repo is required.' unless @ip_name
        end

        def run
          @acc_name = @ip_name
          url = repo_from_name(@ip_name, "")
          make_project_dir

          @ip_tag = url["tag"] unless @ip_tag

          UI.puts "Get ip #{@ip_name} ~> #{@ip_tag}".green
          clone(url["git"], @ip_tag, "#{@acc_name}/#{@ip_name}")
          
          url = repo_from_name(@shell_name, "")

          @shell_tag = url["tag"] unless @shell_tag

          UI.puts "Get shell #{@shell_name} ~> #{@shell_tag}".green
          clone(url["git"], @shell_tag, "#{@acc_name}/#{@shell_name}")
          
          

          UI.puts ""
          UI.puts "Success: IP:#{@ip_name} and Shell:#{@shell_name} are downloaded."
          UI.puts "Next, you can use \"hcode ip make #{@acc_name}\" to compile."
        end

        private

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
            UI.puts "Error: Can not find repo for shell #{name}.".red
            nil
          end
        end

        def make_project_dir
          FileUtils.mkdir_p("#{@acc_name}")
        end

        def specs_from_ip
          UI.puts "Get specs for #{@ip_name} ~> #{@ip_tag}".green

          #Read hcode.spec and parse JSON
          json = File.read("#{@acc_name}/#{@ip_name}/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new

          if(spec["type"] == "shell")
            UI.puts "The target is a shell project, please use \"hCODE shell get\" command.".red
            exit
          end

          keys = spec["shell"].keys
              
          #get shell URLs, if support multiple shells, let user choose one
          spec["shell"].each_with_index{|shell, i|
                repo_url = repo_from_name(keys[i], "")
                urls.push repo_url if repo_url != nil
          }

          spec["shell"].each_with_index{|shell, i|
            compatible_shell = getCompatibleShell(keys[i])
            if (compatible_shell != nil)
              compatible_shell.each{|k,v|
                if (!keys.include?k)
                  keys.push k
                  repo_url = repo_from_name(k, "(May compatible: #{v})")
                  urls.push repo_url if repo_url != nil
                end
              }
            end
          }

          urls.push "No Shell"
 
          url_index = 0
          if urls.length > 1
            message = "Choose a shell.".green
            url_index = UI.choose_from_array(urls, message)
          end

          if url_index == urls.length - 1
            UI.puts "Only IP is donwloaded."
            exit
          end

          #Get IP configurations for selected shell
          @shell_name = keys[url_index]
          clone(urls[url_index]["git"], urls[url_index]["tag"], "#{@acc_name}/#{@shell_name}")
        end

        def getCompatibleShell(shellname)
          json = File.read(File.expand_path("#{Dir.home}/.hcode/compatible_shell.json"))
          shells = JSON.parse(json)
          return shells[shellname]["compatible_shell"]
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
