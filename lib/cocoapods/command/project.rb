module Pod
  class Command
    # Provides support for commands to take a user-specified `project directory`
    #
    module ProjectDirectory
      module Options
        def options
          [
            ['--project-directory=/project/dir/', 'The path to the root of the project directory'],
          ].concat(super)
        end
      end

      def self.included(base)
        base.extend(Options)
      end

      def initialize(argv)
        if project_directory = argv.option('project-directory')
          @project_directory = Pathname.new(project_directory).expand_path
        end
        config.installation_root = @project_directory
        super
      end

      def validate!
        super
        if @project_directory && !@project_directory.directory?
          raise Informative,
                "`#{@project_directory}` is not a valid directory."
        end
      end
    end

    # Provides support for the common behaviour of the `install` and `update`
    # commands.
    #
    module Project
      module Options
        def options
          [
            ['--no-repo-update', 'Skip running `pod repo update` before install'],
          ].concat(super)
        end
      end

      def self.included(base)
        base.extend Options
      end

      def initialize(argv)
        config.skip_repo_update = !argv.flag?('repo-update', !config.skip_repo_update)
        super
      end

      # Runs the installer.
      #
      # @param  [Hash, Boolean, nil] update
      #         Pods that have been requested to be updated or true if all Pods
      #         should be updated
      #
      # @return [void]
      #
      def run_install_with_update(update)
        installer = Installer.new(config.sandbox, config.podfile, config.lockfile)
        installer.update = update
        installer.install!
      end
    end

    #-------------------------------------------------------------------------#

    class Install < Command
      include Project

      self.summary = 'Install shell, ip, or app defined in hCODE.conf file.'

      self.description = <<-DESC
        Downloads all shell, ip, or app defined in `hCODE.conf`.
      DESC

      def run
        verify_podfile_exists!
        run_install_with_update(false)
      end
    end

    #-------------------------------------------------------------------------#

    
  end
end
