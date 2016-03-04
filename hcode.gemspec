# encoding: UTF-8
require File.expand_path('../lib/cocoapods/gem_version', __FILE__)
require 'date'

Gem::Specification.new do |s|
  s.name     = "hcode"
  s.version  = Pod::VERSION
  s.date     = Date.today
  s.license  = "MIT"
  s.email    = ["cho@arch.cs.kumamoto-u.ac.jp"]
  s.homepage = "https://github.com/hCODE-FPGA/hDevKit"
  s.authors  = ["Qian ZHAO"]

  s.summary     = "The devleopment kit tools of the hCODE project."
  s.description = ""
  s.files = Dir["lib/**/*.rb"] + %w{ bin/hcode README.md LICENSE CHANGELOG.md }

  s.executables   = %w{ hcode }
  s.require_paths = %w{ lib }

  # Link with the version of CocoaPods-Core
  #s.add_runtime_dependency 'cocoapods-core',        "= #{Pod::VERSION}"

  s.add_runtime_dependency 'claide',                '>= 1.0.0.beta.1', '< 2.0'
  #s.add_runtime_dependency 'cocoapods-deintegrate', '>= 1.0.0.beta.1', '< 2.0'
  s.add_runtime_dependency 'cocoapods-downloader',  '>= 1.0.0.beta.1', '< 2.0'
  #s.add_runtime_dependency 'cocoapods-plugins',     '>= 1.0.0.beta.1', '< 2.0'
  #s.add_runtime_dependency 'cocoapods-search',      '>= 1.0.0.beta.1', '< 2.0'
  s.add_runtime_dependency 'cocoapods-stats',       '>= 1.0.0.beta.3', '< 2.0'
  #s.add_runtime_dependency 'cocoapods-trunk',       '>= 1.0.0.beta.2', '< 2.0'
  #s.add_runtime_dependency 'cocoapods-try',         '>= 1.0.0.beta.2', '< 2.0'
  s.add_runtime_dependency 'molinillo',             '~> 0.4.3'
  #s.add_runtime_dependency 'xcodeproj',             '>= 1.0.0.beta.3', '< 2.0'

  s.add_runtime_dependency 'activesupport', '>= 4.0.2'
  s.add_runtime_dependency 'colored',       '~> 1.2'
  s.add_runtime_dependency 'escape',        '~> 0.0.4'
  s.add_runtime_dependency 'fourflusher',   '~> 0.3.0'
  s.add_runtime_dependency 'nap',           '~> 1.0'

  s.add_development_dependency 'bacon', '~> 1.1'
  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake', '~> 10.0'

  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = "1.6.2"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = '>= 2.0.0'
  s.specification_version = 3 if s.respond_to? :specification_version
end
