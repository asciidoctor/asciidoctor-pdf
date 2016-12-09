class Numeric
  if (instance_method :truncate).arity == 0
    def truncate_to_precision precision
      if (precision = precision.to_i) > 0
        factor = 10 ** precision
        (self * factor).truncate.fdiv factor
      else
        truncate
      end
    end
  else
    # use native method in Ruby >= 2.4
    alias :truncate_to_precision :truncate
  end unless method_defined? :truncate_to_precision
end
