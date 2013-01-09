# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'roket/version'

Gem::Specification.new do |gem|
  gem.name          = "roket"
  gem.version       = Roket::VERSION
  gem.authors       = ["Martin Rhoads"]
  gem.email         = ["martin.rhoads@airbnb.com"]
  gem.description   = %q{roket launches instances}
  gem.summary       = %q{no summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
