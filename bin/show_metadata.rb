#!/usr/bin/env ruby
# Stemcell (metadata only) (c) 2013 Airbnb
#
# This script outputs the JSON-encoded metadata that stemcel uses to start a
# given role / environment combination.
#
# Usage: script/launch_metadata.rb [chef root] [chef role] [chef environment]

require 'stemcell'

# This script belongs in the /scripts folder.
CHEF_ROOT = File.expand_path "#{__FILE__}/../.."

unless ARGV.count == 3
  fail "usage: #{$PROGRAM_NAME} <chef root> <chef role> <chef environment>"
end

chef_root, chef_role, chef_environment = ARGV

begin
  source = Stemcell::MetadataSource.new(chef_root)
  metadata = source.expand_role(chef_role, chef_environment)
rescue Launch::EmptyRoleError
  fail "this role (#{chef_role}) doesn't contain launch metadata"
end

puts JSON.dump(metadata)
