require 'stemcell/metadata_source/chef_repository'
require 'stemcell/metadata_source/configuration'

module Stemcell
  class MetadataSource
    include Chef::Mixin::DeepMerge

    attr_reader :chef_root
    attr_reader :config_filename

    attr_reader :config
    attr_reader :chef_repo

    DEFAULT_CONFIG_FILENAME = 'stemcell.json'
    DEFAULT_BACKING_STORE = 'instance_store'

    DEFAULT_OPTIONS = {
      'chef_environment' => 'production',
      'git_branch'       => 'production',
      'count'            => 1,
      'instance_hostname' => '',
      'instance_domain_name' => '',
      'chef_package_source' => 'http://www.opscode.com/chef/download?p=${platform}&pv=${platform_version}&m=${arch}&v=${chef_version}&prerelease=false',
      'chef_version'      => '11.4.0',
    }

    def initialize(chef_root, config_filename=DEFAULT_CONFIG_FILENAME)
      @chef_root = chef_root
      @config_filename = config_filename

      if chef_root.nil?
        raise ArgumentError, "You must specify a chef repository"
      end
      if config_filename.nil?
        raise ArgumentError, "You must specify a configuration file"
      end

      @config = Configuration.new(File.join(chef_root, config_filename))
      @chef_repo = ChefRepository.new(chef_root)
    end

    def default_options
      DEFAULT_OPTIONS.merge(config.default_options)
    end

    def expand_role(role, environment, contexts=[], override_options={}, options={})
      raise ArgumentError, "Missing chef role" unless role
      raise ArgumentError, "Missing chef environment" unless environment
      allow_empty_roles = options.fetch(:allow_empty_roles, false)

      # Normal and cookbook attributes to load during role metadata expansion
      normal_attributes     = options.fetch(:normal_attributes, {})
      cookbook_attributes   = override_options['chef_cookbook_attributes']
      cookbook_attributes ||= config.default_options['chef_cookbook_attributes']
      cookbook_attributes ||= []

      chef_options = {}
      chef_options[:cookbook_attributes] = cookbook_attributes unless cookbook_attributes.empty?
      chef_options[:normal_attributes] = normal_attributes unless normal_attributes.empty?

      # Step 1: Expand the role metadata
      role_options = chef_repo.metadata_for_role(role, environment, chef_options)
      role_empty   = role_options.nil? || role_options.empty?

      raise EmptyRoleError if !allow_empty_roles && role_empty

      # Step 1.5: Override context specific values
      if !role_empty
        context_overrides = role_options['context_overrides'] || {}
        contexts.each do |context|
          overriding_hash = context_overrides[context]
          role_options.merge!(overriding_hash) if overriding_hash
        end
        role_options.delete('context_overrides')
      end

      # Step 2: Determine the backing store from available options.

      # This is determined distinctly from the merge sequence below because
      # the backing store options must be available to the operation.

      backing_store   = override_options['backing_store']
      backing_store ||= role_options.to_hash['backing_store'] if role_options
      backing_store ||= config.default_options['backing_store']
      backing_store ||= DEFAULT_BACKING_STORE

      backing_store_region   = override_options['region']
      backing_store_region ||= role_options.to_hash['region'] if role_options
      backing_store_region ||= config.default_options['region']
      backing_store_region ||= DEFAULT_OPTIONS['region']

      # Step 3: Retrieve the backing store options from the defaults.

      backing_store_options = config.options_for_backing_store(backing_store, backing_store_region)
      backing_store_options['backing_store'] = backing_store

      # Step 4: Merge the options together in priority order.

      merged_options = DEFAULT_OPTIONS.dup
      merged_options.merge!(config.default_options)
      merged_options.merge!(backing_store_options)
      merged_options.merge!(role_options.to_hash) if role_options
      merged_options.merge!(override_options)

      # Step 5: If no availability zone was specified, select one at random.

      if merged_options['availability_zone'].nil? && merged_options['region']
        merged_options['availability_zone'] ||=
          config.random_az_for_region(merged_options['region'])
      end

      # Step 6: Mandate that the environment and role were as specified.

      merged_options['chef_environment'] = environment
      merged_options['chef_role'] = role

      merged_options
    end
  end
end
