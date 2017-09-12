module Pod
  class Command
    class Ip < Command
      #-----------------------------------------------------------------------#
      #Compile a IP
      #-----------------------------------------------------------------------#
      class Make < Ip
        self.summary = 'Make the downloaded IP automaticlly.'

        self.description = <<-DESC
          Make the downloaded IP automaticlly. A [--cache] flag can be applied to enable cache.
        DESC

        self.arguments = [
          CLAide::Argument.new('IP_REPO_NAME', true),
          CLAide::Argument.new('--nocache', false),
        ]

        def initialize(argv)
          @acc_name = argv.shift_argument
          @cache = argv.flag?('cache')
          super
        end

        def validate!
          super
          help! 'A name for the IP folder is required.' unless @acc_name
        end

        def run
          read_hcode_file
          make_ip
          copy_ip_verilog_to_shell
          make_shell
          cache_bitstream if @cache
        end

        private
        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def read_hcode_file
          require 'json'
          file = File.read('hcode')
          @hcode_file = JSON.parse(file)
          @shell_name = @hcode_file["shell"]["name"]
          @shell_tag = @hcode_file["shell"]["tag"]
          hcode_hash_string = ""
          @hcode_file["ip"].each{|ip_id, ip|
            hcode_hash_string = hcode_hash_string + "#{ip["name"]}#{ip["tag"]}#{ip["ip_conf"]}#{ip["shell_conf"]}"
          }
          @spec_hash = Digest::SHA256.hexdigest(hcode_hash_string)[0..9]
          @spec_cache = "#{Dir.home}/.hcode/cache/#{@spec_hash}"
          if (File.directory?(@spec_cache) && (@cache))
            FileUtils.cp_r "#{@spec_cache}/bitstream.bit", "."
            UI.puts "hCODE: (#{Time.now.to_s}) Bitstream cache of the same configuration(#{@spec_hash}) is found, copied to #{@shell_name}.".green
            exit
          end
        end

        def make_ip
          @ip_make_list = Hash.new

          #Search cache for IP of the same configuration.
          #If cache exist then use it, else make it.
          @hcode_file["ip"].each{ |channel,ip|
              #Use IP name, tag and ip_conf for HASH
              ip_hash = Digest::SHA256.hexdigest("#{ip["name"]}#{ip["tag"]}#{ip["ip_conf"]}")[0..9]
              ip["cache_hash"] = ip_hash
              ip_folder = "ch#{channel}-#{ip["name"]}"
              ip_cache = "#{Dir.home}/.hcode/cache/#{ip["cache_hash"]}"

              if ((!File.directory?(ip_cache)) || (!@cache))
                if !File.directory?(@shell_name)
                  system "hcode ip get #{ip["name"]}:#{ip["tag"]} --shell=no"
                  system "mv #{ip["name"]} ch#{channel}-#{ip["name"]}"
                end

                hcode_log = "#{ip_folder}/hcode.log"
                File.open(hcode_log, 'w') do |file|
                  json_str = JSON.pretty_generate(ip)
                  str = file.write(json_str)
                end

                ip_name_with_hash = "#{ip["name"].gsub('-','_')}_#{ip["cache_hash"]}"

                cmd = "cd #{ip_folder} && ./configure #{ip["ip_conf"]} -ip_name #{ip_name_with_hash} > configure.log 2>&1"
                UI.puts "hCODE: (#{Time.now.to_s}) Configuring IP #{ip["name"]}.".green
                UI.puts cmd
                system cmd
                cmd = "cd #{ip_folder} && ./make #{ip["ip_conf"]} > make.log 2>&1"
                UI.puts "hCODE: (#{Time.now.to_s}) Making IP #{ip["name"]}.".green
                UI.puts cmd
                system cmd

                if @cache
                  FileUtils::mkdir_p ip_cache
                  FileUtils.cp_r "ch#{channel}-#{ip["name"]}/.", ip_cache
                end
              else
                if @cache
                  UI.puts "hCODE: (#{Time.now.to_s}) Cache for #{ip["name"]} of the same configuration exists (#{ip_hash}).".green
                  FileUtils.rm_rf(ip_folder)
                  FileUtils::mkdir_p ip_folder
                  FileUtils.cp_r "#{ip_cache}/.", "#{ip_folder}"
                  UI.puts "hCODE: (#{Time.now.to_s}) Copy #{ip_folder} from cache (#{ip["cache_hash"]}).".green
                end
              end

              hcode_log_file = "#{ip_folder}/hcode.log"
              hcode_log = JSON.parse(File.read(hcode_log_file))
              @hcode_file["ip"]["#{channel}"]["resource"] = hcode_log["resource"]
              @hcode_file["ip"]["#{channel}"]["make_user"] = ENV['USER']
              @hcode_file["ip"]["#{channel}"]["make_date"] = Time.new.strftime("%Y-%m-%d %H:%M:%S")
          }

          File.open("hcode", 'w') do |file|
            json_str = JSON.pretty_generate(@hcode_file)
            str = file.write(json_str)
          end
        end

        def copy_ip_verilog_to_shell
          if !File.directory?(@shell_name)
            system "hcode shell get #{@shell_name} #{@shell_tag}"
          end

          UI.puts "hCODE: (#{Time.now.to_s}) Removing previous IPs from shell.".green
          system "cd #{@shell_name} && ./make -removeip > make_removeip.log 2>&1"
          system "cd #{@shell_name}/ip-src/ && rm -rf */"

          ins_num = Hash.new
          UI.puts "hCODE: (#{Time.now.to_s}) Copy and append IPs to shell.".green
          @hcode_file["ip"].each{ |channel,ip|
              ip_hash = Digest::SHA256.hexdigest("#{ip["name"]}#{ip["tag"]}#{ip["ip_conf"]}")[0..9]
              ip_name_with_hash = "#{ip["name"].gsub('-','_')}_#{ip_hash}"
              if ins_num[ip_hash] == nil
                ins_num[ip_hash] = 0 
              else
                ins_num[ip_hash] = ins_num[ip_hash] + 1
              end
              ip["shell_conf"].gsub!("$ip_name", ip_name_with_hash)
              ip["shell_conf"].gsub!("$instance_name", "#{ip_name_with_hash}_#{ins_num[ip_hash]}")
              ip["shell_conf"].gsub!("$ch_num", "#{channel}")

              system "cd #{@shell_name} && ./configure #{ip["shell_conf"]}"

              ip_folder = "ch#{channel}-#{ip["name"]}"
              next if File.directory?("#{@shell_name}/ip-src/#{ip_name_with_hash}")
              FileUtils.mkdir_p "#{@shell_name}/ip-src/#{ip_name_with_hash}"

              ip_type = ""
              if File.directory?("#{ip_folder}/output/dcp")
                ip_type = "dcp"
                system "cp -r #{ip_folder}/output/dcp/* #{@shell_name}/ip-src/#{ip_name_with_hash}"
                UI.puts "hCODE: (#{Time.now.to_s}) cp -r #{ip_folder}/output/dcp/* #{@shell_name}/ip-src/#{ip_name_with_hash}".green
              elsif File.directory?("#{ip_folder}/output/verilog")
                ip_type = "verilog"
                system "cp -r #{ip_folder}/output/verilog/* #{@shell_name}/ip-src/#{ip_name_with_hash}"
                UI.puts "hCODE: (#{Time.now.to_s}) cp -r #{ip_folder}/output/verilog/* #{@shell_name}/ip-src/#{ip_name_with_hash}".green
              elsif File.directory?("#{ip_folder}/output/vhdl")
                ip_type = "vhdl"
                system "cp -r #{ip_folder}/output/vhdl/* #{@shell_name}/ip-src/#{ip_name_with_hash}"
                UI.puts "hCODE: (#{Time.now.to_s}) cp -r #{ip_folder}/output/verilog/* #{@shell_name}/ip-src/#{ip_name_with_hash}".green
              end
          }

          UI.puts "hCODE: (#{Time.now.to_s}) Adding IPs to shell.".green
          system "cd #{@shell_name} && ./make -addip > make_addip.log 2>&1"
        end

        def make_shell
          UI.puts "hCODE: (#{Time.now.to_s}) Making Shell+IPs accelerator project (It may take tens of minutes to few hours).".green
          shell_name = @hcode_file["shell"]["name"]
          system "cd #{@shell_name} && ./make > make.log 2>&1"

          bit_file_paths = []
          Find.find("./#{@shell_name}/") do |path|
             bit_file_paths << path if path =~ /.*\.bit$/
          end
          if bit_file_paths.length <= 0
            UI.puts "hCODE: (#{Time.now.to_s}) Bitstream is not found, please check the shell project.".red
            exit
          end
          @bit_file = bit_file_paths[0]
          FileUtils.cp_r @bit_file, "./"          
        end

        def cache_bitstream
            require 'find'
            require 'base64'
            bitstream = File.binread(@bit_file)
            bitstream_b64 = Base64.encode64(bitstream)
            bit_hash = Digest::SHA256.hexdigest(bitstream_b64)[0..9]
            bit_cache = "#{Dir.home}/.hcode/cache/#{bit_hash}"
            if !File.directory?(bit_cache)
              FileUtils::mkdir_p bit_cache
              FileUtils.cp_r @bit_file, bit_cache
              FileUtils.cp_r "./hcode", bit_cache
            end   
            if !File.directory?(@spec_cache)
              system "ln -s #{bit_cache} #{@spec_cache}"
            end
            UI.puts "hCODE: (#{Time.now.to_s}) Final accelerator bitstream is generated and cached (#{bit_hash} and #{@spec_hash}).".green
        end
      end
    end
  end
end
