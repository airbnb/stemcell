require 'simplecov'

require 'stemcell'
require 'support/fixture_helper'

SimpleCov.start do
  add_filter 'spec'
end

RSpec.configure do |config|
  config.color = true
end
