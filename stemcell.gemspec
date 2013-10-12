# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'stemcell/version'

Gem::Specification.new do |s|
  s.name          = "stemcell"
  s.version       = Stemcell::VERSION
  s.authors       = ["Martin Rhoads"]
  s.email         = ["martin.rhoads@airbnb.com"]
  s.description   = %q{stemcell launches instances}
  s.summary       = %q{no summary}
  s.homepage      = ""

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'aws-sdk',   '~> 1.9'
  s.add_runtime_dependency 'chef',      '~> 11.4.0'

  s.add_runtime_dependency 'trollop',   '~> 2.0'
  s.add_runtime_dependency 'aws-creds', '~> 0.2.2'
  s.add_runtime_dependency 'colored',   '~> 1.2'
  s.add_runtime_dependency 'json',      '~> 1.7.7'
end
