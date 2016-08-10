class Array
  if RUBY_VERSION < '2.1.0'
    def to_h
      Hash[to_a]
    end unless method_defined? :to_h
  end

  def delete_all *entries
    entries.map {|entry| delete entry }.compact
  end unless method_defined? :delete_all
end
