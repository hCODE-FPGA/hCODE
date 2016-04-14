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
          @ip_name = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A name for the IP folder is required.' unless @ip_name
        end

        def run
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

        def specs_from_ip
          require 'json'
          #Read shell hcode.spec and parse JSON
          json = File.read("#{@ip_name}/shell/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new
          @shell_name = spec["name"]

          #Read ip hcode.spec and parse JSON
          json = File.read("#{@ip_name}/ip/#{@ip_name}/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new
          index = 0
          @ip_configure_paras = ""

          #get shell URLs, if support multiple shells, let user choose one
          spec["platforms"].each_with_index{|platform, i|
            index = i if platform[1]["shell"] == @shell_name
          }

          #Get IP configurations for selected shell
          keys = spec["platforms"].keys
          spec["platforms"][keys[index]].each{|key, value|
            @ip_configure_paras += "-#{key} \"#{value}\" "
          }
        end

        def configure_ip
          UI.puts "Configuring IP: "
          system "cd #{@ip_name}/ip/#{@ip_name} && ./configure #{@ip_configure_paras}"
        end

        def configure_shell
          UI.puts "Configuring Shell: "
          system "cd #{@ip_name}/shell && ./configure #{@ip_configure_paras}"
        end

        def make_ip
          system "cd #{@ip_name}/ip/#{@ip_name} && ./make"
        end

        def copy_ip_verilog_to_shell
          system "cd #{@ip_name}/shell && ./make -removeip"
          system "rm -rf #{@ip_name}/shell/ip-src/*"
          system "cp -r #{@ip_name}/ip/#{@ip_name}/output/verilog/* #{@ip_name}/shell/ip-src/"
          system "cd #{@ip_name}/shell && ./make -addip"
        end

        def make_shell
          system "cd #{@ip_name}/shell && ./make"
        end
      end
    end
  end
end