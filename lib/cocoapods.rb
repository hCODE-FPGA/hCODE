require 'rubygems'
#require 'xcodeproj'

# It is very likely that we'll need these and as some of those paths will atm
# result in a I18n deprecation warning, we load those here now so that we can
# get rid of that warning.
require 'active_support/core_ext/string/strip'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array/conversions'
# TODO: check what this actually does by the time we're going to add support for
# other locales.
require 'i18n'
if I18n.respond_to?(:enforce_available_locales=)
  I18n.enforce_available_locales = false
end

module Pod
  require 'pathname'
  require 'tmpdir'

  require 'cocoapods/gem_version'
  require 'cocoapods-core/gem_version'

  # Indicates a runtime error **not** caused by a bug.
  #
  class PlainInformative < StandardError; end

  # Indicates a user error.
  #
  class Informative < PlainInformative; end
  
  require 'cocoapods/config'
  require 'cocoapods/downloader'
  require 'pathname'
  require 'cocoapods-core/vendor'



  # Loaded immediately after dependencies to ensure proper override of their
  # UI methods.
  #
  require 'cocoapods/user_interface'

  # Indicates an user error. This is defined in cocoapods-core.
  #
  class Informative < PlainInformative
    def message
      "[!] #{super}".red
    end
  end

  #Xcodeproj::PlainInformative.send(:include, CLAide::InformativeError)

  autoload :Version,        'cocoapods-core/version'
  autoload :Requirement,    'cocoapods-core/requirement'
  #autoload :Dependency,     'cocoapods-core/dependency'
  autoload :CoreUI,         'cocoapods-core/core_ui'
  autoload :DSLError,       'cocoapods-core/standard_error'
  autoload :GitHub,         'cocoapods-core/github'
  autoload :HTTP,           'cocoapods-core/http'
  autoload :Lockfile,       'cocoapods-core/lockfile'
  autoload :Metrics,        'cocoapods-core/metrics'
  autoload :Platform,       'cocoapods-core/platform'
  autoload :Podfile,        'cocoapods-core/podfile'
  autoload :Source,         'cocoapods-core/source'
  autoload :Specification,  'cocoapods-core/specification'
  autoload :StandardError,  'cocoapods-core/standard_error'
  autoload :YAMLHelper,     'cocoapods-core/yaml_helper'

  autoload :AggregateTarget,           'cocoapods/target/aggregate_target'
  autoload :Command,                   'cocoapods/command'
  #autoload :Deintegrator,              'cocoapods_deintegrate'
  autoload :Executable,                'cocoapods/executable'
  autoload :ExternalSources,           'cocoapods/external_sources'
  autoload :Installer,                 'cocoapods/installer'
  autoload :HooksManager,              'cocoapods/hooks_manager'
  autoload :PodTarget,                 'cocoapods/target/pod_target'
  autoload :Project,                   'cocoapods/project'
  autoload :Resolver,                  'cocoapods/resolver'
  autoload :Sandbox,                   'cocoapods/sandbox'
  autoload :SourcesManager,            'cocoapods/sources_manager'
  autoload :Target,                    'cocoapods/target'
  autoload :Validator,                 'cocoapods/validator'

  Spec = Specification

  module Generator
    autoload :Acknowledgements,        'cocoapods/generator/acknowledgements'
    autoload :Markdown,                'cocoapods/generator/acknowledgements/markdown'
    autoload :Plist,                   'cocoapods/generator/acknowledgements/plist'
    autoload :BridgeSupport,           'cocoapods/generator/bridge_support'
    autoload :CopyResourcesScript,     'cocoapods/generator/copy_resources_script'
    autoload :DummySource,             'cocoapods/generator/dummy_source'
    autoload :EmbedFrameworksScript,   'cocoapods/generator/embed_frameworks_script'
    autoload :Header,                  'cocoapods/generator/header'
    autoload :InfoPlistFile,           'cocoapods/generator/info_plist_file'
    autoload :ModuleMap,               'cocoapods/generator/module_map'
    autoload :PrefixHeader,            'cocoapods/generator/prefix_header'
    autoload :UmbrellaHeader,          'cocoapods/generator/umbrella_header'
    autoload :XCConfig,                'cocoapods/generator/xcconfig'
  end
end
