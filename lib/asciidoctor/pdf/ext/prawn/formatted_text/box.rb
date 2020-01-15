# frozen_string_literal: true

Prawn::Text::Formatted::Box.prepend (Module.new do
  def draw_fragment_overlay_styles fragment
    if (underline = (styles = fragment.styles).include? :underline) || (styles.include? :strikethrough)
      (doc = fragment.document).save_graphics_state do
        if (text_decoration_width = (fs = fragment.format_state)[:text_decoration_width] || doc.text_decoration_width)
          doc.line_width = text_decoration_width
        end
        if (text_decoration_color = fs[:text_decoration_color])
          doc.stroke_color = text_decoration_color
        end
        underline ? (doc.stroke_line fragment.underline_points) : (doc.stroke_line fragment.strikethrough_points)
      end
    end
  end

  def process_vertical_alignment text
    return super if ::Symbol === (valign = @vertical_align)

    return if defined? @vertical_alignment_processed
    @vertical_alignment_processed = true

    valign, offset = valign

    if valign == :top
      @at[1] -= offset
      return
    end

    wrap text
    h = height

    case valign
    when :center
      @at[1] -= (@height - h + @descender) * 0.5 + offset
    when :bottom
      @at[1] -= (@height - h) + offset
    end

    @height = h
  end
end)
