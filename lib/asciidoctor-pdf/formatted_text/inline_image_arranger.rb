module Asciidoctor::Pdf::FormattedText
module InlineImageArranger
  #ImagePlaceholderChar = [0x00a0].pack 'U*'
  ImagePlaceholderChar = '.'
  begin
    require 'thread_safe' unless defined? ::ThreadSafe
    CalculatedFragmentWidths = ::ThreadSafe::Cache.new
  rescue
    CalculatedFragmentWidths = {}
  end

  if RUBY_MIN_VERSION_2
    def wrap fragments
      arrange_images fragments
      super
    end
  else
    class << self
      def extended base
        base.class.__send__ :alias_method, :_initial_wrap, :wrap
      end
    end

    def wrap fragments
      arrange_images fragments
      _initial_wrap fragments
    end
  end

  def arrange_images fragments
    doc = @document
    scratch = doc.scratch?
    fragments.select {|f| f.key? :image_path }.each do |fragment|
      spacer_w = width_of_fragment fragment.merge(text: ImagePlaceholderChar), doc

      if (image_w = fragment[:image_width])
        image_w *= 0.75
      end

      # TODO make helper method to calculate width and height of image
      case (fragment[:image_type] = ::File.extname(image_path = fragment[:image_path])[1..-1].downcase)
      when 'svg'
        svg_obj = ::Prawn::Svg::Interface.new ::IO.read(image_path), doc, at: doc.bounds.top_left, width: image_w
        if image_w
          fragment[:image_width] = svg_obj.document.sizing.output_width
          fragment[:image_height] = svg_obj.document.sizing.output_height
        else
          fragment[:image_width] = svg_obj.document.sizing.output_width * 0.75
          fragment[:image_height] = svg_obj.document.sizing.output_height * 0.75
        end
        fragment[:image_obj] = svg_obj
      else
        # FIXME would be good if we could cache object information (maybe Prawn already does this?)
        image_obj, image_info = doc.build_image_object image_path
        if image_w
          fragment[:image_width], fragment[:image_height] = image_info.calc_image_dimensions width: image_w
        else
          fragment[:image_width] = image_info.width * 0.75
          fragment[:image_height] = image_info.height * 0.75
        end
        fragment[:image_obj] = image_obj
        fragment[:image_info] = image_info
      end

      # NOTE make room for the image by repeating the image placeholder character
      # TODO could use character spacing as an alternative to repeating characters
      fragment[:text] = ImagePlaceholderChar * (fragment[:image_width] / spacer_w).ceil

      # NOTE skip rendering image in scratch document (may have to rethink if image is allowed to change line height)
      if scratch
        fragment.delete :callback
        fragment.delete :image_obj
        fragment.delete :image_info
        # TODO move unlink to an ensure clause in case reading images fails
        ::File.unlink image_path if fragment[:image_tmp]
      end
    end
  end

  # Calculate the width of the specified fragment's text, taking into account
  # font family, size and style.
  #--
  # FIXME move method to Prawn::Document via extension (dropping doc argument)
  def width_of_fragment fragment, doc
    f_info = doc.font_info
    f_family = fragment[:font] || f_info[:family]
    f_size = fragment[:size] || f_info[:size]
    f_style = if (f_styles = fragment[:styles]).include? :bold
      (f_styles.include? :italic) ? :bold_italic : :bold
    elsif f_styles.include? :italic
      :italic
    else
      :normal
    end
    f_text = fragment[:text]
    f_key = [f_family, f_size, f_style, f_text]
    if (fragment_w = CalculatedFragmentWidths[f_key])
      return fragment_w
    end
    doc.font f_family, size: f_size, style: f_style do
      fragment_w = doc.width_of f_text
    end
    CalculatedFragmentWidths[f_key] = fragment_w
  end
end

if RUBY_MIN_VERSION_2
  ::Prawn::Text::Formatted::Box.prepend InlineImageArranger
else
  ::Prawn::Text::Formatted::Box.extensions << InlineImageArranger
end
end
