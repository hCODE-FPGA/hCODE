module Pod
  class Command
    class Ip < Command
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