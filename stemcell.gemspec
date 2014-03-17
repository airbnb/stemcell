# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'stemcell/version'

Gem::Specification.new do |s|
  s.name          = "stemcell"
  s.version       = Stemcell::VERSION
  s.authors       = ["Martin Rhoads", "Igor Serebryany", "Nelson Gauthier", "Patrick Viet"]
  s.email         = ["martin.rhoads@airbnb.com", "igor.serebryany@airbnb.com"]
  s.description   = %q{A tool for launching and bootstrapping EC2 instances}
  s.summary       = %q{no summary}
  s.homepage      = "https://github.com/airbnb/stemcell"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'aws-sdk',   '~> 1.34'
  s.add_runtime_dependency 'net-ssh',   '~> 2.8'
  s.add_runtime_dependency 'chef',      '~> 11.4.0'

  s.add_runtime_dependency 'trollop',   '~> 2.0'
  s.add_runtime_dependency 'aws-creds', '~> 0.2.3'
  s.add_runtime_dependency 'colored',   '~> 1.2'
  s.add_runtime_dependency 'json',      '~> 1.7.7'
end
