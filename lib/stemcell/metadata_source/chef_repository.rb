require 'chef'

module Stemcell
  class MetadataSource

    class ChefRepository
      include Chef::Mixin::DeepMerge

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
      def metadata_for_role(chef_role, chef_environment, chef_options = {})
        attrs = expand_role(chef_role, chef_environment, chef_options)
        METADATA_ATTRIBUTES.inject(nil) { |r, key| r || attrs[key] }
      end

      private

      def configure_chef
        Chef::Config[:cookbook_path] = File.join(chef_root, 'cookbooks')
        Chef::Config[:data_bag_path] = File.join(chef_root, 'data_bags')
        Chef::Config[:role_path]     = File.join(chef_root, 'roles')
      end

      def expand_role(chef_role, chef_environment, chef_options)
        node = Chef::Node.new
        node.chef_environment = chef_environment
        node.run_list << "role[#{chef_role}]"

        normal_attributes = chef_options.fetch(:normal_attributes, {})
        node.consume_attributes(normal_attributes)

        # Load cookbooks.
        cookbook_loader = Chef::CookbookLoader.new(Chef::Config[:cookbook_path])
        cookbook_attributes = chef_options.fetch(:cookbook_attributes, [])
        cookbook_attributes.each do |file_spec|
          cookbook_name, * = node.parse_attribute_file_spec(file_spec)
          cookbook_loader.load_cookbook(cookbook_name)
        end

        cookbook_collection = Chef::CookbookCollection.new(cookbook_loader.cookbooks_by_name)
        events = Chef::EventDispatch::Dispatcher.new
        run_context = Chef::RunContext.new(node, cookbook_collection, events)

        # Expand the node's run list.
        expansion = node.run_list.expand(chef_environment, 'disk')
        raise RoleExpansionError if expansion.errors?

        # Set the default and override attributes.
        node.attributes.role_default = expansion.default_attrs
        node.attributes.role_override = expansion.override_attrs

        # Load cookbook attributes.
        cookbook_attributes.each do |file_spec|
          node.include_attribute(file_spec)
        end

        Mash.new(node.attributes.to_hash)
      end

    end

  end
end
