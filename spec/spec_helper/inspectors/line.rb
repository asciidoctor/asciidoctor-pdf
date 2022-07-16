# frozen_string_literal: true

class LineInspector < PDF::Inspector
  attr_accessor :lines

  def initialize
    @lines = []
    @from = nil
    @color = nil
    @graphic_states = {}
    @page_number = 1
    @width = nil
    @dash = nil
  end

  def append_curved_segment *args
    x, y = args.pop 2
    @from = { x: x, y: y }
  end

  def append_line x, y
    style = @dash && @width ? (@dash[0] > @width ? :dashed : :dotted) : :solid
    @lines << { page_number: @page_number, from: @from, to: { x: x, y: y }, color: @color, width: @width, style: style } unless @color.nil? && @width.nil?
    @from = { x: x, y: y }
  end

  def begin_new_subpath x, y
    @from = { x: x, y: y }
  end

  def close_subpath
    @from = nil
  end

  def page= page
    @page_number = page.number
    @graphic_states = page.graphic_states
  end

  # SCN
  def set_color_for_stroking_and_special *params
    @color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| sprintf '%02X', (it.to_f * 255).round }.join
  end

  # gs
  def set_graphics_state_parameters ref
    if (opacity = @graphic_states[ref][:ca])
      @color += (sprintf '%02X', (opacity * 255).round)
    end
  end

  # d
  # NOTE: dash is often set before line width, so we must defer resolving until line is appended
  def set_line_dash a, _b
    @dash = a.empty? ? nil : a
  end

  # w
  def set_line_width line_width
    @width = line_width
  end

  # Q
  def restore_graphics_state
    @width = nil
  end
end
