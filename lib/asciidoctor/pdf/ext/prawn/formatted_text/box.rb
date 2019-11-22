# frozen_string_literal: true
Prawn::Text::Formatted::Box.prepend (Module.new do
  def draw_fragment_overlay_styles fragment
    if (underline = (styles = fragment.styles).include? :underline) || (styles.include? :strikethrough)
      (doc = fragment.document).save_graphics_state do
        if (text_decoration_width = (fs = fragment.format_state)[:text_decoration_width])
          doc.line_width = text_decoration_width
        end
        if (text_decoration_color = fs[:text_decoration_color])
          doc.stroke_color = text_decoration_color
        end
        underline ? (doc.stroke_line fragment.underline_points) : (doc.stroke_line fragment.strikethrough_points)
      end
    end
  end
end)
