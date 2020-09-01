# frozen_string_literal: true

Prawn::Font::AFM.instance_variable_set :@hide_m17n_warning, true

require 'prawn/icon'

Prawn::Icon::Compatibility.send :prepend, (::Module.new { def warning *_args; end })

module Asciidoctor
  module Prawn
    module Extensions
      include ::Asciidoctor::PDF::Measurements
      include ::Asciidoctor::PDF::Sanitizer
      include ::Asciidoctor::PDF::TextTransformer

      FontAwesomeIconSets = %w(fab far fas)
      IconSets = %w(fab far fas fi pf).to_set
      IconSetPrefixes = IconSets.map {|it| it + '-' }
      InitialPageContent = %(q\n)
      (FontStyleToSet = {
        bold: [:bold].to_set,
        italic: [:italic].to_set,
        bold_italic: [:bold, :italic].to_set,
      }).default = ::Set.new
      # NOTE: must use a visible char for placeholder or else Prawn won't reserve space for the fragment
      PlaceholderChar = ?\u2063

      # - :height is the height of a line
      # - :leading is spacing between adjacent lines
      # - :padding_top is half line spacing, plus any line_gap in the font
      # - :padding_bottom is half line spacing
      # - :final_gap determines whether a gap is added below the last line
      LineMetrics = ::Struct.new :height, :leading, :padding_top, :padding_bottom, :final_gap

      # Core

      # Retrieves the catalog reference data for the PDF.
      #
      def catalog
        state.store.root
      end

      # Retrieves the compatiblity version of the PDF.
      #
      def min_version
        state.version
      end

      # Measurements

      # Returns the width of the current page from edge-to-edge
      #
      def page_width
        page.dimensions[2]
      end

      # Returns the height of the current page from edge-to-edge
      #
      def page_height
        page.dimensions[3]
      end

      # Returns the effective (writable) height of the page
      #
      # If inside a fixed-height bounding box, returns height of box.
      #
      def effective_page_height
        reference_bounds.height
      end

      # Returns the height of the content area of the page
      #
      def page_content_height
        page_height - page_margin_top - page_margin_bottom
      end

      # remove once fixed upstream; see https://github.com/prawnpdf/prawn/pull/1122
      def generate_margin_box
        page_w, page_h = (page = state.page).dimensions.slice 2, 2
        page_m = page.margins
        prev_margin_box, @margin_box = @margin_box, (::Prawn::Document::BoundingBox.new self, nil, [page_m[:left], page_h - page_m[:top]], width: page_w - page_m[:left] - page_m[:right], height: page_h - page_m[:top] - page_m[:bottom])

        # update bounding box if not flowing from the previous page
        unless @bounding_box&.parent
          prev_margin_box = @bounding_box
          @bounding_box = @margin_box
        end

        # maintains indentation settings across page breaks
        if prev_margin_box
          @margin_box.add_left_padding prev_margin_box.total_left_padding
          @margin_box.add_right_padding prev_margin_box.total_right_padding
        end

        nil
      end

      # Set the margins for the current page.
      #
      def set_page_margin margin
        # FIXME: is there a cleaner way to set margins? does it make sense to override create_new_page?
        apply_margin_options margin: margin
        generate_margin_box
      end

      # Returns the margins for the current page as a 4 element array (top, right, bottom, left)
      #
      def page_margin
        [page_margin_top, page_margin_right, page_margin_bottom, page_margin_left]
      end

      # Returns the width of the left margin for the current page
      #
      def page_margin_left
        page.margins[:left]
      end

      # Returns the width of the right margin for the current page
      #
      def page_margin_right
        page.margins[:right]
      end

      # Returns the width of the top margin for the current page
      #
      def page_margin_top
        page.margins[:top]
      end

      # Returns the width of the bottom margin for the current page
      #
      def page_margin_bottom
        page.margins[:bottom]
      end

      # Returns the total left margin (to the page edge) for the current bounds.
      #
      def bounds_margin_left
        bounds.absolute_left
      end

      # Returns the total right margin (to the page edge) for the current bounds.
      #
      def bounds_margin_right
        page.dimensions[2] - bounds.absolute_right
      end

      # Returns the side the current page is facing, :recto or :verso.
      #
      def page_side pgnum = nil, invert = nil
        if invert
          (recto_page? pgnum) ? :verso : :recto
        else
          (verso_page? pgnum) ? :verso : :recto
        end
      end

      # Returns whether the page is a recto page.
      #
      def recto_page? pgnum = nil
        (pgnum || page_number).odd?
      end

      # Returns whether the page is a verso page.
      #
      def verso_page? pgnum = nil
        (pgnum || page_number).even?
      end

      # Returns whether the cursor is at the top of the page (i.e., margin box).
      #
      def at_page_top?
        @y == @margin_box.absolute_top
      end

      # Returns whether the current page is the last page in the document.
      #
      def last_page?
        page_number == page_count
      end

      # Destinations

      # Generates a destination object that resolves to the top of the page
      # specified by the page_num parameter or the current page if no page number
      # is provided. The destination preserves the user's zoom level unlike
      # the destinations generated by the outline builder.
      #
      def dest_top page_num = nil
        dest_xyz 0, page_height, nil, (page_num ? state.pages[page_num - 1] : page)
      end

      # Fonts

      # Registers a new custom font described in the data parameter
      # after converting the font name to a String.
      #
      # Example:
      #
      #  register_font Roboto: {
      #    normal: 'fonts/roboto-normal.ttf',
      #    italic: 'fonts/roboto-italic.ttf',
      #    bold: 'fonts/roboto-bold.ttf',
      #    bold_italic: 'fonts/roboto-bold_italic.ttf'
      #  }
      #
      def register_font data
        font_families.update data.transform_keys(&:to_s)
      end

      # Enhances the built-in font method to allow the font
      # size to be specified as the second option and to
      # lazily load font-based icons.
      #
      def font name = nil, options = {}
        if name
          options = { size: options } if ::Numeric === options
          if IconSets.include? name
            ::Prawn::Icon::FontData.load self, name
            options = options.reject {|k| k == :style } if options.key? :style
          end
        end
        super
      end

      # Retrieves the current font name (i.e., family).
      #
      def font_family
        font.options[:family]
      end

      alias font_name font_family

      # Retrieves the current font info (family, style, size) as a Hash
      #
      def font_info
        { family: font.options[:family], style: (font.options[:style] || :normal), size: @font_size }
      end

      # Set the font style on the document, if a style is given, otherwise return the current font style.
      #
      def font_style style = nil
        if style
          font font.options[:family], style: style
        else
          font.options[:style] || :normal
        end
      end

      # Applies points as a scale factor of the current font if the value provided
      # is less than or equal to 1 or it's a string (e.g., 1.1em), then delegates to the super
      # implementation to carry out the built-in functionality.
      #
      #--
      # QUESTION: should we round the result?
      def font_size points = nil
        return @font_size unless points
        if ::String === points
          if points.end_with? 'rem'
            super @root_font_size * points.to_f
          elsif points.end_with? 'em'
            super @font_size * points.to_f
          elsif points.end_with? '%'
            super @font_size * (points.to_f / 100)
          else
            super points.to_f
          end
        # NOTE: assume em value (since a font size of 1 is extremely unlikely)
        elsif points <= 1
          super @font_size * points
        else
          super points
        end
      end

      def resolve_font_style styles
        if styles.include? :bold
          (styles.include? :italic) ? :bold_italic : :bold
        elsif styles.include? :italic
          :italic
        else
          :normal
        end
      end

      # Retreives the collection of font styles from the given font style key,
      # which defaults to the current font style.
      #
      def font_styles style = font_style
        FontStyleToSet[style].dup
      end

      # Apply the font settings (family, size, styles and character spacing) from
      # the fragment to the document, then yield to the block.
      #
      # The original font settings are restored before this method returns.
      #
      def fragment_font fragment
        f_info = font_info
        f_family = fragment[:font] || f_info[:family]
        f_size = fragment[:size] || f_info[:size]
        if (f_styles = fragment[:styles])
          f_style = resolve_font_style f_styles
        else
          f_style = :normal
        end

        if (c_spacing = fragment[:character_spacing])
          character_spacing c_spacing do
            font f_family, size: f_size, style: f_style do
              yield
            end
          end
        else
          font f_family, size: f_size, style: f_style do
            yield
          end
        end
      end

      # Override width of string to check for placeholder char, which uses character spacing to control width
      #
      def width_of_string string, options = {}
        string == PlaceholderChar ? @character_spacing : super
      end

      def icon_font_data family
        ::Prawn::Icon::FontData.load self, family
      end

      def resolve_legacy_icon_name name
        ::Prawn::Icon::Compatibility::SHIMS[%(fa-#{name})]
      end

      def calc_line_metrics line_height = 1, font = self.font, font_size = self.font_size
        line_height_length = line_height * font_size
        leading = line_height_length - font_size
        half_leading = leading / 2
        padding_top = half_leading + font.line_gap
        padding_bottom = half_leading
        LineMetrics.new line_height_length, leading, padding_top, padding_bottom, false
      end

=begin
      # these line metrics attempted to figure out a correction based on the reported height and the font_size
      # however, it only works for some fonts, and breaks down for fonts like Noto Serif
      def calc_line_metrics line_height = 1, font = self.font, font_size = self.font_size
        line_height_length = font_size * line_height
        line_gap = line_height_length - font_size
        correction = font.height - font_size
        leading = line_gap - correction
        shift = (font.line_gap + correction + line_gap) / 2
        final_gap = font.line_gap != 0
        LineMetrics.new line_height_length, leading, shift, shift, final_gap
      end
=end

      # Parse the text into an array of fragments using the text formatter.
      def parse_text string, options = {}
        return [] if string.nil?

        options = options.dup
        if (format_option = options.delete :inline_format)
          format_option = [] unless ::Array === format_option
          fragments = text_formatter.format string, *format_option
        else
          fragments = [text: string]
        end

        if (color = options.delete :color)
          fragments.map do |fragment|
            fragment[:color] ? fragment : fragment.merge(color: color)
          end
        else
          fragments
        end
      end

      # NOTE: override built-in fill_formatted_text_box to insert leading before second line when :first_line is true
      def fill_formatted_text_box text, opts
        merge_text_box_positioning_options opts
        box = ::Prawn::Text::Formatted::Box.new text, opts
        remaining_text = box.render
        @no_text_printed = box.nothing_printed?
        @all_text_printed = box.everything_printed?

        if ((defined? @final_gap) && @final_gap) || (opts[:first_line] && !(@no_text_printed || @all_text_printed))
          self.y -= box.height + box.line_gap + box.leading
        else
          self.y -= box.height
        end

        remaining_text
      end

      # NOTE: override built-in draw_indented_formatted_line to set first_line flag
      def draw_indented_formatted_line string, opts
        super string, (opts.merge first_line: true)
      end

      # Performs the same work as Prawn::Text.text except that the first_line_opts are applied to the first line of text
      # renderered. It's necessary to use low-level APIs in this method so we only style the first line and not the
      # remaining lines (which is the default behavior in Prawn).
      def text_with_formatted_first_line string, first_line_opts, opts
        color = opts.delete :color
        fragments = parse_text string, opts
        # NOTE: the low-level APIs we're using don't recognize the :styles option, so we must resolve
        if (styles = opts.delete :styles)
          opts[:style] = resolve_font_style styles
        end
        if (first_line_styles = first_line_opts.delete :styles)
          first_line_opts[:style] = resolve_font_style first_line_styles
        end
        first_line_color = (first_line_opts.delete :color) || color
        opts = opts.merge document: self
        # QUESTION: should we merge more carefully here? (hand-select keys?)
        first_line_opts = opts.merge(first_line_opts).merge single_line: true, first_line: true
        box = ::Prawn::Text::Formatted::Box.new fragments, first_line_opts
        # NOTE: get remaining_fragments before we add color to fragments on first line
        if (text_indent = opts.delete :indent_paragraphs)
          remaining_fragments = indent text_indent do
            box.render dry_run: true
          end
        else
          remaining_fragments = box.render dry_run: true
        end
        # NOTE: color must be applied per-fragment
        fragments.each {|fragment| fragment[:color] ||= first_line_color } if first_line_color
        if text_indent
          indent text_indent do
            fill_formatted_text_box fragments, first_line_opts
          end
        else
          fill_formatted_text_box fragments, first_line_opts
        end
        unless remaining_fragments.empty?
          # NOTE: color must be applied per-fragment
          remaining_fragments.each {|fragment| fragment[:color] ||= color } if color
          remaining_fragments = fill_formatted_text_box remaining_fragments, opts
          draw_remaining_formatted_text_on_new_pages remaining_fragments, opts
        end
      end

      # Apply the text transform to the specified text.
      #
      # Supported transform values are "uppercase", "lowercase", or "none" (passed
      # as either a String or a Symbol). When the uppercase transform is applied to
      # the text, it correctly uppercases visible text while leaving markup and
      # named character entities unchanged. The none transform returns the text
      # unmodified.
      #
      def transform_text text, transform
        case transform
        when :uppercase, 'uppercase'
          uppercase_pcdata text
        when :lowercase, 'lowercase'
          lowercase_pcdata text
        when :capitalize, 'capitalize'
          capitalize_words_pcdata text
        else
          text
        end
      end

      def hyphenate_text text, hyphenator
        hyphenate_words_pcdata text, hyphenator
      end

      # Cursor

      # Short-circuits the call to the built-in move_up operation
      # when n is 0.
      #
      def move_up n
        super unless n == 0
      end

      # Override built-in move_text_position method to prevent Prawn from advancing
      # to next page if image doesn't fit before rendering image.
      #--
      # NOTE: could use :at option when calling image/embed_image instead
      def move_text_position h; end

      # Short-circuits the call to the built-in move_down operation
      # when n is 0.
      #
      def move_down n
        super unless n == 0
      end

      # Bounds

      # Augments the built-in pad method by adding support for specifying padding on all four sizes.
      #
      # Padding may be specified as an array of four values, or as a single value.
      # The single value is used as the padding around all four sides of the box.
      #
      # If padding is nil, this method simply yields to the block and returns.
      #
      # Example:
      #
      #  pad_box 20 do
      #    text 'A paragraph inside a blox with even padding on all sides.'
      #  end
      #
      #  pad_box [10, 10, 10, 20] do
      #    text 'An indented paragraph inside a box with equal padding on all sides.'
      #  end
      #
      def pad_box padding
        if padding
          # TODO: implement shorthand combinations like in CSS
          p_top, p_right, p_bottom, p_left = ::Array === padding ? padding : (::Array.new 4, padding)
          begin
            # logic is intentionally inlined
            move_down p_top
            bounds.add_left_padding p_left
            bounds.add_right_padding p_right
            yield
            # NOTE: support negative bottom padding to shave bottom margin of last child
            # NOTE: this doesn't work well at a page boundary since not all of the bottom margin may have been applied
            if p_bottom < 0
              p_bottom < cursor - reference_bounds.top ? (move_cursor_to reference_bounds.top) : (move_down p_bottom)
            else
              p_bottom < cursor ? (move_down p_bottom) : reference_bounds.move_past_bottom
            end
          ensure
            bounds.subtract_left_padding p_left
            bounds.subtract_right_padding p_right
          end
        else
          yield
        end
      end

      def expand_indent_value value
        (::Array === value ? (value.slice 0, 2) : (::Array.new 2, value)).map(&:to_f)
      end

      def expand_padding_value shorthand
        unless (padding = (@side_area_shorthand_cache ||= {})[shorthand])
          if ::Array === shorthand
            case shorthand.size
            when 1
              padding = [shorthand[0], shorthand[0], shorthand[0], shorthand[0]]
            when 2
              padding = [shorthand[0], shorthand[1], shorthand[0], shorthand[1]]
            when 3
              padding = [shorthand[0], shorthand[1], shorthand[2], shorthand[1]]
            when 4
              padding = shorthand
            else
              padding = shorthand.slice 0, 4
            end
          else
            padding = ::Array.new 4, (shorthand || 0)
          end
          @side_area_shorthand_cache[shorthand] = padding
        end
        padding.dup
      end

      alias expand_margin_value expand_padding_value

      # Stretch the current bounds to the left and right edges of the current page
      # while yielding the specified block if the verdict argument is true.
      # Otherwise, simply yield the specified block.
      #
      def span_page_width_if verdict
        if verdict
          indent(-bounds_margin_left, -bounds_margin_right) do
            yield
          end
        else
          yield
        end
      end

      # A flowing version of the bounding_box. If the content runs to another page, the cursor starts
      # at the top of the page instead of the original cursor position. Similar to span, except
      # you can specify an absolute left position and pass additional options through to bounding_box.
      #
      def flow_bounding_box left = 0, opts = {}
        original_y = y
        # QUESTION: should preserving original_x be an option?
        original_x = bounds.absolute_left - margin_box.absolute_left
        canvas do
          bounding_box [margin_box.absolute_left + original_x + left, margin_box.absolute_top], opts do
            self.y = original_y
            yield
          end
        end
      end

      # Graphics

      # Fills the current bounding box with the specified fill color. Before
      # returning from this method, the original fill color on the document is
      # restored.
      def fill_bounds f_color = fill_color
        if f_color && f_color != 'transparent'
          prev_fill_color = fill_color
          fill_color f_color
          fill_rectangle bounds.top_left, bounds.width, bounds.height
          fill_color prev_fill_color
        end
      end

      # Fills the absolute bounding box with the specified fill color. Before
      # returning from this method, the original fill color on the document is
      # restored.
      def fill_absolute_bounds f_color = fill_color
        canvas { fill_bounds f_color }
      end

      # Fills the current bounds using the specified fill color and strokes the
      # bounds using the specified stroke color. Sets the line with if specified
      # in the options. Before returning from this method, the original fill
      # color, stroke color and line width on the document are restored.
      #
      def fill_and_stroke_bounds f_color = fill_color, s_color = stroke_color, options = {}
        no_fill = !f_color || f_color == 'transparent'
        if ::Array === (s_width = options[:line_width] || 0.5)
          s_width_max = s_width.max
          radius = 0
        else
          radius = options[:radius] || 0
        end
        no_stroke = !s_color || s_color == 'transparent' || (s_width_max || s_width) == 0
        return if no_fill && no_stroke
        save_graphics_state do
          # fill
          unless no_fill
            fill_color f_color
            fill_rounded_rectangle bounds.top_left, bounds.width, bounds.height, radius
          end

          next if no_stroke

          # stroke
          if s_width_max
            if (s_width_end = s_width[0] || 0) > 0
              stroke_horizontal_rule s_color, line_width: s_width_end, line_style: options[:line_style]
              stroke_horizontal_rule s_color, line_width: s_width_end, line_style: options[:line_style], at: bounds.height
            end
            if (s_width_side = s_width[1] || 0) > 0
              stroke_vertical_rule s_color, line_width: s_width_side, line_style: options[:line_style]
              stroke_vertical_rule s_color, line_width: s_width_side, line_style: options[:line_style], at: bounds.width
            end
          else
            stroke_color s_color
            case options[:line_style]
            when :dashed
              line_width s_width
              dash s_width * 4
            when :dotted
              line_width s_width
              dash s_width
            when :double
              single_line_width = s_width / 3.0
              line_width single_line_width
              inner_line_offset = single_line_width * 2
              inner_top_left = [bounds.left + inner_line_offset, bounds.top - inner_line_offset]
              stroke_rounded_rectangle bounds.top_left, bounds.width, bounds.height, radius
              stroke_rounded_rectangle inner_top_left, bounds.width - (inner_line_offset * 2), bounds.height - (inner_line_offset * 2), radius
              next
            else # :solid
              line_width s_width
            end
            stroke_rounded_rectangle bounds.top_left, bounds.width, bounds.height, radius
          end
        end
      end

      # Strokes a horizontal line using the current bounds. The width of the line
      # can be specified using the line_width option. The offset from the cursor
      # can be set using the at option.
      #
      def stroke_horizontal_rule rule_color = stroke_color, options = {}
        rule_y = cursor - (options[:at] || 0)
        rule_style = options[:line_style]
        rule_width = options[:line_width] || 0.5
        rule_x_start = bounds.left
        rule_x_end = bounds.right
        save_graphics_state do
          stroke_color rule_color
          case rule_style
          when :dashed
            line_width rule_width
            dash rule_width * 4
          when :dotted
            line_width rule_width
            dash rule_width
          when :double
            single_rule_width = rule_width / 3.0
            line_width single_rule_width
            stroke_horizontal_line rule_x_start, rule_x_end, at: (rule_y + single_rule_width)
            stroke_horizontal_line rule_x_start, rule_x_end, at: (rule_y - single_rule_width)
            next
          else # :solid
            line_width rule_width
          end
          stroke_horizontal_line rule_x_start, rule_x_end, at: rule_y
        end
      end

      # A compliment to the stroke_horizontal_rule method, strokes a
      # vertical line using the current bounds. The width of the line
      # can be specified using the line_width option. The horizontal (x)
      # position can be specified using the at option.
      #
      def stroke_vertical_rule rule_color = stroke_color, options = {}
        rule_x = options[:at] || 0
        rule_y_from = bounds.top
        rule_y_to = bounds.bottom
        rule_style = options[:line_style]
        rule_width = options[:line_width] || 0.5
        save_graphics_state do
          line_width rule_width
          stroke_color rule_color
          case rule_style
          when :dashed
            dash rule_width * 4
          when :dotted
            dash rule_width
          when :double
            stroke_vertical_line rule_y_from, rule_y_to, at: (rule_x - rule_width)
            rule_x += rule_width
          end if rule_style
          stroke_vertical_line rule_y_from, rule_y_to, at: rule_x
        end
      end

      # Pages

      # Deletes the current page and move the cursor
      # to the previous page.
      def delete_page
        pg = page_number
        pdf_store = state.store
        content_id = page.content.identifier
        # NOTE: cannot delete objects and IDs, otherwise references get corrupted; so just reset the value
        (pdf_store.instance_variable_get :@objects)[content_id] = ::PDF::Core::Reference.new content_id, {}
        pdf_store.pages.data[:Kids].pop
        pdf_store.pages.data[:Count] -= 1
        state.pages.pop
        if pg > 1
          go_to_page pg - 1
        else
          @page_number = 0
          state.page = nil
        end
      end

      # Import the specified page into the current document.
      #
      # By default, advance to the next page afterwards, creating it if necessary.
      # This behavior can be disabled by passing the option `advance: false`.
      # However, due to how page creation works in Prawn, understand that advancing
      # to the next page is necessary to prevent the size & layout of the imported
      # page from affecting a newly created page.
      def import_page file, opts = {}
        prev_page_layout = page.layout
        prev_page_size = page.size
        state.compress = false if state.compress # can't use compression if using template
        prev_text_rendering_mode = (defined? @text_rendering_mode) ? @text_rendering_mode : nil
        delete_page if opts[:replace]
        # NOTE: use functionality provided by prawn-templates
        start_new_page_discretely template: file, template_page: opts[:page]
        # prawn-templates sets text_rendering_mode to :unknown, which breaks running content; revert
        @text_rendering_mode = prev_text_rendering_mode
        if page.imported_page?
          yield if block_given?
          # NOTE: set page size & layout explicitly in case imported page differs
          # I'm not sure it's right to start a new page here, but unfortunately there's no other
          # way atm to prevent the size & layout of the imported page from affecting subsequent pages
          advance_page size: prev_page_size, layout: prev_page_layout if opts.fetch :advance, true
        elsif opts.fetch :advance, true
          delete_page
          # NOTE: see previous comment
          advance_page size: prev_page_size, layout: prev_page_layout
        else
          delete_page
        end
        nil
      end

      # Create a new page for the specified image.
      #
      # The image is positioned relative to the boundaries of the page.
      def image_page file, options = {}
        start_new_page_discretely
        ex = nil
        float do
          canvas do
            image file, ({ position: :center, vposition: :center }.merge options)
          rescue
            ex = $!
          end
        end
        raise ex if ex
        nil
      end

      # Perform an operation (such as creating a new page) without triggering the on_page_create callback
      #
      def perform_discretely
        if (saved_callback = state.on_page_create_callback)
          begin
            # equivalent to calling `on_page_create` with no arguments
            state.on_page_create_callback = nil
            yield
          ensure
            # equivalent to calling `on_page_create &saved_callback`
            state.on_page_create_callback = saved_callback
          end
        else
          yield
        end
      end

      # This method is a smarter version of start_new_page. It calls start_new_page
      # if the current page is the last page of the document. Otherwise, it simply
      # advances to the next existing page.
      def advance_page opts = {}
        last_page? ? (start_new_page opts) : (go_to_page page_number + 1)
      end

      # Start a new page without triggering the on_page_create callback
      #
      def start_new_page_discretely options = {}
        perform_discretely { start_new_page options }
      end

      # Grouping

      def get_scratch_document
        # marshal if not using transaction feature
        #Marshal.load Marshal.dump @prototype

        # use cached instance, tests show it's faster
        #@prototype ||= ::Prawn::Document.new
        @scratch ||= if defined? @prototype # rubocop:disable Naming/MemoizedInstanceVariableName
                       scratch = Marshal.load Marshal.dump @prototype
                       scratch.instance_variable_set :@prototype, @prototype
                       scratch.instance_variable_set :@tmp_files, @tmp_files
                       # TODO: set scratch number on scratch document
                       scratch
                     else
                       logger.warn 'no scratch prototype available; instantiating fresh scratch document'
                       ::Prawn::Document.new
                     end
      end

      def scratch?
        (@_label ||= (state.store.info.data[:Scratch] ? :scratch : :primary)) == :scratch
      rescue
        false # NOTE: this method may get called before the state is initialized
      end
      alias is_scratch? scratch?

      def dry_run &block
        scratch = get_scratch_document
        # QUESTION: should we use scratch.advance_page instead?
        scratch.start_new_page
        start_page_number = scratch.page_number
        start_y = scratch.y
        scratch_bounds = scratch.bounds
        original_x = scratch_bounds.absolute_left
        original_width = scratch_bounds.width
        scratch_bounds.instance_variable_set :@x, bounds.absolute_left
        scratch_bounds.instance_variable_set :@width, bounds.width
        prev_font_scale, scratch.font_scale = scratch.font_scale, font_scale
        scratch.font font_family, style: font_style, size: font_size do
          scratch.instance_exec(&block)
        end
        scratch.font_scale = prev_font_scale
        # NOTE: don't count excess if cursor exceeds writable area (due to padding)
        full_page_height = scratch.effective_page_height
        partial_page_height = [full_page_height, start_y - scratch.y].min
        scratch_bounds.instance_variable_set :@x, original_x
        scratch_bounds.instance_variable_set :@width, original_width
        whole_pages = scratch.page_number - start_page_number
        [(whole_pages * full_page_height + partial_page_height), whole_pages, partial_page_height]
      end

      # Attempt to keep the objects generated in the block on the same page
      #
      # TODO: short-circuit nested usage
      def keep_together &block
        available_space = cursor
        total_height, = dry_run(&block)
        # NOTE: technically, if we're at the page top, we don't even need to do the
        # dry run, except several uses of this method rely on the calculated height
        if total_height > available_space && !at_page_top? && total_height <= effective_page_height
          advance_page
          started_new_page = true
        else
          started_new_page = false
        end

        # HACK: yield doesn't work here on JRuby (at least not when called from AsciidoctorJ)
        #yield remainder, started_new_page
        instance_exec total_height, started_new_page, &block
      end

      # Attempt to keep the objects generated in the block on the same page
      # if the verdict parameter is true.
      #
      def keep_together_if verdict, &block
        verdict ? keep_together(&block) : yield
      end
    end
  end
end
