module Asciidoctor::Pdf::FormattedText
module InlineImageRenderer
  module_function

  # render_behind is called before the text is printed
  # this handler is only used on the main document (not the scratch document)
  def render_behind fragment
    pdf = fragment.document
    data = fragment.format_state
    # QUESTION what if image height is more than fragment height?
    image_top = fragment.top - ((fragment.height - data[:image_height]) / 2.0)
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
