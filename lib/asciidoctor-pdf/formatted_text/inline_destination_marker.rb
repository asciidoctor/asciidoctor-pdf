module Asciidoctor::Pdf::FormattedText
module InlineDestinationMarker
  module_function

  # render_behind is called before the text is printed
  def render_behind fragment
    unless (pdf = fragment.document).scratch?
      if (name = fragment.format_state[:name])
        # get precise position of the reference (x, y)
        dest_rect = fragment.absolute_bounding_box
        pdf.add_dest name, (pdf.dest_xyz dest_rect.first, dest_rect.last)
      end
    end
  end
end
end
