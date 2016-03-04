module Pod
  class Command
    class Ip < Command
      self.abstract_command = true
      self.summary = 'Develop hardware IP'

      #-----------------------------------------------------------------------#
      class Get < Ip
        self.summary = 'Download an IP and as well as a compatible shell for your enviroment'

        self.description = <<-DESC
          Download the IP from a given IP_REPO_NAME.
          A IP_REPO_VERSION tag can also be specified.
        DESC

        self.arguments = [
          CLAide::Argument.new('IP_REPO_NAME', true),
          CLAide::Argument.new('IP_REPO_VERSION', false),
        ]

        def initialize(argv)
          @ip_name = argv.shift_argument
          @ip_tag = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A url for the IP repo is required.' unless @ip_name
        end

        def run
          url = repo_from_name(@ip_name)
          make_project_dir

          @ip_tag = url["tag"] unless @ip_tag

          UI.puts "Get ip #{@ip_name} ~> #{@ip_tag}".green
          clone(url["git"], @ip_tag, "#{@ip_name}/ip/#{@ip_name}")
          shells_for_ip()
          
          #configure_template
          #print_info
        end

        private

        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def repo_from_name(name)
          set = SourcesManager.fuzzy_search_by_name(name)
          set.repo_url
        end

        def make_project_dir
          FileUtils.mkdir_p("#{@ip_name}")
          FileUtils.mkdir_p("#{@ip_name}/ip")
          FileUtils.mkdir_p("#{@ip_name}/shell")
        end

        def shells_for_ip
          UI.puts "Get shell for #{@ip_name} ~> #{@ip_tag}".green

          json = File.read("#{@ip_name}/ip/#{@ip_name}/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new
          spec["shells"].each{|shell|
              urls.push repo_from_name(shell[0])
          }

          index = 0
          if spec["shells"].length > 1
            message = "Choose a shell.".green
            index = UI.choose_from_array(urls, message)
          end

          clone(urls[index]["git"], urls[0]["tag"], "#{@ip_name}/shell/")
        end



        # Clones the repo from the remote in the path directory using
        # the url, tag of IP repo.
        #
        # @return [void]
        #
        def clone(url, tag, dir)
          UI.section("Cloning #{url} with tag #{tag}.") do
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

      #-----------------------------------------------------------------------#

      class Lint < Ip
        self.summary = 'Validates a Pod'

        self.description = <<-DESC
          Validates the Pod using the files in the working directory.
        DESC

        def self.options
          [
            ['--quick', 'Lint skips checks that would require to download and build the spec'],
            ['--allow-warnings', 'Lint validates even if warnings are present'],
            ['--subspec=NAME', 'Lint validates only the given subspec'],
            ['--no-subspecs', 'Lint skips validation of subspecs'],
            ['--no-clean', 'Lint leaves the build directory intact for inspection'],
            ['--fail-fast', 'Lint stops on the first failing platform or subspec'],
            ['--use-libraries', 'Lint uses static libraries to install the spec'],
            ['--sources=https://github.com/artsy/Specs,master', 'The sources from which to pull dependent pods ' \
             '(defaults to https://github.com/CocoaPods/Specs.git). ' \
             'Multiple sources must be comma-delimited.'],
            ['--private', 'Lint skips checks that apply only to public specs'],
          ].concat(super)
        end

        def initialize(argv)
          @quick           = argv.flag?('quick')
          @allow_warnings  = argv.flag?('allow-warnings')
          @clean           = argv.flag?('clean', true)
          @fail_fast       = argv.flag?('fail-fast', false)
          @subspecs        = argv.flag?('subspecs', true)
          @only_subspec    = argv.option('subspec')
          @use_frameworks  = !argv.flag?('use-libraries')
          @source_urls     = argv.option('sources', 'https://github.com/CocoaPods/Specs.git').split(',')
          @private         = argv.flag?('private', false)
          @podspecs_paths  = argv.arguments!
          super
        end

        def validate!
          super
        end

        def run
          UI.puts
          podspecs_to_lint.each do |podspec|
            validator                = Validator.new(podspec, @source_urls)
            validator.local          = true
            validator.quick          = @quick
            validator.no_clean       = !@clean
            validator.fail_fast      = @fail_fast
            validator.allow_warnings = @allow_warnings
            validator.no_subspecs    = !@subspecs || @only_subspec
            validator.only_subspec   = @only_subspec
            validator.use_frameworks = @use_frameworks
            validator.ignore_public_only_results = @private
            validator.validate

            unless @clean
              UI.puts "Pods workspace available at `#{validator.validation_dir}/App.xcworkspace` for inspection."
              UI.puts
            end
            if validator.validated?
              UI.puts "#{validator.spec.name} passed validation.".green
            else
              spec_name = podspec
              spec_name = validator.spec.name if validator.spec
              message = "#{spec_name} did not pass validation, due to #{validator.failure_reason}."

              if @clean
                message << "\nYou can use the `--no-clean` option to inspect " \
                  'any issue.'
              end
              raise Informative, message
            end
          end
        end

        private

        #----------------------------------------#

        # !@group Private helpers

        # @return [Pathname] The path of the podspec found in the current
        #         working directory.
        #
        # @raise  If no podspec is found.
        # @raise  If multiple podspecs are found.
        #
        def podspecs_to_lint
          if !@podspecs_paths.empty?
            Array(@podspecs_paths)
          else
            podspecs = Pathname.glob(Pathname.pwd + '*.spec{.json,}')
            if podspecs.count.zero?
              raise Informative, 'Unable to find a podspec in the working ' \
                'directory'
            end
            podspecs
          end
        end
      end

      #-----------------------------------------------------------------------#
    end
  end
end
