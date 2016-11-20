module Asciidoctor::Pdf::FormattedText
module TextBackgroundFiller
  module_function

  # render_behind is called before the text is printed
  def render_behind fragment
    unless (pdf = fragment.document).scratch?
      data = fragment.format_state
      border_radius = data[:border_radius]
      if (background_color = data[:background_color])
        prev_fill_color = pdf.fill_color
        pdf.fill_color background_color
        if border_radius
          pdf.fill_rounded_rectangle fragment.top_left, fragment.width, fragment.height, border_radius
        else
          pdf.fill_rectangle fragment.top_left, fragment.width, fragment.height
        end
        pdf.fill_color prev_fill_color
      end
      if (border_width = data[:border_width])
        border_color = data[:border_color]
        prev_stroke_color = pdf.stroke_color
        prev_line_width = pdf.line_width
        pdf.stroke_color border_color
        pdf.line_width border_width
        if border_radius
          pdf.stroke_rounded_rectangle fragment.top_left, fragment.width, fragment.height
        else
          pdf.stroke_rectangle fragment.top_left, fragment.width, fragment.height, border_radius
        end
        pdf.stroke_color prev_stroke_color
        pdf.line_width prev_line_width
      end
    end
  end
end
end
