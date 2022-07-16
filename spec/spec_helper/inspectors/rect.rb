# frozen_string_literal: true

class RectInspector < PDF::Inspector
  attr_reader :rectangles

  alias rects rectangles

  def initialize
    @next_rectangle = nil
    @rectangles = []
    @fill_color = @stroke_color = @line_width = nil
    @page_number = 0
  end

  def page= page
    @page_number = page.number
  end

  # re
  def append_rectangle x, y, width, height
    @next_rectangle = { point: [x, y], width: width, height: height, page_number: @page_number }
  end

  # f
  def fill_path_with_nonzero
    if @next_rectangle
      @rectangles << (@next_rectangle.merge fill_color: @fill_color)
      @next_rectangle = nil
    end
  end

  # w
  def set_line_width line_width
    @line_width = line_width
  end

  # S
  def stroke_path
    if @next_rectangle
      @rectangles << (@next_rectangle.merge stroke_color: @stroke_color, stroke_width: @line_width)
      @next_rectangle = nil
    end
  end

  # scn
  def set_color_for_nonstroking_and_special *params
    @fill_color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| sprintf '%02X', (it.to_f * 255).round }.join
  end

  # SCN
  def set_color_for_stroking_and_special *params
    @stroke_color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| sprintf '%02X', (it.to_f * 255).round }.join
  end
end
