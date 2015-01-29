module Stemcell
  # This is the class from which all stemcell errors descend.
  class Error < StandardError; end

  class MissingMetadataConfigError < Error; end
  class MetadataConfigParseError < Error; end

  class RoleExpansionError < Error; end
  class EmptyRoleError < Error; end

  class UnknownBackingStoreError < Error
    attr_reader :backing_store
    def initialize(backing_store)
      super "Unknown backing store: #{backing_store}"
      @backing_store = backing_store
    end
  end

  class MissingStemcellOptionError < Error
    attr_reader :option
    def initialize(option)
      super "Missing option: #{option}"
      @option = option
    end
  end

  class IncompleteOperation < Error
    attr_reader :operation, :all_instance_ids, :errors
    def initialize(operation, all_instance_ids, errors)
      super()
      @operation = operation
      @all_instance_ids = all_instance_ids
      @errors = errors
    end

    def message
      "Incomplete operation '#{@operation}': " +
      "all_instance_ids=#{@all_instance_ids.join('|')}; " +
      "errors=" + (@errors.map { |k, v| "'#{k}' => '#{v}'"}.join('|'))
    end
  end
end
