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
    attr_reader :operation, :all_instances, :finished_instances, :errors
    def initialize(operation, all_instances)
      super()
      @operation = operation
      @all_instances = all_instances

      @finished_instances = []
      @errors = {}
    end

    def add_finished_instance(instance_id)
      @finished_instances << instance_id
      # an instance may run into an error and get fixed later
      @errors.delete(instance_id)
    end

    def add_error(instance_id, error)
      @errors[instance_id] = error
    end

    def message
      "Incomplete operation '#{@operation}': " +
      "all_instances=#{@all_instances.join('|')}; " +
      "finished_instances=#{@finished_instances.join('|')}; " +
      "errors=" + (@errors.map { |k, v| "'#{k}' => '#{v}'"}.join('|'))
    end
  end
end
