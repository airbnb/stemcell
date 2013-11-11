require 'chef'

module Stemcell
  class MetadataSource

    class ChefRepository
      attr_reader :chef_root

      # Search for instance metadata in the following role attributes, with
      # priority given to the keys at the head.
      METADATA_ATTRIBUTES = [
        :instance_metadata,
        :stemcell
      ]

      def initialize(chef_root)
        @chef_root = chef_root
        if chef_root.nil?
          raise ArgumentError, "You must specify a chef repository"
        end

        configure_chef
      end

      # This method will return nil if the role has no stemcell metdata.
      def metadata_for_role(chef_role, chef_environment)
        default_attrs, override_attrs = expand_role(chef_role, chef_environment)
        merged_attrs = default_attrs.merge(override_attrs)
        METADATA_ATTRIBUTES.inject(nil) { |r, key| r || merged_attrs[key] }
      end

      private

      def configure_chef
        Chef::Config[:cookbook_path] = File.join(chef_root, 'cookbooks')
        Chef::Config[:data_bag_path] = File.join(chef_root, 'data_bags')
        Chef::Config[:role_path]     = File.join(chef_root, 'roles')
      end

      def expand_role(chef_role, chef_environment)
        run_list = Chef::RunList.new
        run_list << "role[#{chef_role}]"

        expansion = run_list.expand(chef_environment, 'disk')
        raise RoleExpansionError if expansion.errors?

        [expansion.default_attrs, expansion.override_attrs]
      end

    end

  end
end
