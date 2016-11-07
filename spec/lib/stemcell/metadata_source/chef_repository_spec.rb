require 'spec_helper'

describe Stemcell::MetadataSource::ChefRepository do

  let(:chef_root) { FixtureHelper.chef_repo_fixture_path }
  let(:chef_repo) { Stemcell::MetadataSource::ChefRepository.new(chef_root) }

  describe '#initialize' do

    it "sets chef_root" do
      expect(chef_repo.chef_root).to eql(chef_root)
    end

    context "with a mocked chef root" do
      let(:chef_root) { '/path/to/chef' }

      it "configures the cookbooks path" do
        chef_repo
        expect(Chef::Config[:cookbook_path]).to eql('/path/to/chef/cookbooks')
      end
      it "configures the data_bags path" do
        chef_repo
        expect(Chef::Config[:data_bag_path]).to eql('/path/to/chef/data_bags')
      end
      it "configures the roles path" do
        chef_repo
        expect(Chef::Config[:role_path]).to eql('/path/to/chef/roles')
      end
    end

  end

  describe '#metadata_for_role' do

    let(:expected_metadata) { FixtureHelper.expected_metadata_for_role(role) }
    let(:result_metadata)   { chef_repo.metadata_for_role(role, environment) }

    let(:environment) { 'production' }
    let(:role) { nil }

    context "for a role with no inheritance" do

      context "and no attributes" do
        let(:role) { 'unit-simple-none' }
        it "returns nil" do
          expect(result_metadata).to eql(nil)
        end
      end

      context "and default attributes" do
        let(:role) { 'unit-simple-default' }
        it "returns the expected metdata" do
          expect(result_metadata).to eql(expected_metadata)
        end
      end

      context "and override attributes" do
        let(:role) { 'unit-simple-override' }
        it "returns the expected metdata" do
          expect(result_metadata).to eql(expected_metadata)
        end
      end

      context "and both default and override attributes" do
        let(:role) { 'unit-simple-both' }
        it "returns the expected metdata" do
          expect(result_metadata).to eql(expected_metadata)
        end
      end

    end

    context "for a role with inheritance" do

      context "and no attributes" do
        let(:role) { 'unit-inherit-none' }
        it "returns the expected metdata" do
          expect(result_metadata).to eql(expected_metadata)
        end
      end

      context "and default attributes" do
        let(:role) { 'unit-inherit-default' }
        it "returns the expected metdata" do
          expect(result_metadata).to eql(expected_metadata)
        end
      end

      context "and override attributes" do
        let(:role) { 'unit-inherit-override' }
        it "returns the expected metdata" do
          expect(result_metadata).to eql(expected_metadata)
        end
      end

      context "and both default and override attributes" do
        let(:role) { 'unit-inherit-both' }
        it "returns the expected metdata" do
          expect(result_metadata).to eql(expected_metadata)
        end
      end

    end

  end

end
