module Pod
  class Command
    class Ip < Command
      #-----------------------------------------------------------------------#
      #Compile a IP
      #-----------------------------------------------------------------------#
      class Make < Ip
        self.summary = 'Make the downloaded IP automaticlly.'

        self.description = <<-DESC
          Make the downloaded IP automaticlly.
        DESC

        self.arguments = [
          CLAide::Argument.new('IP_REPO_NAME', true),
        ]

        def initialize(argv)
          @acc_name = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A name for the IP folder is required.' unless @acc_name
        end

        def run
          get_names
          specs_from_ip
          configure_ip
          configure_shell
          make_ip
          copy_ip_verilog_to_shell
          make_shell
        end

        private
        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def get_names
            @ip_name = ""
            @shell_name = ""

            require 'find'
            bit_file_paths = []
            Find.find(@acc_name) do |path|
              bit_file_paths << path if path =~ /.hcode\.spec$/
            end

            if bit_file_paths.length > 0
              bit_file_paths.each{|path|
                puts path
                require 'json'
                json = File.read(path)
                spec = JSON.parse(json)
                name = spec["name"]

                @ip_name = name if name.include?'ip-'
                @shell_name = name if name.include?'shell-'
              }
              if @ip_name == "" || @shell_name == ""
                UI.puts "Cannot find IP or Shell project, please check the acclerator project #{acc_name}.".red
                exit
              end
            else
              UI.puts "No bitstream is found in folder #{@bitstream_file}.".red
              exit
            end
        end

        def specs_from_ip
          @ip_configure_paras = ""

          require 'json'
          #Read shell hcode.spec and parse JSON
          json = File.read("#{@acc_name}/#{@shell_name}/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new
          @shell_name = spec["name"]
          #Get Sehll hardware parameters
          spec["hardware"].each{|key, value|
            @ip_configure_paras += "-#{key} \'#{value}\' "
          }

          #Read ip hcode.spec and parse JSON
          json = File.read("#{@acc_name}/#{@ip_name}/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new
          index = 0
          

          shell_names = spec["shell"].keys
          #get shell URLs, if support multiple shells, let user choose one
          shell_names.each_with_index{|name,i|
            index = i if name == @shell_name
          }

          #Get IP configurations for selected shell
          spec["shell"][shell_names[index]].each{|key, value|
            @ip_configure_paras += "-#{key} \'#{value}\' "
          }
        end

        def configure_ip
          cmd = "cd #{@acc_name}/#{@ip_name} && ./configure #{@ip_configure_paras}"
          UI.puts "Configuring IP: "
          UI.puts cmd
          system cmd
        end

        def configure_shell
          cmd = "cd #{@acc_name}/#{@shell_name} && ./configure #{@ip_configure_paras}"
          UI.puts "Configuring Shell: "
          UI.puts cmd
          system cmd
        end

        def make_ip
          system "cd #{@acc_name}/#{@ip_name} && ./make"
        end

        def copy_ip_verilog_to_shell
          system "cd #{@acc_name}/#{@shell_name} && ./make -removeip"
          system "rm -rf #{@acc_name}/#{@shell_name}/ip-src/*"
          system "cp -r #{@acc_name}/#{@ip_name}/output/verilog/* #{@acc_name}/#{@shell_name}/ip-src/"
          system "cd #{@acc_name}/#{@shell_name} && ./make -addip"
        end

        def make_shell
          system "cd #{@acc_name}/#{@shell_name} && ./make"
        end
      end
    end
  end
end