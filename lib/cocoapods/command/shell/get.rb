module Pod
  class Command
    class Shell < Command
      #-----------------------------------------------------------------------#
      #Get a IP + shell from repository
      #-----------------------------------------------------------------------#
      class Get < Shell
        self.summary = 'Download a shell.'

        self.description = <<-DESC
          Download the Shell from a given SHELL_REPO_NAME.
          A SHELL_REPO_VERSION tag can also be specified.
        DESC

        self.arguments = [
          CLAide::Argument.new('SHELL_REPO_NAME', true),
          CLAide::Argument.new('SHELL_REPO_VERSION', false),
        ]

        def initialize(argv)
          @shell_name = argv.shift_argument
          @shell_tag = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A url for the Shell repo is required.' unless @shell_name
        end

        def run
          url = repo_from_name(@shell_name)

          @shell_tag = url["tag"] unless @shell_tag

          UI.puts "Get shell #{@shell_name} ~> #{@shell_tag}".green
          clone(url["git"], @shell_tag, "#{@shell_name}")

          UI.puts ""
          UI.puts "Success: Shell:#{@shell_name} is downloaded."
        end

        private

        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def repo_from_name(name)
          UI.puts name
          begin
            set = SourcesManager.fuzzy_search_by_name(name)
            set.repo_url
          rescue => e
            UI.puts "Error: Can not find repo for shell #{name}.".red
            nil
          end
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
      end
    end
  end
end