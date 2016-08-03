module Pod
  class Command
    class Ip < Command
      #-----------------------------------------------------------------------#
      #Install a IP
      #-----------------------------------------------------------------------#
      class Install < Ip
        self.summary = 'Install the IP driver.'

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
          help! 'A name for the accelerator folder is required.' unless @acc_name
        end

        def run
          get_names
          system "cd #{@acc_name}/#{@ip_name} && ./make -driver"
        end

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
      end
    end
  end
end