module Asciidoctor::Pdf::FormattedText
module InlineImageRenderer
  module_function

  # Embeds the image object in this fragment into the document in place of the
  # text that was previously used to reserve space for the image in the line.
  #
  # If the image height is less than 1.5x the height of the surrounding text,
  # it is centered vertically in the line. If the image height is greater, then
  # the image is aligned to the bottom of the text.
  #
  # Note that render_behind is called before the text is printed.
  #
  # This handler is only used on the main document (not the scratch document).
  #
  def render_behind fragment
    pdf = fragment.document
    data = fragment.format_state
    image_top = if data.key? :line_height_increased
      # align image to bottom of line (differs from fragment.top by descender value)
      fragment.bottom + data[:image_height]
    else
      # center image in line
      fragment.top - ((fragment.height - data[:image_height]) / 2.0)
    end
    image_left = fragment.left + ((fragment.width - data[:image_width]) / 2.0)
    case data[:image_type]
    when 'svg'
      # prawn-svg messes with the cursor; use float as a workaround
      pdf.float do
        data[:image_obj].tap {|obj| obj.options[:at] = [image_left, image_top] }.draw
      end
    else
      pdf.embed_image data[:image_obj], data[:image_info], at: [image_left, image_top], width: data[:image_width]
    end
    # ...or use the public interface, loading the image again
    #pdf.image data[:image_path], at: [image_left, image_top], width: data[:image_width]

    # prevent any text from being written
    fragment.conceal
  ensure
    ::File.unlink data[:image_path] if data[:image_tmp]
  end
end
end
