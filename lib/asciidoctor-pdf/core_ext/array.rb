class Array
  def delete_all *entries
    entries.map {|entry| delete entry }.compact
  end unless method_defined? :delete_all
end
