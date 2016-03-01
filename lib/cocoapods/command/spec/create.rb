
module Pod
  class Command
    class Spec < Command
      class Create < Spec
        self.summary = 'Create spec file stub.'

        self.description = <<-DESC
          Creates a PodSpec, in the current working dir, called `NAME.podspec'.
          If a GitHub url is passed the spec is prepopulated.
        DESC

        self.arguments = [
          CLAide::Argument.new(%w(NAME https://github.com/USER/REPO), false),
        ]

        def initialize(argv)
          @type = argv.shift_argument
          #@url = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A hCODE project type (shell, ip or app) is required.' unless @type
        end

        def run
          data = default_data_for_template(@type)
          

          case @type
          when "ip" then
            spec = spec_template_ip(data)
          when "shell" then
            spec = spec_template_shell(data)
          when "app" then
            spec = spec_template_app(data)
          else
            help! 'A type of shell, ip or app is required.'
          end

          (Pathname.pwd + "hfpga.spec").open('w') { |f| f << spec }
          UI.puts "\nSpecification of type #{@type} created at hfpga.spec".green
        end

        private

        #--------------------------------------#

        # Templates and GitHub information retrieval for spec create
        #
        # @todo It would be nice to have a template class that accepts options
        #       and uses the default ones if not provided.
        # @todo The template is outdated.

        def default_data_for_template(type)
          data = {}
          data[:name]          = "test"
          data[:version]       = '0.0.1'
          data[:type]          = type
          data
        end

        def github_data_for_template(repo_id)
          repo = GitHub.repo(repo_id)
          raise Informative, "Unable to fetch data for `#{repo_id}`" unless repo
          user = GitHub.user(repo['owner']['login'])
          raise Informative, "Unable to fetch data for `#{repo['owner']['login']}`" unless user
          data = {}

          data[:name]          = repo['name']
          data[:summary]       = (repo['description'] || '').gsub(/["]/, '\"')
          data[:homepage]      = (repo['homepage'] && !repo['homepage'].empty?) ? repo['homepage'] : repo['html_url']
          data[:author_name]   = user['name'] || user['login']
          data[:author_email]  = user['email'] || 'email@address.com'
          data[:source_url]    = repo['clone_url']

          data.merge suggested_ref_and_version(repo)
        end

        def suggested_ref_and_version(repo)
          tags = GitHub.tags(repo['html_url']).map { |tag| tag['name'] }
          versions_tags = {}
          tags.each do |tag|
            clean_tag = tag.gsub(/^v(er)? ?/, '')
            versions_tags[Gem::Version.new(clean_tag)] = tag if Gem::Version.correct?(clean_tag)
          end
          version = versions_tags.keys.sort.last || '0.0.1'
          data = { :version => version }
          if version == '0.0.1'
            branches        = GitHub.branches(repo['html_url'])
            master_name     = repo['master_branch'] || 'master'
            master          = branches.find { |branch| branch['name'] == master_name }
            raise Informative, "Unable to find any commits on the master branch for the repository `#{repo['html_url']}`" unless master
            data[:ref_type] = ':commit'
            data[:ref]      = master['commit']['sha']
          else
            data[:ref_type] = ':tag'
            data[:ref]      = versions_tags[version]
            data[:ref]      = '#{s.version}' if "#{version}" == versions_tags[version]
            data[:ref]      = 'v#{s.version}' if "v#{version}" == versions_tags[version]
          end
          data
        end

        def spec_template_shell(data)
          <<-SPEC
{
  "name": "test",
  "type": "shell",
  "version": "0.0.1",
  "summary": "A summary of test.",
  "description": "A description of test.",
  "homepage": "http://www.example.com/test",
  "license": "MIT",
  "authors": {
    "tester": "tester@example.com"
  },
  "source": {
    "git": "https://example.com/test.git",
    "tag": "0.0.1"
  },
  "platforms": {
    "vc707": "0.0.0"
  },
  "ides": {
    "version": "vivado2015.3",
    "version": "vivado2015.4"
  },
  "properties": {
    "max-clock": "250MHz",
    "host-fpga": {
        "name": "xillybus-eval-virtex7-1.2c",
        "interface": {
            "protocol" : "ap-stream",
            "datawidth" : "32"
          }
    },
    "fpga-ddr": {
        "name": "xilinx-mig",
        "interface":{
            "protocol" : "axi-master",
            "datawidth" : "32",
            "addresswidth" : "32"
        }
    }
  }
}

          SPEC
        end

        def spec_template_ip(data)
          <<-SPEC
{
  "name": "test",
  "type": "ip",
  "version": "0.0.1",
  "summary": "A summary of test.",
  "description": "A description of test.",
  "homepage": "http://www.example.com/test",
  "license": "MIT",
  "authors": {
    "tester": "tester@example.com"
  },
  "source": {
    "git": "https://example.com/test.git",
    "tag": "0.0.1"
  },
  "platforms": {
    "vc707": "0.0.0"
  },
  "shells": {
    "name": "shell-vc707-xillybus-ap_fifo32"
  },
  "code": {
    "verilog": true, 
    "verilog_generator": false,
    "vhdl": false,
    "vhdl_generator": false,
    "vivado_hls": true,
    "hls_generator": true
  },
  "ides": {
    "version": "vivado2015.3",
    "version": "vivado2015.4"
  },
  "properties": {
    "max-clock": "250MHz",
    "host-fpga": {
        "name": "xillybus-eval-virtex7-1.2c",
        "interface": {
            "protocol" : "ap-stream",
            "datawidth" : "32"
        }
    }
  }
}

          SPEC
        end

        def spec_template_app(data)
          <<-SPEC
{
  "name": "test",
  "type": "app",
  "version": "0.0.1",
  "summary": "A summary of test.",
  "description": "A description of test.",
  "homepage": "http://www.example.com/test",
  "license": "MIT",
  "authors": {
    "tester": "tester@example.com"
  },
  "source": {
    "git": "https://example.com/test.git",
    "tag": "0.0.1"
  },
  "platforms": {
    "vc707": "0.0.0"
  },
  "ides": {
    "version": "vivado2015.3",
    "version": "vivado2015.4"
  },
  "properties": {
    "max-clock": "250MHz"
  }
}

          SPEC
        end

        def semantic_versioning_notice(repo_id, repo)
          <<-EOS

#{'――― MARKDOWN TEMPLATE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――'.reversed}

I’ve recently added [#{repo}](https://github.com/CocoaPods/Specs/tree/master/#{repo}) to the [CocoaPods](https://github.com/CocoaPods/CocoaPods) package manager repo.

CocoaPods is a tool for managing dependencies for OSX and iOS Xcode projects and provides a central repository for iOS/OSX libraries. This makes adding libraries to a project and updating them extremely easy and it will help users to resolve dependencies of the libraries they use.

However, #{repo} doesn't have any version tags. I’ve added the current HEAD as version 0.0.1, but a version tag will make dependency resolution much easier.

[Semantic version](http://semver.org) tags (instead of plain commit hashes/revisions) allow for [resolution of cross-dependencies](https://github.com/CocoaPods/Specs/wiki/Cross-dependencies-resolution-example).

In case you didn’t know this yet; you can tag the current HEAD as, for instance, version 1.0.0, like so:

```
$ git tag -a 1.0.0 -m "Tag release 1.0.0"
$ git push --tags
```

#{'――― TEMPLATE END ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――'.reversed}

#{'[!] This repo does not appear to have semantic version tags.'.yellow}

After commiting the specification, consider opening a ticket with the template displayed above:
  - link:  https://github.com/#{repo_id}/issues/new
  - title: Please add semantic version tags
          EOS
        end
      end
    end
  end
end
