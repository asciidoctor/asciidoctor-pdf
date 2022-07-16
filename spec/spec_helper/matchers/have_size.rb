# frozen_string_literal: true

RSpec::Matchers.define :have_size do |expected|
  match {|actual| actual.size == expected }
  failure_message {|actual| %(expected #{actual} to have size #{expected}, but was #{actual.size}) }
end
