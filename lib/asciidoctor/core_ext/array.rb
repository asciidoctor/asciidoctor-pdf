class Array
  def to_h
    Hash[*self]
  end unless respond_to? :to_h
end
