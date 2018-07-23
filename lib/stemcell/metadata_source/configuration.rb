require 'json'

module Stemcell
  class MetadataSource

    class Configuration
      attr_reader :config_path

      attr_reader :all_options
      attr_reader :default_options
      attr_reader :backing_store_options
      attr_reader :availability_zones

      def initialize(config_path)
        @config_path = config_path
        if config_path.nil?
          raise ArgumentError, "You must specify a configuration file"
        end

        read_configuration
        validate_configutation
      end

      def options_for_backing_store(backing_store, region)
        options = backing_store_options[backing_store]
        raise UnknownBackingStoreError.new(backing_store) if options.nil?
        options.fetch(region, options)
      end

      def random_az_for_region(region)
        (availability_zones[region] || []).sample
      end

      private

      def read_configuration
        begin
          @all_options = JSON.parse(File.read(config_path))
        rescue Errno::ENOENT
          raise Stemcell::MissingMetadataConfigError
        rescue => e
          raise Stemcell::MetadataConfigParseError, e.message
        end

        @default_options       = @all_options['defaults']
        @backing_store_options = @all_options['backing_store']
        @availability_zones    = @all_options['availability_zones']
      end

      def validate_configutation
        errors = []

        if default_options.nil?
          errors << "missing required section 'defaults'; " \
                    "should be a hash containing default launch options"
        end

        if backing_store_options.nil? || backing_store_options.empty?
          errors << "missing or empty section 'backing_store'"
          errors << "'backing_store' should be a hash from " \
                    "store type (like 'ebs') => hash of options for that store"
        end

        if availability_zones.nil?
          errors << "missing or empty section 'availability_zones'"
          errors << "'availability_zones' should be a hash from " \
                    "region name => list of allowed zones in that region"
        end

        unless errors.empty?
          raise Stemcell::MetadataConfigParseError, errors.join("; ")
        end
      end
    end

  end
end
