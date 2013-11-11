require 'spec_helper'

describe Stemcell::MetadataSource::Configuration do

  let(:config_filename) { 'stemcell.json' }

  let(:chef_root) { FixtureHelper.chef_repo_fixture_path }
  let(:path)      { File.join(chef_root, config_filename) }
  let(:config)    { Stemcell::MetadataSource::Configuration.new(path) }

  describe '#initialize' do

    it "sets config_path" do
      expect(config.config_path).to eql path
    end

    it "sets all_options" do
      expect(config.all_options.keys).to eql([
        'defaults',
        'backing_store',
        'availability_zones'
      ])
    end

    context "when the required options are present" do
      it "sets default_options" do
        expect(config.default_options).to eql({
          'instance_type' => 'm1.small'
        })
      end

      it "sets backing_store_options" do
        expect(config.backing_store_options).to eql({
          'instance_store' => {
            'image_id' => 'ami-d9d6a6b0'
          }
        })
      end

      it "sets availability_zones" do
        expect(config.availability_zones).to eql({
          'us-east-1' => ['us-east-1a']
        })
      end
    end

    context "when defaults are not specified" do
      let(:config_filename) { 'stemcell-defaults-missing.json' }
      it "raises" do
        expect { config }.to raise_error(Stemcell::MetadataConfigParseError)
      end
    end

    context "when backing store options are not specified" do
      let(:config_filename) { 'stemcell-backing-store-missing.json' }
      it "raises" do
        expect { config }.to raise_error(Stemcell::MetadataConfigParseError)
      end
    end

    context "when availability zones are empty" do
      let(:config_filename) { 'stemcell-backing-store-empty.json' }
      it "raises" do
        expect { config }.to raise_error(Stemcell::MetadataConfigParseError)
      end
    end

    context "when availability zones are not specified" do
      let(:config_filename) { 'stemcell-azs-missing.json' }
      it "raises" do
        expect { config }.to raise_error(Stemcell::MetadataConfigParseError)
      end
    end

  end

  describe '#options_for_backing_store' do
    let(:backing_store) { 'instance_store' }

    context "when the backing store definition exists" do
      it "returns the options" do
        expect(config.options_for_backing_store(backing_store)).to eql({
          'image_id' => 'ami-d9d6a6b0'
        })
      end
    end

    context "when the backing store isn't defined" do
      let(:backing_store) { 'nyanstore' }
      it "raises" do
        expect { config.options_for_backing_store(backing_store) }.to raise_error(
          Stemcell::UnknownBackingStoreError
        )
      end
    end

  end

  describe '#random_az_in_region' do
    let(:region) { 'us-east-1' }

    context "when availability zones are defined for the region" do
      it "returns an az" do
        expect(config.random_az_for_region(region)).to eql('us-east-1a')
      end
    end

    context "when availability zone aren't defined for the region" do
      let(:region) { 'nyancat' }
      it "returns nil" do
        expect(config.random_az_for_region(region)).to be_nil
      end
    end

  end

end
