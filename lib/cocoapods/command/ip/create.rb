module Pod
  class Command
    class Ip < Command
    	#-----------------------------------------------------------------------#
      #Create a new ip with a shell
      #-----------------------------------------------------------------------#
      class Create < Ip
        self.summary = 'Creates a new IP'

        self.description = <<-DESC
          Creates a scaffold for the development of a new IP named `NAME`
          according to the hCODE best practices.

          A repo url pointing to a `SHELL` is also required. You can find
          a proper hCODE shell by using the command `hcode search [keyword]`.

          If you are creating a hardware all on your own(not hCODE shell-ip way),
          you just need to type `hcode spec create app`, edit the hcode.spec,
          and sharing it by `hcode repo push [your-repo] hcode.spec` command.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', true),
          CLAide::Argument.new('SHELL', true),
        ]

        def initialize(argv)
          @name = argv.shift_argument
          @shell_name = argv.shift_argument
          super
          @additional_args = argv.remainder!
        end

        def validate!
          super
          help! 'A name for the IP is required.' unless @name
          help! 'The IP name cannot contain spaces.' if @name.match(/\s/)
          help! "The IP name cannot begin with a '.'" if @name[0, 1] == '.'
          help! 'A repo url of a shell is required.' unless @shell_name
        end

        def run
          make_project_dir
          @shell_url = repo_from_name(@shell_name)["git"]
          clone_template
          #configure_template
          print_info
        end

        private

        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        TEMPLATE_REPO = 'https://github.com/jonsonxp/shell-vc707-xillybus-ap_fifo32.git'
        
        CREATE_NEW_POD_INFO_URL = 'http://www.arch.cs.kumamoto-u.ac.jp/hcode'

        def make_project_dir
          FileUtils.mkdir_p("#{@name}")
          FileUtils.mkdir_p("#{@name}/ip")
          FileUtils.mkdir_p("#{@name}/ip/#{@name}")
          FileUtils.mkdir_p("#{@name}/shell")
        end

        def repo_from_name(name)
          set = SourcesManager.fuzzy_search_by_name(name)
          set.repo_url
        end

        # Clones the template from the remote in the working directory using
        # the name of the Pod.
        #
        # @return [void]
        #
        def clone_template
          UI.section("Cloning `#{template_repo_url}` into `#{@name}`.") do
            git! ['clone', template_repo_url, "#{@name}/shell"]
          end
        end

        # Runs the template configuration utilities.
        #
        # @return [void]
        #
        def configure_template
          UI.section("Configuring #{@name} template.") do
            Dir.chdir(@name) do
              if File.exist?('configure')
                system('./configure', @name, *@additional_args)
              else
                UI.warn 'Template does not have a configure file.'
              end
            end
          end
        end

        # Runs the template configuration utilities.
        #
        # @return [void]
        #
        def print_info
          UI.puts "\nTo learn more about the template see `#{template_repo_url}`."
          UI.puts "To learn more about creating a new pod, see `#{CREATE_NEW_POD_INFO_URL}`."
        end

        # Checks if a template URL is given else returns the TEMPLATE_REPO URL
        #
        # @return String
        #
        def template_repo_url
          @shell_url || TEMPLATE_REPO
        end
      end
    end
  end
end
