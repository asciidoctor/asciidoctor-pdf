# frozen_string_literal: true

class FormattedString < String
  attr_reader :fragments

  def initialize fragments
    super [].tap {|accum| (@fragments = fragments).each {|it| accum << it[:text] } }.join
  end

  def eql? other
    super && (FormattedString === other ? (@fragments ||= nil) == other.fragments : true)
  end
end
