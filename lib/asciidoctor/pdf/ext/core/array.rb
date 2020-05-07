# frozen_string_literal: true

class Array
  def sum
    reduce(&:+)
  end unless method_defined? :sum
end
