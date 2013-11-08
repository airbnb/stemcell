require 'chef'
require 'json'

module Stemcell
  class MetadataSource
    attr_reader :chef_root
    attr_reader :default_options

    DEFAULT_OPTIONS = {
      'chef_environment' => 'production',
      'git_branch'       => 'production',
      'count'            => 1,
      'instance_hostname' => '',
      'instance_domain_name' => '',
      'chef_package_source' => 'http://www.opscode.com/chef/download?p=${platform}&pv=${platform_version}&m=${arch}&v=${chef_version}&prerelease=false',
      'chef_version'      => '11.4.0',
    }

    # Search for instance metadata in the following role attributes, with
    # priority given to the keys at the head.
    METADATA_ATTRIBUTES = [
      :instance_metadata,
      :stemcell
    ]

    def initialize(chef_root)
      @chef_root = chef_root

      raise ArgumentError, "You must specify a chef root" unless chef_root

      template_options = read_template
      @default_options = DEFAULT_OPTIONS.merge(template_options['defaults'])

      @all_backing_store_options = template_options['backing_store']
      @all_azs_by_region = template_options['availability_zones']
    end

    def expand_role(role, environment, override_options={}, options={})
      raise ArgumentError, "Missing chef role" unless role
      raise ArgumentError, "Missing chef environment" unless environment
      allow_empty_roles = options.fetch(:allow_empty_roles, false)

      role_options = expand_role_options(role, environment)
      role_empty   = role_options.nil? || role_options.empty?

      raise EmptyRoleError if !allow_empty_roles && role_empty

      backing_store_options =
        expand_backing_store_options(
            default_options,
            role_options,
            override_options
          )

      # Merge all the options together in priority order
      merged_options = default_options.dup
      merged_options.deep_merge!(backing_store_options)
      merged_options.deep_merge!(role_options) if role_options
      merged_options.deep_merge!(override_options)

      # Add the AZ if not specified
      if (region = merged_options['region'])
        merged_options['availability_zone'] ||= random_az_in_region(region)
      end

      # The chef environment and role used to expand the runlist takes
      # priority over all other options.
      merged_options['chef_environment'] = environment
      merged_options['chef_role']        = role

      merged_options
    end

    private

    def read_template
      begin
        template_path = File.join(chef_root, 'stemcell.json')
        template_options = JSON.parse(IO.read(template_path))
      rescue Errno::ENOENT
        raise NoTemplateError
      rescue => e
        raise TemplateParseError, e.message
      end

      errors = []
      unless template_options.include?('defaults')
        errors << 'missing required section "defaults"; should be a hash containing default launch options'
      end

      if template_options['availability_zones'].nil?
        errors << 'missing or empty section "availability zones"'
        errors << '"availability_zones" should be a hash from region name => list of allowed zones in that region'
      end

      if template_options['backing_store'].nil? or template_options['backing_store'].empty?
        errors << 'missing or empty section "backing_store"'
        errors << '"backing_store" should be a hash from store type (like "ebs") => hash of options for that store'
      end

      unless errors.empty?
        raise TemplateParseError, errors.join("; ")
      end

       return template_options
    end

    def expand_role_options(chef_role, chef_environment)
      Chef::Config[:role_path] = File.join(chef_root, 'roles')
      Chef::Config[:data_bag_path] = File.join(chef_root, 'data_bags')

      run_list = Chef::RunList.new
      run_list << "role[#{chef_role}]"

      expansion = run_list.expand(chef_environment, 'disk')
      raise RoleExpansionError if expansion.errors?

      default_attrs = expansion.default_attrs
      override_attrs = expansion.override_attrs

      merged_attrs = default_attrs.merge(override_attrs)
      METADATA_ATTRIBUTES.inject(nil) { |r, key| r || merged_attrs[key] }
    end

    def expand_backing_store_options(default_opts, role_opts, override_opts)
      backing_store   = override_opts['backing_store']
      backing_store ||= role_opts.to_hash['backing_store'] if role_opts
      backing_store ||= default_opts['backing_store']
      backing_store ||= 'instance_store'

      backing_store_options = @all_backing_store_options[backing_store]
      if backing_store_options.nil?
        raise Stemcell::UnknownBackingStoreError.new(backing_store)
      end
      backing_store_options
    end

    def random_az_in_region(region)
      possible_azs = @all_azs_by_region[region] || []
      possible_azs.sample
    end
  end
end
