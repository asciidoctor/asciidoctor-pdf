module Asciidoctor::Pdf::FormattedText
module InlineImageArranger
  #ImagePlaceholderChar = [0x00a0].pack 'U*'
  ImagePlaceholderChar = '.'
  begin
    require 'thread_safe' unless defined? ::ThreadSafe
    PlaceholderWidthCache = ::ThreadSafe::Cache.new
  rescue
    PlaceholderWidthCache = {}
  end

  if ::RUBY_MIN_VERSION_2
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

  # Iterates over the fragments that represent inline images and prepares the
  # image data to be embedded into the document.
  #
  # This method populates the image_width, image_height, image_obj and
  # image_info (PNG only) keys on the fragment. The text is replaced with
  # placeholder text that will be used to reserve enough room in the line to
  # fit the image.
  #
  # The image height is scaled down to 75% of the specified width (px to pt
  # conversion). If the image height is more than 1.5x the height of the
  # surrounding line of text, the font size and line metrics of the fragment
  # are modified to fit the image in the line.
  #
  # If this is the scratch document, the image renderer callback is removed so
  # that the image is not embedded.
  def arrange_images fragments
    doc = @document
    scratch = doc.scratch?
    fragments.select {|f| f.key? :image_path }.each do |fragment|
      begin
        if (image_w = fragment[:image_width])
          image_w *= 0.75
        end

        image_path = fragment[:image_path]

        # TODO make helper method to calculate width and height of image
        case (fragment[:image_type] = (::File.extname image_path)[1..-1].downcase)
        when 'svg'
          svg_obj = ::Prawn::Svg::Interface.new (::IO.read image_path), doc, at: doc.bounds.top_left, width: image_w
          if image_w
            fragment[:image_width] = svg_obj.document.sizing.output_width
            fragment[:image_height] = svg_obj.document.sizing.output_height
          else
            fragment[:image_width] = svg_obj.document.sizing.output_width * 0.75
            fragment[:image_height] = svg_obj.document.sizing.output_height * 0.75
          end
          fragment[:image_obj] = svg_obj
        else
          # TODO would be good if we could cache object information (maybe Prawn already does this?)
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

        spacer_w = nil
        doc.fragment_font fragment do
          # NOTE if image height exceeds line height by more than 1.5x, increase the line height
          # HACK we could really use a nicer API from Prawn here; this is an ugly hack
          if (f_height = fragment[:image_height]) > ((line_font = doc.font).height * 1.5)
            fragment[:ascender] = f_height
            fragment[:descender] = line_font.descender
            doc.font_size(fragment[:size] = f_height * (doc.font_size / line_font.height))
            fragment[:increased_line_height] = true
          end

          unless (spacer_w = PlaceholderWidthCache[f_info = doc.font_info])
            spacer_w = PlaceholderWidthCache[f_info] = doc.width_of ImagePlaceholderChar
          end
        end

        # NOTE make room for the image by repeating the image placeholder character
        # TODO could use character spacing as an alternative to repeating characters
        # HACK we could use a nicer API from Prawn here to reserve width in a line
        fragment[:text] = ImagePlaceholderChar * (fragment[:image_width] / spacer_w).ceil
        #fragment[:width] = fragment[:image_width]
      ensure
        # NOTE skip rendering image in scratch document
        if scratch
          fragment.delete :callback
          fragment.delete :image_obj
          fragment.delete :image_info
          # NOTE in main document, tmp image path is unlinked by renderer
          ::File.unlink image_path if fragment[:image_tmp]
        end
      end
    end
  end
end

if ::RUBY_MIN_VERSION_2
  ::Prawn::Text::Formatted::Box.prepend InlineImageArranger
else
  ::Prawn::Text::Formatted::Box.extensions << InlineImageArranger
end
end
