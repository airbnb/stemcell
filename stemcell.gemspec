# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'stemcell/version'

Gem::Specification.new do |s|
  s.name          = "stemcell"
  s.version       = Stemcell::VERSION
  s.authors       = ["Martin Rhoads", "Igor Serebryany", "Nelson Gauthier", "Patrick Viet"]
  s.email         = ["igor.serebryany@airbnb.com"]
  s.description   = %q{A tool for launching and bootstrapping EC2 instances}
  s.summary       = %q{no summary}
  s.homepage      = "https://github.com/airbnb/stemcell"
  s.license       = 'MIT'

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'aws-sdk-v1', '~> 1.63'
  s.add_runtime_dependency 'net-ssh',    '~> 2.9'
  if RUBY_VERSION >= '2.0'
    s.add_runtime_dependency 'chef',     '>= 11.4.0'
  else
    s.add_runtime_dependency 'chef',     ['>= 11.4.0', '< 12.0.0']
  end

  # this is a transitive dependency, but the latest vesion has a late ruby
  # version dependency. lets explicitly include it here. if this becomes
  # no-longer a dependency of chef via chef-zero, then remove it
  s.add_runtime_dependency 'rack', '< 2.0.0'
  s.add_runtime_dependency 'nokogiri', '~> 1.8.2'
  s.add_runtime_dependency 'ffi-yajl', '< 2.3.1'

  s.add_runtime_dependency 'trollop',    '~> 2.1'
  s.add_runtime_dependency 'aws-creds',  '~> 0.2.3'
  s.add_runtime_dependency 'colored',    '~> 1.2'
  s.add_runtime_dependency 'json',       '~> 1.8.2'
end
