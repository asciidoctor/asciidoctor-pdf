# frozen_string_literal: true

RSpec::Matchers.define :have_background do |expected|
  match do |actual|
    color = ((expected[:color].scan %r/../).map {|it| ((it.to_i 16) / 255.0).round 5 }.join ' ') + ' scn'
    # FIXME: shave off lines before this line
    (expect actual).to include color
    x1, y1 = expected[:top_left]
    x2, y2 = expected[:bottom_right]
    (expect actual).to include %(#{x2} #{y1} #{x2} #{y1} #{x2} #{y1} c)
    (expect actual).to include %(#{x1} #{y2} #{x1} #{y2} #{x1} #{y2} c)
  end
  failure_message {|actual| %(expected #{actual} to have background #{expected}, but was \n#{actual.join ?\n}) }
end
