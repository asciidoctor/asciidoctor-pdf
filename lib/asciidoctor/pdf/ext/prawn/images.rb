# frozen_string_literal: true

module Asciidoctor
  module Prawn
    module Images
      # Dispatch to suitable image method in Prawn based on file extension.
      def image file, opts = {}
        # FIXME: handle case when SVG is an IO object
        if ::String === file
          if ((opts = opts.merge).delete :format) == 'svg' || (file.downcase.end_with? '.svg')
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

      # Override built-in method to cache info separately from obj.
      def build_image_object file
        if ::File === file
          cache_key = ((::File.absolute_path? (file_path = file.path)) ? file_path : (File.absolute_path file_path)).to_sym
          info = image_info_cache[cache_key]
        end
        unless info
          image_content = verify_and_read_image file
          if cache_key || !(info = image_info_cache[(cache_key = ::Digest::SHA1.hexdigest image_content)])
            # build the image object
            info = (::Prawn.image_handler.find image_content).new image_content
            renderer.min_version info.min_pdf_version if info.respond_to? :min_pdf_version
            image_info_cache[cache_key] = info
          end
        end
        # reuse image if it has already been embedded
        unless (image_obj = image_registry[cache_key])
          # add the image to the PDF then register it in case we see it again
          image_registry[cache_key] = image_obj = info.build_pdf_object self
        end
        [image_obj, info]
      end

      def recommend_prawn_gmagick? err, image_format
        ::Prawn::Errors::UnsupportedImageType === err && !(defined? ::GMagick::Image) && ((err.message.include? 'PNG') || (%w(jpg png).none? image_format))
      end

      def image_info_cache
        @image_info_cache ||= {}
      end
    end

    ::Prawn::Document.extensions << Images
  end
end
