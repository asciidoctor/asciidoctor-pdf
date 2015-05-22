class Array
  def to_h
    Hash[to_a]
  end unless respond_to? :to_h
end if RUBY_VERSION < '2.1.0'
