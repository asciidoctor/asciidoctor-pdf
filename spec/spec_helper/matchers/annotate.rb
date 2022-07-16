# frozen_string_literal: true

RSpec::Matchers.define :annotate do |text|
  match do |subject|
    left, bottom, right, top = subject[:Rect]
    left == text[:x] && ((text[:x] + text[:width]) - right).abs < 0.25 && bottom < text[:y] && top > (text[:y] + text[:font_size])
  end
  failure_message {|subject| %(expected #{subject} to annotate #{text}) }
end
