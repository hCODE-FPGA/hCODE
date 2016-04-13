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
          @ip_name = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A name for the IP folder is required.' unless @ip_name
        end

        def run
          system "cd #{@ip_name}/ip/#{@ip_name} && sh make.sh -driver"
        end
      end
    end
  end
end