module Asciidoctor::Pdf::FormattedText
module InlineImageArranger
  #ImagePlaceholderChar = %(\u00a0)
  ImagePlaceholderChar = '.'
  begin
    require 'thread_safe' unless defined? ::ThreadSafe
    PlaceholderWidthCache = ::ThreadSafe::Cache.new
  rescue
    PlaceholderWidthCache = {}
  end
  TemporaryPath = ::Asciidoctor::Pdf::TemporaryPath

  if respond_to? :prepend
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
  #
  # This method is called each time the set of fragments overflow to another
  # page, so it's necessary to short-circuit if that case is detected.
  def arrange_images fragments
    doc = @document
    available_w = doc.bounds.width
    scratch = doc.scratch?
    fragments.select {|f| (f.key? :image_path) && !(f.key? :image_obj) }.each do |fragment|
      begin
        image_path = fragment[:image_path]

        # NOTE only attempt to convert an unresolved String value
        if ::String === (image_w = fragment[:image_width])
          image_w = [
            available_w,
            (image_w.end_with? '%') ? (image_w.to_f / 100 * available_w) : image_w.to_f
          ].min
        end

        # TODO make helper method to calculate width and height of image
        if fragment[:image_format] == 'svg'
          svg_data = ::IO.read image_path
          svg_obj = ::Prawn::Svg::Interface.new svg_data, doc,
              at: (bounds_top_left = doc.bounds.top_left),
              width: image_w,
              fallback_font_name: doc.default_svg_font
          if image_w
            fragment[:image_width] = svg_obj.document.sizing.output_width
            fragment[:image_height] = svg_obj.document.sizing.output_height
          else
            # NOTE convert intrinsic dimensions to points
            if (fragment[:image_width] = doc.to_pt svg_obj.document.sizing.output_width, 'px') > available_w
              svg_obj = ::Prawn::Svg::Interface.new svg_data, doc,
                  at: bounds_top_left,
                  width: available_w,
                  fallback_font_name: doc.default_svg_font
              fragment[:image_width] = svg_obj.document.sizing.output_width
              fragment[:image_height] = svg_obj.document.sizing.output_height
            else
              fragment[:image_height] = doc.to_pt svg_obj.document.sizing.output_height, 'px'
            end
          end
          fragment[:image_obj] = svg_obj
        else
          # TODO cache image info based on path (Prawn caches based on SHA1 of content)
          image_obj, image_info = ::File.open(image_path, 'rb') {|fd| doc.build_image_object fd }
          if image_w
            fragment[:image_width], fragment[:image_height] = image_info.calc_image_dimensions width: image_w
          else
            # NOTE convert intrinsic dimensions to points
            if (fragment[:image_width] = doc.to_pt image_info.width, 'px') > available_w
              fragment[:image_width], fragment[:image_height] = image_info.calc_image_dimensions width: available_w
            else
              fragment[:image_height] = doc.to_pt image_info.height, 'px'
            end
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
            fragment[:line_height_increased] = true
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
      rescue => e
        warn %(asciidoctor: WARNING: could not embed image: #{image_path}; #{e.message})
        scratch = true # delegate to cleanup logic in ensure block
      ensure
        # NOTE skip rendering image in scratch document
        if scratch
          fragment.delete :callback
          fragment.delete :image_info
          # NOTE retain key to indicate we've visited this fragment already
          fragment[:image_obj] = nil
          # NOTE in main document, temporary image path is unlinked by renderer
          ::File.unlink image_path if TemporaryPath === image_path && image_path.exist?
        end
      end
    end
  end
end

if respond_to? :prepend
  class ::Prawn::Text::Formatted::Box
    prepend InlineImageArranger
  end
else
  ::Prawn::Text::Formatted::Box.extensions << InlineImageArranger
end
end
