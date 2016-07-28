require 'spec_helper'

describe Stemcell::OptionParser do
  describe '#parse!' do
    it 'returns a hash containing all of the options' do
      result = subject.parse!([])
      expect(result).to be_an_instance_of(Hash)

      possible_keys = described_class::OPTION_DEFINITIONS.map { |d| d[:name] }
      expect(result).to include(*possible_keys)
    end
  end
end
