class Hash
  def deep_merge!(other_hash)
    merge!(other_hash) do |key, oldval, newval|
      # Coerce Chef-style attribute hashes to generic ones
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)

      oldval.class.to_s == 'Hash' &&
        newval.class.to_s == 'Hash' ?
          oldval.deep_merge!(newval) : newval
    end
  end
end
