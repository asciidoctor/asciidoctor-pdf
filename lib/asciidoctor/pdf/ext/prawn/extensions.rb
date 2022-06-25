# frozen_string_literal: true

Prawn::Font::AFM.instance_variable_set :@hide_m17n_warning, true

require 'prawn/icon'

Prawn::Icon::Compatibility.prepend (::Module.new { def warning *_args; end })

module Asciidoctor
  module Prawn
    module Extensions
      include ::Asciidoctor::PDF::Measurements
      include ::Asciidoctor::PDF::Sanitizer
      include ::Asciidoctor::PDF::TextTransformer

      ColumnBox = ::Prawn::Document::ColumnBox

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

      Position = ::Struct.new :page, :column, :cursor

      Extent = ::Struct.new :current, :from, :to do
        def initialize current_page, current_column, current_cursor, from_page, from_column, from_cursor, to_page, to_cursor
          self.current = Position.new current_page, current_column, current_cursor
          self.from = Position.new from_page, from_column, from_cursor
          self.from = current if from == current
          self.to = Position.new to_page, nil, to_cursor
        end

        def each_page
          from.page.upto to.page do |pgnum|
            yield pgnum == from.page && from, pgnum == to.page && to, pgnum
          end
        end

        def single_page?
          from.page == to.page
        end

        def single_page_height
          single_page? ? from.cursor - to.cursor : nil
        end

        def page_range
          (from.page..to.page)
        end
      end

      ScratchExtent = ::Struct.new :from, :to do
        def initialize start_page, start_cursor, end_page, end_cursor
          self.from = Position.new start_page, 0, start_cursor
          self.to = Position.new end_page, 0, end_cursor
        end

        def position_onto pdf, keep_together = nil
          current_page = pdf.page_number
          current_column = ColumnBox === pdf.bounds ? (column_box = pdf.bounds).current_column : 0
          current_cursor = pdf.cursor
          if (advance_by = from.page - 1) > 0
            advance_by.times { pdf.advance_page }
          elsif keep_together && single_page? && !(try_to_fit_on_previous current_cursor)
            pdf.advance_page
          end
          from_page = pdf.page_number
          from_column = column_box&.current_column || 0
          to_page = from_page + (to.page - from.page)
          Extent.new current_page, current_column, current_cursor, from_page, from_column, from.cursor, to_page, to.cursor
        end

        def single_page?
          from.page == to.page
        end

        def single_page_height
          single_page? ? from.cursor - to.cursor : nil
        end

        def try_to_fit_on_previous reference_cursor
          if (height = from.cursor - to.cursor) <= reference_cursor
            from.cursor = reference_cursor
            to.cursor = reference_cursor - height
            true
          else
            false
          end
        end
      end

      NewPageRequiredError = ::Class.new ::StopIteration

      InhibitNewPageProc = proc do |pdf|
        pdf.delete_current_page
        raise NewPageRequiredError
      end

      DetectEmptyFirstPage = ::Module.new

      DetectEmptyFirstPageProc = proc do |delegate, pdf|
        if pdf.state.pages[pdf.page_number - 2].empty?
          pdf.delete_current_page
          raise NewPageRequiredError
        end
        delegate.call pdf if (pdf.state.on_page_create_callback = delegate)
      end

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
        @y == (ColumnBox === bounds ? bounds : @margin_box).absolute_top
      end

      # Prevents at_page_top? from returning true while yielding to the specified block.
      #
      def conceal_page_top
        old_top = (outer_bounds = ColumnBox === bounds ? bounds : @margin_box).absolute_top
        outer_bounds.instance_variable_set :@y, old_top + 0.0001
        yield
      ensure
        outer_bounds.instance_variable_set :@y, old_top
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

      # Gets the destination registered for the specified name. The return value
      # matches that which was passed to the add_dest method.
      #
      def get_dest name, node = dests.data
        node.children.each do |child|
          if ::PDF::Core::NameTree::Value === child
            return child.value.data if child.name == name
          elsif (found = get_dest name, child)
            return found
          end
        end
        nil
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

      # Override width of string to check for placeholder char, which uses character spacing to control width
      #
      def width_of_string string, options
        string == PlaceholderChar ? @character_spacing : super
      end

      def icon_font_data family
        ::Prawn::Icon::FontData.load self, family
      end

      def resolve_legacy_icon_name name
        ::Prawn::Icon::Compatibility::SHIMS[%(fa-#{name})]
      end

      def calc_line_metrics line_height, font = self.font, font_size = self.font_size
        line_height_length = line_height * font_size
        leading = line_height_length - font_size
        half_leading = leading / 2
        padding_top = half_leading + font.line_gap
        padding_bottom = half_leading
        LineMetrics.new line_height_length, leading, padding_top, padding_bottom, false
      end

      # Parse the text into an array of fragments using the text formatter.
      def parse_text string, options = {}
        return [] if string.nil?

        if (format_option = options[:inline_format])
          format_option = [] unless ::Array === format_option
          text_formatter.format string, *format_option
        else
          [text: string]
        end
      end

      # NOTE: override built-in fill_formatted_text_box to insert leading before second line when :first_line is true
      def fill_formatted_text_box text, options
        if (initial_gap = options[:initial_gap]) && !text.empty? && text[0][:from_page] != page_number
          self.y -= initial_gap
        end
        merge_text_box_positioning_options options
        box = ::Prawn::Text::Formatted::Box.new text, options
        remaining_fragments = box.render
        @no_text_printed = box.nothing_printed?
        @all_text_printed = box.everything_printed?
        unless remaining_fragments.empty? || (remaining_fragments[0][:from_page] ||= page_number) == page_number
          log :error, %(cannot fit formatted text on page: #{remaining_fragments.map {|it| it[:image_path] || it[:text] }.join})
          page.tare_content_stream
          remaining_fragments = {}
        end

        if @final_gap || (options[:first_line] && !(@no_text_printed || @all_text_printed))
          self.y -= box.height + box.line_gap + box.leading
        else
          self.y -= box.height
        end

        remaining_fragments
      end

      # NOTE: override built-in draw_indented_formatted_line to set first_line flag
      def draw_indented_formatted_line string, options
        super string, (options.merge first_line: true)
      end

      # Performs the same work as Prawn::Text.text except that the first_line_options are applied to the first line of text
      # renderered. It's necessary to use low-level APIs in this method so we only style the first line and not the
      # remaining lines (which is the default behavior in Prawn).
      def text_with_formatted_first_line string, first_line_options, options
        if (first_line_font_color = first_line_options.delete :color)
          remaining_lines_font_color, options[:color] = options[:color], first_line_font_color
        end
        fragments = parse_text string, options
        # NOTE: the low-level APIs we're using don't recognize the :styles option, so we must resolve
        # NOTE: disabled until we have a need for it; currently handled in convert_abstract
        #if (styles = options.delete :styles)
        #  options[:style] = resolve_font_style styles
        #end
        if (first_line_styles = first_line_options.delete :styles)
          first_line_options[:style] = resolve_font_style first_line_styles
        end
        first_line_text_transform = first_line_options.delete :text_transform
        options = options.merge document: self
        @final_gap = final_gap = options.delete :final_gap
        text_indent = options.delete :indent_paragraphs
        # QUESTION: should we merge more carefully here? (hand-select keys?)
        first_line_options = (options.merge first_line_options).merge single_line: true, first_line: true
        box = ::Prawn::Text::Formatted::Box.new fragments, first_line_options
        if text_indent
          remaining_fragments = indent(text_indent) { box.render dry_run: true }
        else
          remaining_fragments = box.render dry_run: true
        end
        if remaining_fragments.empty?
          remaining_fragments = nil
        elsif (remaining_fragments[0][:from_page] ||= page_number) != page_number
          log :error, %(cannot fit formatted text on page: #{remaining_fragments.map {|it| it[:image_path] || it[:text] }.join})
          page.tare_content_stream
          remaining_fragments = nil
        end
        if first_line_text_transform
          # NOTE: applying text transform here could alter the wrapping, so isolate first line and shrink it to fit
          first_line_text = (box.instance_variable_get :@printed_lines)[0]
          unless first_line_text == fragments[0][:text]
            original_fragments, fragments = fragments, []
            original_fragments.reduce '' do |traced, fragment|
              fragments << fragment
              # NOTE: we could just do a length comparison here
              if (traced += fragment[:text]).start_with? first_line_text
                fragment[:text] = fragment[:text][0...-(traced.length - first_line_text.length)]
                break
              end
              traced
            end
          end
          fragments.each {|fragment| fragment[:text] = transform_text fragment[:text], first_line_text_transform }
          first_line_options[:overflow] = :shrink_to_fit
          @final_gap = first_line_options[:force_justify] = true if remaining_fragments
        end
        if text_indent
          indent(text_indent) { fill_formatted_text_box fragments, first_line_options }
        else
          fill_formatted_text_box fragments, first_line_options
        end
        if remaining_fragments
          options[:color] = remaining_lines_font_color if first_line_font_color
          @final_gap = final_gap if first_line_text_transform
          remaining_fragments = fill_formatted_text_box remaining_fragments, options
          draw_remaining_formatted_text_on_new_pages remaining_fragments, options
        end
      end

      def hyphenate_text text, hyphenator
        hyphenate_words_pcdata text, hyphenator
      end

      # Cursor

      # Override the built-in float method to add support for restoring the current column of a ColumnBox
      #
      def float
        original_page_number = page_number
        original_y = y
        original_column = bounds.current_column if ColumnBox === bounds
        yield
        go_to_page original_page_number unless page_number == original_page_number
        self.y = original_y
        bounds.current_column = original_column if original_column
      end

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
      #    text 'A paragraph inside a blox with even padding from all edges.'
      #  end
      #
      #  pad_box [10, 5] do
      #    text 'A paragraph inside a box with different padding from ends and sides.'
      #  end
      #
      #  pad_box [5, 10, 15, 20] do
      #    text 'A paragraph inside a box with different padding from each edge.'
      #  end
      #
      def pad_box padding, node = nil
        if padding
          p_top, p_right, p_bottom, p_left = expand_padding_value padding
          # logic is intentionally inlined
          begin
            if node && ((last_block = node).content_model != :compound || (last_block = node.last_child)&.context == :paragraph)
              @bottom_gutters << { last_block => p_bottom }
            else
              @bottom_gutters << {}
            end
            move_down p_top
            bounds.add_left_padding p_left
            bounds.add_right_padding p_right
            yield
          ensure
            cursor > p_bottom ? (move_down p_bottom) : bounds.move_past_bottom unless at_page_top?
            @bottom_gutters.pop
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
        (@edge_shorthand_cache ||= ::Hash.new do |store, key|
          if ::Array === key
            case key.size
            when 1
              value = [(value0 = key[0] || 0), value0, value0, value0]
            when 2
              value = [(value0 = key[0] || 0), (value1 = key[1] || 0), value0, value1]
            when 3
              value = [key[0] || 0, (value1 = key[1] || 0), key[2] || 0, value1]
            when 4
              value = key.map {|it| it || 0 }
            else
              value = (key.slice 0, 4).map {|it| it || 0 }
            end
          else
            value = [(value0 = key || 0), value0, value0, value0]
          end
          store[key] = value
        end)[shorthand]
      end

      alias expand_margin_value expand_padding_value

      def expand_grid_values shorthand, default = nil
        if ::Array === shorthand
          case shorthand.size
          when 1
            [(value0 = shorthand[0] || default), value0]
          when 2
            shorthand.map {|it| it || default }
          when 4
            if Asciidoctor::PDF::ThemeLoader::CMYKColorValue === shorthand
              [shorthand, shorthand]
            else
              (shorthand.slice 0, 2).map {|it| it || default }
            end
          else
            (shorthand.slice 0, 2).map {|it| it || default }
          end
        else
          [(value0 = shorthand || default), value0]
        end
      end

      def expand_rect_values shorthand, default = nil
        if ::Array === shorthand
          case shorthand.size
          when 1
            [(value0 = shorthand[0] || default), value0, value0, value0]
          when 2
            [(value0 = shorthand[0] || default), (value1 = shorthand[1] || default), value0, value1]
          when 3
            [shorthand[0] || default, (value1 = shorthand[1] || default), shorthand[2] || default, value1]
          when 4
            if Asciidoctor::PDF::ThemeLoader::CMYKColorValue === shorthand
              [shorthand, shorthand, shorthand, shorthand]
            else
              shorthand.map {|it| it || default }
            end
          else
            (shorthand.slice 0, 4).map {|it| it || default }
          end
        else
          [(value0 = shorthand || default), value0, value0, value0]
        end
      end

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

      # Wraps the column_box method and automatically sets the height unless the :height option is specified.
      def column_box point, options, &block
        options[:height] = cursor unless options.key? :height
        super
      end

      # A flowing version of bounding_box. If the content runs to another page, the cursor starts at
      # the top of the page instead of from the original cursor position. Similar to span, except
      # the :position option is limited to a numeric value and additional options are passed through
      # to bounding_box.
      #
      def flow_bounding_box options = {}
        original_y, original_x = y, bounds.absolute_left
        canvas do
          bounding_box [original_x + (options.delete :position).to_f, @margin_box.absolute_top], options do
            self.y = original_y
            yield
          end
        end
      end

      # Graphics

      # Fills the current bounding box with the specified fill color. Before
      # returning from this method, the original fill color on the document is
      # restored.
      def fill_bounds f_color
        prev_fill_color = fill_color
        fill_color f_color
        fill_rectangle bounds.top_left, bounds.width, bounds.height
        fill_color prev_fill_color
      end

      # Fills the absolute bounding box with the specified fill color. Before
      # returning from this method, the original fill color on the document is
      # restored.
      def fill_absolute_bounds f_color
        canvas { fill_bounds f_color }
      end

      # Fills the current bounds using the specified fill color and strokes the
      # bounds using the specified stroke color. Sets the line with if specified
      # in the options. Before returning from this method, the original fill
      # color, stroke color and line width on the document are restored.
      #
      def fill_and_stroke_bounds f_color = fill_color, s_color = stroke_color, options = {}
        no_fill = !f_color || f_color == 'transparent'
        if ::Array === (s_width = options[:line_width] || 0)
          s_width = [s_width[0], s_width[1], s_width[0], s_width[1]] if s_width.size == 2
          s_width_max = (s_width = s_width.map {|it| it || 0 }).max
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
            s_width_top, s_width_right, s_width_bottom, s_width_left = s_width
            projection_top, projection_right, projection_bottom, projection_left = s_width.map {|it| it * 0.5 }
            if s_width_top > 0
              stroke_horizontal_rule s_color, line_width: s_width_top, line_style: options[:line_style], left_projection: projection_left, right_projection: projection_right
            end
            if s_width_right > 0
              stroke_vertical_rule s_color, line_width: s_width_right, line_style: options[:line_style], at: bounds.width, top_projection: projection_top, bottom_projection: projection_bottom
            end
            if s_width_bottom > 0
              stroke_horizontal_rule s_color, line_width: s_width_bottom, line_style: options[:line_style], at: bounds.height, left_projection: projection_left, right_projection: projection_right
            end
            if s_width_left > 0
              stroke_vertical_rule s_color, line_width: s_width_left, line_style: options[:line_style], top_projection: projection_top, bottom_projection: projection_bottom
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
        rule_x_start = bounds.left - (options[:left_projection] || 0)
        rule_x_end = bounds.right - (options[:right_projection] || 0)
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
        rule_y_from = bounds.top + (options[:top_projection] || 0)
        rule_y_to = bounds.bottom - (options[:bottom_projection] || 0)
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
      def delete_current_page
        pg = page_number
        pdf_store = state.store
        content_id = page.content.identifier
        page_ref = page.dictionary
        (prune_dests = proc do |node|
          node.children.delete_if {|it| ::PDF::Core::NameTree::Node === it ? prune_dests[it] : it.value.data[0] == page_ref }
          false
        end)[dests.data]
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
      def import_page file, options = {}
        prev_page_layout = page.layout
        prev_page_size = page.size
        prev_page_margin = page_margin
        prev_bounds = bounds
        state.compress = false if state.compress # can't use compression if using template
        prev_text_rendering_mode = (defined? @text_rendering_mode) ? @text_rendering_mode : nil
        delete_current_page if options[:replace]
        # NOTE: use functionality provided by prawn-templates
        start_new_page_discretely template: file, template_page: options[:page]
        # prawn-templates sets text_rendering_mode to :unknown, which breaks running content; revert
        @text_rendering_mode = prev_text_rendering_mode
        if page.imported_page?
          yield if block_given?
          # NOTE: set page size & layout explicitly in case imported page differs
          # I'm not sure it's right to start a new page here, but unfortunately there's no other
          # way atm to prevent the size & layout of the imported page from affecting subsequent pages
          if options.fetch :advance, true
            advance_page layout: prev_page_layout, margin: prev_page_margin, size: prev_page_size
            (@bounding_box = prev_bounds).reset_top if ColumnBox === prev_bounds
          end
        elsif options.fetch :advance_if_missing, true
          delete_current_page
          # NOTE: see previous comment
          advance_page layout: prev_page_layout, margin: prev_page_margin, size: prev_page_size
          @y = (@bounding_box = prev_bounds).reset_top if ColumnBox === prev_bounds
        else
          delete_current_page
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
        state.on_page_create_callback = nil if (saved_callback = state.on_page_create_callback) != InhibitNewPageProc
        yield
      ensure
        state.on_page_create_callback = saved_callback
      end

      # This method is a smarter version of start_new_page. It only calls start_new_page options are
      # specified and the current page is the last page in the document. Otherwise, it advances the
      # cursor to the next page (or column) using Bounds#move_past_bottom.
      def advance_page options = {}
        options.empty? || !last_page? ? bounds.move_past_bottom : (start_new_page options)
      end

      # Start a new page without triggering the on_page_create callback
      #
      def start_new_page_discretely options = {}
        perform_discretely { start_new_page options }
      end

      # Scratch

      def allocate_scratch_prototype
        @scratch_prototype = create_scratch_prototype { ::Marshal.load ::Marshal.dump self }
      end

      def scratch
        @scratch ||= ((Marshal.load Marshal.dump @scratch_prototype).send :init_scratch, self)
      end

      def scratch?
        @label == :scratch
      end

      def with_dry_run &block
        yield dry_run(&block).position_onto self, cursor
      end

      # Yields to the specified block multiple times, first to determine where to render the content
      # so it fits properly, then once more, this time providing access to the content's extent, to
      # ink the content in the primary document.
      #
      # This method yields to the specified block in a scratch document by calling dry_run to
      # determine where the content should start in the primary document. In the process, it also
      # computes the extent of the content. It then returns to the primary document and yields to
      # the block again, this time passing in the extent of the content. The extent can be used to
      # draw a border and/or background under the content before inking it.
      #
      # This method is intended to enclose the conversion of a single content block, such as a
      # sidebar or example block. The arrange logic attempts to keep unbreakable content on the same
      # page, keeps the top caption pinned to the top of the content, computes the extent of the
      # content for the purpose of drawing a border and/or background underneath it, and ensures
      # that the extent does not begin near the bottom of a page if the first line of content
      # doesn't fit. If unbreakable content does not fit on a single page, the content is treated as
      # breakable.
      #
      # The block passed to this method should use advance_page to move to the next page rather than
      # start_new_page. Using start_new_page can mangle the calculation of content block's extent.
      #
      def arrange_block node, &block
        keep_together = (node.option? 'unbreakable') && !at_page_top?
        doc = node.document
        block_for_scratch = proc do
          push_scratch doc
          instance_exec(&block)
        ensure
          pop_scratch doc
        end
        extent = dry_run keep_together: keep_together, onto: [self, keep_together], &block_for_scratch
        scratch? ? block_for_scratch.call : (yield extent)
      end

      # This method installs an on_page_create_callback that stops processing if the first page is
      # exceeded while yielding to the specified block. If the content fits on a single page, the
      # processing is not stopped. The purpose of this method is to determine if the content fits on
      # a single page.
      #
      # Returns a Boolean indicating whether the content fits on a single page.
      def perform_on_single_page
        saved_callback, state.on_page_create_callback = state.on_page_create_callback, InhibitNewPageProc
        yield
        false
      rescue NewPageRequiredError
        true
      ensure
        state.on_page_create_callback = saved_callback
      end

      # This method installs an on_page_create_callback that stops processing if a new page is
      # created without writing content to the first page while yielding to the specified block. If
      # any content is written to the first page, processing is not stopped. The purpose of this
      # method is to check whether any content fits on the remaining space on the current page.
      #
      # Returns a Boolean indicating whether any content is written on the first page.
      def stop_if_first_page_empty
        delegate = state.on_page_create_callback
        state.on_page_create_callback = DetectEmptyFirstPageProc.curry[delegate].extend DetectEmptyFirstPage
        yield
        false
      rescue NewPageRequiredError
        true
      ensure
        state.on_page_create_callback = delegate
      end

      # This method delegates to the provided block, then tares (i.e., resets) the content stream of
      # the initial page.
      #
      # The purpose of this method is to ink content while making it appear as though the page is
      # empty. This technique allows the caller to detect whether any subsequent content was written
      # to the page following the content inked by the block. It's often used to keep the title of a
      # content block with the block's first child.
      #
      # NOTE: this method should only used inside dry_run since that's when DetectEmptyFirstPage is active
      def tare_first_page_content_stream
        return yield unless DetectEmptyFirstPage === (delegate = state.on_page_create_callback)
        on_page_create_called = nil
        state.on_page_create_callback = proc do |pdf|
          on_page_create_called = true
          pdf.state.pages[pdf.page_number - 2].tare_content_stream
          delegate.call pdf
        end
        begin
          yield
        ensure
          page.tare_content_stream unless on_page_create_called
          state.on_page_create_callback = delegate
        end
      end

      # Yields to the specified block within the context of a scratch document up to three times to
      # acertain the extent of the content block.
      #
      # The purpose of this method is two-fold. First, it works out the position where the rendered
      # content should start in the calling document. Then, it precomputes the extent of the content
      # starting from that position.
      #
      # This method returns the content's extent (the range from the start page and cursor to the
      # end page and cursor) as a ScratchExtent object or, if the onto keyword parameter is
      # specified, an Extent object. A ScratchExtent always starts the page range at 1. When the
      # ScratchExtent is positioned onto the primary document using ScratchExtent#position_onto,
      # that's when the cursor may be advanced to the next page.
      #
      # This method performs all work in a scratch document (or documents). It begins by starting a
      # new page in the scratch document, first creating the scratch document if necessary. It then
      # applies all the settings from the main document to the scratch document that impact
      # rendering. This includes the bounds, the cursor position, and the font settings. This method
      # assumes that the content area remains constant when content flows from one page to the next.
      #
      # From this point, the number of attempts the method makes is determined by the value of the
      # keep_together keyword parameter. If the value is true (or the parent document is inhibiting
      # page creation), it starts from the top of the page, yields to the block, and tries to fit
      # the content on the current page. If the content fits, it computes and returns the
      # ScratchExtent (or Extent). If the content does not fit, it first checks if this scenario
      # should stop the operation. If the parent document is inhibiting page creation, it bubbles
      # the error. If the single_page keyword argument is :enforce, it raises a CannotFit error. If
      # the single_page keyword argument is true, it returns a ScratchExtent (or Extent) that
      # represents a full page. If none of those conditions are met, it restarts with the
      # keep_together parameter unset.
      #
      # If the keep_together parameter is not true, the method tries to render the content in the
      # scratch document from the location of the cursor in the main document. If the cursor is at
      # the top of the page, no special conditions are applied (this is the last attempt). The
      # content is rendered and the extent is computed based on where the content ended up (minus a
      # trailing empty page). If the cursor is not at the top of the page, the method renders the
      # content while listening for a page creation event before any content is written. If a new
      # page is created, and no content is written on the first page, the method restarts with the
      # cursor at the top of the page.
      #
      # Note that if the block has content that itself requires a dry run, that nested dry run will
      # be performed in a separate scratch document.
      #
      # options - A Hash of options that configure the dry run computation:
      #           :keep_together - A Boolean indicating whether an attempt should be made to keep
      #           the content on the same page (optional, default: false).
      #           :single_page - A Boolean indicating whether the operation should stop if the
      #           content exceeds the height of a single page.
      #           :onto - The document onto which to position the scratch extent. If this option is
      #           set, the method returns an Extent instance (optional, default: false)
      #           :pages_advanced - The number of pages the content has been advanced during this
      #           operation (internal only) (optional, default: 0)
      #
      # Returns an Extent or ScratchExtent object that describes the bounds of the content block.
      def dry_run keep_together: nil, pages_advanced: 0, single_page: nil, onto: nil, &block
        (scratch_pdf = scratch).start_new_page layout: page.layout
        saved_bounds = scratch_pdf.bounds
        scratch_pdf.bounds = bounds.dup.tap do |bounds_copy|
          bounds_copy.instance_variable_set :@document, scratch_pdf
          bounds_copy.instance_variable_set :@parent, saved_bounds
          bounds_copy.single_file if ColumnBox === bounds_copy
        end
        scratch_pdf.move_cursor_to cursor unless (scratch_start_at_top = keep_together || pages_advanced > 0 || at_page_top?)
        scratch_start_cursor = scratch_pdf.cursor
        scratch_start_page = scratch_pdf.page_number
        inhibit_new_page = state.on_page_create_callback == InhibitNewPageProc
        restart = nil
        scratch_pdf.font font_family, size: font_size, style: font_style do
          prev_font_scale, scratch_pdf.font_scale = scratch_pdf.font_scale, font_scale
          if keep_together || inhibit_new_page
            if (restart = scratch_pdf.perform_on_single_page { scratch_pdf.instance_exec(&block) })
              # NOTE: propogate NewPageRequiredError from nested block, which is rendered in separate scratch document
              raise NewPageRequiredError if inhibit_new_page
              if single_page
                raise ::Prawn::Errors::CannotFit if single_page == :enforce
                # single_page and onto are mutually exclusive
                return ScratchExtent.new scratch_start_page, scratch_start_cursor, scratch_start_page, 0
              end
            end
          elsif scratch_start_at_top
            scratch_pdf.instance_exec(&block)
          elsif (restart = scratch_pdf.stop_if_first_page_empty { scratch_pdf.instance_exec(&block) })
            pages_advanced += 1
          end
        ensure
          scratch_pdf.font_scale = prev_font_scale
        end
        return dry_run pages_advanced: pages_advanced, onto: onto, &block if restart
        scratch_end_page = scratch_pdf.page_number - scratch_start_page + (scratch_start_page = 1)
        if pages_advanced > 0
          scratch_start_page += pages_advanced
          scratch_end_page += pages_advanced
        end
        scratch_end_cursor = scratch_pdf.cursor
        # NOTE: drop trailing blank page and move cursor to end of previous page
        if scratch_end_page > scratch_start_page && scratch_pdf.at_page_top?
          scratch_end_page -= 1
          scratch_end_cursor = 0
        end
        extent = ScratchExtent.new scratch_start_page, scratch_start_cursor, scratch_end_page, scratch_end_cursor
        onto ? extent.position_onto(*onto) : extent
      ensure
        scratch_pdf.bounds = saved_bounds
      end
    end
  end
end
