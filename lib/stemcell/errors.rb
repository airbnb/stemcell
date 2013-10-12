module Stemcell
  # This is the class from which all stemcell errors descend.
  class Error < StandardError; end

  class NoTemplateError < Error; end
  class TemplateParseError < Error; end
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
end
