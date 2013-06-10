require 'stemcell/version'

require 'stemcell/ec2_provider'
require 'stemcell/lxc_provider'

module Stemcell
  # Maintain alias to avoid breaking API. Prefer StemcellEC2
  Stemcell = Stemcell::EC2Provider
end
