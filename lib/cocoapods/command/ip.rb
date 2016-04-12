module Pod
  class Command
    class Ip < Command
      self.abstract_command = true
      self.summary = 'Develop hardware IP'

      #-----------------------------------------------------------------------#
      #Get a IP + shell from repository
      #-----------------------------------------------------------------------#
      class Get < Ip
        self.summary = 'Download an IP and as well as a compatible shell.'

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
          specs_from_ip

          UI.puts ""
          UI.puts "Success: IP:#{@ip_name} and Shell:#{@shell_name} are downloaded."
          UI.puts "Next, you can use \"hcode ip make #{@ip_name}\" to compile."
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
            UI.puts "Error: Can not find repo for shall #{name}.".red
            nil
          end
        end

        def make_project_dir
          FileUtils.mkdir_p("#{@ip_name}")
          FileUtils.mkdir_p("#{@ip_name}/ip")
          FileUtils.mkdir_p("#{@ip_name}/shell")
        end

        def specs_from_ip
          UI.puts "Get specs for #{@ip_name} ~> #{@ip_tag}".green

          #Read hcode.spec and parse JSON
          json = File.read("#{@ip_name}/ip/#{@ip_name}/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new
          index = 0

          #get shell URLs, if support multiple shells, let user choose one
          spec["platforms"].each_with_index{|platform, i|
                repo_url = repo_from_name(platform[1]["shell"])
                urls.push repo_url if repo_url != nil
                index = i if repo_url != nil
          }
 
          url_index = 0
          if urls.length > 1
            message = "Choose a shell.".green
            url_index = UI.choose_from_array(urls, message)
          end

          keys = spec["platforms"].keys

          #Get IP configurations for selected shell
          @shell_name = keys[index]

          clone(urls[url_index]["git"], urls[url_index]["tag"], "#{@ip_name}/shell/")
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
          start_vivado
        end

        private
        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def specs_from_ip
          require 'json'
          #Read hcode.spec and parse JSON
          json = File.read("#{@ip_name}/shell/hcode.spec")
          spec = JSON.parse(json)
          urls = Array.new
          @shell_name = spec["name"]

          #Read hcode.spec and parse JSON
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
          system "cd #{@ip_name}/ip/#{@ip_name} && sh configure.sh #{@ip_configure_paras}"
        end

        def configure_shell
          UI.puts "Configuring Shell: "
          system "cd #{@ip_name}/shell && sh configure.sh #{@ip_configure_paras}"
        end

        def make_ip
          system "cd #{@ip_name}/ip/#{@ip_name} && sh make.sh"
        end

        def copy_ip_verilog_to_shell
          system "rm -rf #{@ip_name}/shell/ip-src/*"
          system "cp -r #{@ip_name}/ip/#{@ip_name}/output/verilog/* #{@ip_name}/shell/ip-src/"
        end

        def start_vivado
          UI.puts "All generated IP are added into shell project, bringing up Vivado now."
          UI.puts "Please finish bitstream generation in Vivado."
          system "echo \"remove_files IP_wrapper.v;add_files ./ip-src\" > tmp.tcl"
          system "cd #{@ip_name}/shell && vivado -nolog -nojournal -source ../../tmp.tcl ./hcode_shell.xpr"
          system "rm -rf tmp.tcl"
        end
      end

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
