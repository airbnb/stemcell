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
    let(:result_metadata)   { chef_repo.metadata_for_role(role, environment, options) }

    let(:cookbook_attributes) { [] }
    let(:normal_attributes) { {} }
    let(:options) {
      {
        :cookbook_attributes => cookbook_attributes,
        :normal_attributes => normal_attributes
      }
    }
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

    context "with chef cookbook attributes" do

      context "that are not valid" do
        let(:role) { 'unit-simple-none' }
        let(:cookbook_attributes) { ['unknown::attr'] }
        it "raises an error" do
          expect { result_metadata }.to raise_error(Chef::Exceptions::CookbookNotFound)
        end
      end

      context "for a role with no inheritance and default attributes" do
        let(:role) { 'unit-simple-default' }
        let(:cookbook_attributes) { ['unit_cookbook::simple-default'] }
        it "returns the expected metdata" do
          expect(result_metadata).to include(
            "tags" => {
              "tag1" => "tag1_value_default",
              "tag2" => "tag2_value",
              "tag3" => "tag3_value_attribute_default"
            }
          )
        end
      end

      context "for a role with no inheritance and derived attributes" do
        let(:role) { 'unit-simple-default' }
        let(:cookbook_attributes) { ['unit_cookbook::simple-derived'] }
        it "returns the expected metdata" do
          expect(result_metadata).to include(
            "tags" => {
              "tag1" => "tag1_value_default",
              "derived_tag1" => "tag1_value_default",
              "tag2" => "tag2_value"
            }
          )
        end
      end

      context "that override a role with no inheritance and default attributes" do
        let(:role) { 'unit-simple-default' }
        let(:cookbook_attributes) { ['unit_cookbook::simple-override'] }
        it "returns the expected metdata" do
          expect(result_metadata).to include(
            "tags" => {
              "tag1" => "tag1_value_default",
              "tag2" => "tag2_value_override"
            }
          )
        end
      end

    end

    context "with normal attributes" do
      let(:role) { 'unit-simple-default' }

      context "for a role with default attribute" do
        let(:normal_attributes) { { :instance_metadata => { :instance_type => 'test' } } }
        it "returns the attribute with higher precedence" do
          expect(result_metadata).to include("instance_type" => "test")
        end
      end

      context "for a cookbook attribute" do
        let(:role) { 'unit-simple-default' }
        let(:cookbook_attributes) { ['unit_cookbook::simple-derived'] }
        let(:normal_attributes) {
          {
            :instance_metadata => {
              :tags => {
                'tag1' => 'tag1_value_normal'
              }
            }
          }
        }
        it "returns the normal/derived attribute" do
          expect(result_metadata).to include(
            "tags" => {
              "tag1" => "tag1_value_normal",
              "derived_tag1" => "tag1_value_normal",
              "tag2" => "tag2_value"
            }
          )
        end
      end

    end

  end

end
