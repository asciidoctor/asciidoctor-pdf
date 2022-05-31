# frozen_string_literal: true

module Asciidoctor
  module Prawn
    module Images
      # Dispatch to suitable image method in Prawn based on file extension.
      def image file, opts = {}
        # FIXME: handle case when SVG is an IO object
        if ::String === file
          if ((opts = opts.dup).delete :format) == 'svg' || (file.downcase.end_with? '.svg')
            #opts[:enable_file_requests_with_root] = (::File.dirname file) unless opts.key? :enable_file_requests_with_root
            #opts[:enable_web_requests] = allow_uri_read if !(opts.key? :enable_web_requests) && (respond_to? :allow_uri_read)
            #opts[:cache_images] = cache_uri if !(opts.key? :cache_images) && (respond_to? :cache_uri)
            #opts[:fallback_font_name] = fallback_svg_font_name if !(opts.key? :fallback_font_name) && (respond_to? :fallback_svg_font_name)
            if (fit = opts.delete :fit) && !(opts[:width] || opts[:height])
              image_info = svg (::File.read file, mode: 'r:UTF-8'), opts do |svg_doc|
                # NOTE: fit to specified width, then reduce size if height exceeds bounds
                svg_doc.calculate_sizing requested_width: fit[0] if svg_doc.sizing.output_width != fit[0]
                svg_doc.calculate_sizing requested_height: fit[1] if svg_doc.sizing.output_height > fit[1]
              end
            else
              image_info = svg (::File.read file, mode: 'r:UTF-8'), opts
            end
            if ::Asciidoctor::Logging === self && !scratch? && !(warnings = image_info[:warnings]).empty?
              warnings.each {|warning| log :warn, %(problem encountered in image: #{file}; #{warning}) }
            end
            image_info
          else
            ::File.open(file, 'rb') {|fd| super fd, opts }
          end
        else
          super
        end
      end

      # Retrieve the intrinsic image dimensions for the specified path in pt.
      #
      # Returns a Hash containing :width and :height keys that map to the image's
      # intrinsic width and height values (in pt).
      def intrinsic_image_dimensions path, format
        if format == 'svg'
          # NOTE: prawn-svg computes intrinsic width and height in pt
          img_obj = ::Prawn::SVG::Interface.new (::File.read path, mode: 'r:UTF-8'), self, {}
          img_size = img_obj.document.sizing
          { width: img_size.output_width, height: img_size.output_height }
        else
          # NOTE: build_image_object caches image data previously loaded
          # NOTE: build_image_object computes intrinsic width and height in px
          _, img_size = ::File.open(path, 'rb') {|fd| build_image_object fd }
          { width: (to_pt img_size.width, :px), height: (to_pt img_size.height, :px) }
        end
      rescue
        # NOTE: image cannot be read, so it won't be used anyway
        { width: 0, height: 0 }
      end

      def recommend_prawn_gmagick? err, image_format
        ::Prawn::Errors::UnsupportedImageType === err && !(defined? ::GMagick::Image) && ((err.message.include? 'PNG') || (%w(jpg png).none? image_format))
      end
    end

    ::Prawn::Document.extensions << Images
  end
end
