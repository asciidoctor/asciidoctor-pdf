class Array
  def to_h
    Hash[to_a]
  end unless respond_to? :to_h
end
