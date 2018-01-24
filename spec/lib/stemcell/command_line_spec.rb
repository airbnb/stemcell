require 'spec_helper'

describe Stemcell::CommandLine do
  describe '#run!' do
    let(:chef_root) { FixtureHelper.chef_repo_fixture_path }
    let(:config_fn) { 'Stemcell::MetadataSource::DEFAULT_CONFIG_FILENAME' }
    it 'outputs a help message' do
      stub_const 'ARGV', ["--local-chef-root=#{chef_root}", "--help"]
      stub_const config_fn, 'stemcell-options-parser.json'
      expect do
        subject.run!
      end.to output(/Show this message/).to_stdout.and raise_error(SystemExit)
    end
  end
end
