class Numeric
  def with_precision precision
    precision = precision.to_i
    if precision > 0
      factor = 10 ** precision
      (self * factor).truncate / factor.to_f
    else
      self.truncate
    end
  end unless method_defined? :with_precision
end
