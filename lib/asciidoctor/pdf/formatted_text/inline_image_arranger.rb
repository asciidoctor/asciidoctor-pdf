# frozen_string_literal: true

module Asciidoctor::PDF::FormattedText
  module InlineImageArranger
    include ::Asciidoctor::PDF::Measurements
    include ::Asciidoctor::Logging

    PlaceholderChar = ::Asciidoctor::Prawn::Extensions::PlaceholderChar

    def wrap fragments
      arrange_images fragments
      super
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
    # When this method is called, the cursor is positioned at start of where this
    # group of fragments will be written (offset by the leading padding).
    #
    # This method is called each time the set of fragments overflow to another
    # page, so it's necessary to short-circuit if that case is detected.
    def arrange_images fragments
      doc = @document
      return if (raw_image_fragments = fragments.select {|f| (f.key? :image_path) && !(f.key? :image_obj) }).empty?
      scratch = doc.scratch?
      available_w = available_width
      available_h = doc.bounds.height
      last_fragment = {}
      raw_image_fragments.each do |fragment|
        if fragment[:object_id] == last_fragment[:object_id]
          fragments.delete fragment
          next
        else
          drop = scratch
        end
        image_path = fragment[:image_path]
        image_format = fragment[:image_format]
        if (image_w = fragment[:image_width] || '100%') == 'auto'
          image_w = nil # use intrinsic width
        elsif image_w.start_with? 'auto*'
          image_scale = (image_w.slice 5, image_w.length).to_f
          image_w = nil # use intrinsic width
        elsif (pctidx = image_w.index '%') && pctidx + 1 < image_w.length
          # NOTE: intrinsic width is stored behind % symbol
          pct = (image_w.slice 0, pctidx).to_f / 100
          intrinsic_w = (image_w.slice pctidx + 1, image_w.length).to_f
          image_w = [available_w, pct * intrinsic_w].min
        else
          image_w = [available_w, pctidx ? (image_w.to_f / 100 * available_w) : image_w.to_f].min
        end

        if (fit = fragment[:image_fit]) === 'line'
          max_image_h = [available_h, doc.font.height].min
        elsif fit == 'none'
          max_image_h = doc.margin_box.height
        elsif doc.bounds.instance_variable_get :@table_cell
          max_image_h = doc.bounds.parent.height
        else
          max_image_h = available_h
        end

        # TODO: make helper method to calculate width and height of image
        if image_format == 'svg'
          svg_obj = ::Prawn::SVG::Interface.new ::File.read(image_path, mode: 'r:UTF-8'), doc,
            at: doc.bounds.top_left,
            width: image_w,
            fallback_font_name: doc.fallback_svg_font_name,
            enable_web_requests: doc.allow_uri_read ? (doc.method :load_open_uri).to_proc : false,
            enable_file_requests_with_root: { base: (::File.dirname image_path), root: doc.jail_dir },
            cache_images: doc.cache_uri
          svg_size = svg_obj.document.sizing
          # NOTE: the best we can do is make the image fit within full height of bounds
          if (image_h = svg_size.output_height) > max_image_h
            image_w = (svg_obj.resize height: (image_h = max_image_h)).output_width
          elsif image_w
            image_w = svg_size.output_width
          else
            fragment[:image_width] = (image_w = svg_size.output_width).to_s
            image_w *= image_scale if image_scale
            image_w = available_w if image_w > available_w
          end
          fragment[:image_obj] = svg_obj
        else
          # TODO: cache image info based on path (Prawn caches based on SHA1 of content)
          # NOTE: image_obj is constrained to image_width by renderer
          image_obj, image_info = ::File.open(image_path, 'rb') {|fd| doc.build_image_object fd }
          unless image_w
            fragment[:image_width] = (image_w = to_pt image_info.width, :px).to_s
            image_w *= image_scale if image_scale
            image_w = available_w if image_w > available_w
          end
          if (image_h = image_w * (image_info.height.fdiv image_info.width)) > max_image_h
            # NOTE: the best we can do is make the image fit within full height of bounds
            image_w = (image_h = max_image_h) * (image_info.width.fdiv image_info.height)
          end
          fragment[:image_obj] = image_obj
          fragment[:image_info] = image_info
        end

        doc.save_font do
          # NOTE: if image height exceeds line height by more than 1.5x, increase the line height
          # FIXME: we could really use a nicer API from Prawn here; this is an ugly hack
          if (f_height = image_h) > (line_font = doc.font).height * 1.5
            # align with descender (equivalent to vertical-align: bottom in CSS)
            fragment[:ascender] = f_height - (fragment[:descender] = line_font.descender)
            if f_height == available_h
              fragment[:ascender] -= (doc.calc_line_metrics (doc.instance_variable_get :@base_line_height), line_font, doc.font_size).padding_top
              fragment[:full_height] = true
            end
            doc.font_size (fragment[:size] = f_height * (doc.font_size / line_font.height))
            # align with baseline (roughly equivalent to vertical-align: baseline in CSS)
            #fragment[:ascender] = f_height
            #fragment[:descender] = 0
            #doc.font_size(fragment[:size] = (f_height + line_font.descender) * (doc.font_size / line_font.height))
            fragment[:line_height_increased] = true
          end
        end

        # NOTE: we can't rely on the fragment width because the line wrap mechanism ignores it;
        # it only considers the text (string) and character spacing, rebuilding the string several times
        fragment[:text] = PlaceholderChar
        fragment[:actual_character_spacing] = doc.character_spacing
        fragment[:character_spacing] = image_w
        fragment[:image_width] = fragment[:width] = image_w
        fragment[:image_height] = image_h
      rescue
        logger.warn %(could not embed image: #{image_path}; #{$!.message}#{(doc.recommend_prawn_gmagick? $!, image_format) ? %(; install prawn-gmagick gem to add support for #{image_format&.upcase || 'unknown'} image format) : ''}) unless scratch
        drop = true # delegate to cleanup logic in ensure block
      ensure
        # NOTE: skip rendering image in scratch document or if image can't be loaded
        if drop
          fragment.delete :callback
          fragment.delete :image_info
          # NOTE: retain key to indicate we've visited fragment already
          fragment[:image_obj] = nil
        end
        last_fragment = fragment
      end
    end
  end

  ::Prawn::Text::Formatted::Box.prepend InlineImageArranger
end
