# frozen_string_literal: true

require_relative 'formatted_string'
require_relative 'formatted_text'
require_relative 'index_catalog'
require_relative 'optimizer'
require_relative 'pdfmark'
require_relative 'roman_numeral'
require_relative 'section_info_by_page'

module Asciidoctor
  module PDF
    class Converter < ::Prawn::Document
      include ::Asciidoctor::Converter
      include ::Asciidoctor::Logging
      include ::Asciidoctor::Writer
      include ::Asciidoctor::Prawn::Extensions

      register_for 'pdf'

      attr_reader :allow_uri_read

      attr_reader :cache_uri

      attr_reader :jail_dir

      attr_accessor :font_color

      attr_accessor :font_scale

      attr_reader :index

      attr_reader :theme

      attr_reader :text_decoration_width

      # NOTE: require_library doesn't support require_relative and we don't modify the load path for this gem
      CodeRayRequirePath = ::File.join __dir__, 'ext/prawn/coderay_encoder'
      RougeRequirePath = ::File.join __dir__, 'ext/rouge'
      PygmentsRequirePath = ::File.join __dir__, 'ext/pygments'

      AdmonitionIcons = {
        caution: { name: 'fas-fire', stroke_color: 'BF3400' },
        important: { name: 'fas-exclamation-circle', stroke_color: 'BF0000' },
        note: { name: 'fas-info-circle', stroke_color: '19407C' },
        tip: { name: 'far-lightbulb', stroke_color: '111111' },
        warning: { name: 'fas-exclamation-triangle', stroke_color: 'BF6900' },
      }.transform_values {|val| val.merge size: 36 }
      TextAlignmentNames = { 'justify' => true, 'left' => true, 'center' => true, 'right' => true }
      IndentableTextAlignments = { justify: true, left: true }
      TextAlignmentRoles = { 'text-justify' => true, 'text-left' => true, 'text-center' => true, 'text-right' => true }
      TextDecorationStyleTable = { 'underline' => :underline, 'line-through' => :strikethrough }
      FontKerningTable = { 'normal' => true, 'none' => false }
      BlockFloatNames = %w(left right)
      BlockAlignmentNames = %w(left center right)
      (AlignmentTable = { '<' => :left, '=' => :center, '>' => :right }).default = :left
      ColumnPositions = [:left, :center, :right]
      PageLayouts = [:portrait, :landscape]
      (PageModes = {
        'fullscreen' => [:FullScreen, :UseOutlines],
        'fullscreen none' => [:FullScreen, :UseNone],
        'fullscreen outline' => [:FullScreen, :UseOutlines],
        'fullscreen thumbs' => [:FullScreen, :UseThumbs],
        'none' => :UseNone,
        'outline' => :UseOutlines,
        'thumbs' => :UseThumbs,
      }).default = :UseOutlines
      PageSides = [:recto, :verso]
      (PDFVersions = { '1.3' => 1.3, '1.4' => 1.4, '1.5' => 1.5, '1.6' => 1.6, '1.7' => 1.7 }).default = 1.4
      AuthorAttributeNames = { name: 'author', initials: 'authorinitials', firstname: 'firstname', middlename: 'middlename', lastname: 'lastname', email: 'email' }
      LF = ?\n
      DoubleLF = LF * 2
      TAB = ?\t
      InnerIndent = LF + ' '
      # a no-break space is used to replace a leading space to prevent Prawn from trimming indentation
      # a leading zero-width space can't be used as it gets dropped when calculating the line width
      GuardedIndent = ?\u00a0
      GuardedInnerIndent = LF + GuardedIndent
      TabRx = /\t/
      TabIndentRx = /^\t+/
      NoBreakSpace = ?\u00a0
      ZeroWidthSpace = ?\u200b
      DummyText = ?\u0000
      DigitsRx = /^\d+$/
      DotLeaderTextDefault = '. '
      EmDash = ?\u2014
      RightPointer = ?\u25ba
      LowercaseGreekA = ?\u03b1
      Bullets = {
        disc: ?\u2022,
        circle: ?\u25e6,
        square: ?\u25aa,
        none: '',
      }
      # NOTE: default theme font uses ballot boxes from FontAwesome
      BallotBox = {
        checked: ?\u2611,
        unchecked: ?\u2610,
      }
      ConumSets = {
        'circled' => (?\u2460..?\u2473).to_a,
        'filled' => (?\u2776..?\u277f).to_a + (?\u24eb..?\u24f4).to_a,
      }
      TypographicQuotes = %w(&#8220; &#8221; &#8216; &#8217;)
      InlineFormatSniffRx = /[<&]/
      SimpleAttributeRefRx = /(?<!\\)\{\w+(?:-\w+)*\}/
      MeasurementRxt = '\\d+(?:\\.\\d+)?(?:in|cm|mm|p[txc])?'
      MeasurementPartsRx = /^(\d+(?:\.\d+)?)(in|mm|cm|p[txc])?$/
      PageSizeRx = /^(?:\[(#{MeasurementRxt}), ?(#{MeasurementRxt})\]|(#{MeasurementRxt})(?: x |x)(#{MeasurementRxt})|\S+)$/
      CalloutExtractRx = %r((?:(?://|#|--|;;) ?)?(\\)?<!?(|--)(\d+|\.)\2> ?(?=(?:\\?<!?\2(?:\d+|\.)\2> ?)*$))
      CalloutConflictRx = /([<>&])(; *<!?(|--)(?:\d+|\.)\3>)/
      ImageAttributeValueRx = /\Aimage:{1,2}(.*?)\[(.*?)\]\Z/
      StopPunctRx = /[.!?;:]$/
      UriBreakCharsRx = %r((?:/|\?|&amp;|#)(?!$))
      UriBreakCharRepl = %(\\&#{ZeroWidthSpace})
      UriSchemeBoundaryRx = %r((?<=://))
      UrlSniffRx = %r(^\p{Alpha}[\p{Alnum}+.-]*://)
      LineScanRx = /\n|.+/
      BlankLineRx = /\n{2,}/
      CjkLineBreakRx = /(?=[\u3000\u30a0-\u30ff\u3040-\u309f\p{Han}\uff00-\uffef])/
      WhitespaceChars = ' ' + TAB + LF
      ValueSeparatorRx = /;|,/
      HexColorRx = /^#[a-fA-F0-9]{6}$/
      VimeoThumbnailRx = %r(<thumbnail_url>(.*?)</thumbnail_url>)
      DropAnchorRx = %r(<(?:a\b[^>]*|/a)>)
      SourceHighlighters = %w(coderay pygments rouge).to_set
      ViewportWidth = ::Module.new
      ImageWidth = ::Module.new
      (TitleStyles = {
        'toc' => [:numbered_title],
        'basic' => [:title],
      }).default = [:numbered_title, formal: true]

      def initialize backend, opts
        super
        basebackend 'html'
        filetype 'pdf'
        htmlsyntax 'html'
        outfilesuffix '.pdf'
        @label = :primary
        @tmp_files = {}
        @initial_instance_variables = [:@initial_instance_variables] + instance_variables
        if (doc = opts[:document])
          # NOTE: enabling data-uri forces Asciidoctor Diagram to produce absolute image paths
          doc.attributes['data-uri'] = (doc.instance_variable_get :@attribute_overrides)['data-uri'] = ''
          # NOTE: pre-initialize some instance variables for resolving inline images before conversion starts
          @allow_uri_read = doc.attr? 'allow-uri-read'
          @cache_uri = doc.attr? 'cache-uri'
          @jail_dir = doc.safe < ::Asciidoctor::SafeMode::SAFE ? nil : doc.base_dir
        end
      end

      def convert node, name = nil, _opts = {}
        method_name = %(convert_#{name ||= node.node_name})
        if respond_to? method_name
          result = send method_name, node
        else
          # TODO: delegate to convert_method_missing
          log :warn, %(missing convert handler for #{name} node in #{@backend} backend)
        end
        # NOTE: inline node handlers generate HTML-like strings; all other handlers write directly to the PDF object
        node.inline? ? result : self
      end

      def convert_document doc
        init_pdf doc
        marked_page_number = page_number
        # NOTE: a new page will already be started (page_number = 2) if the front cover image is a PDF
        ink_cover_page doc, :front
        has_front_cover = page_number > marked_page_number
        doctype = doc.doctype
        if (has_title_page = (title_as_page = doctype == 'book' || (doc.attr? 'title-page')) && (start_title_page doc))
          # NOTE: the base font must be set before any content is written to the main or scratch document
          font @theme.base_font_family, size: @root_font_size, style: @theme.base_font_style
          if perform_on_single_page { ink_title_page doc }
            log :warn, 'the title page contents has been truncated to prevent it from overrunning the bounds of a single page'
          end
          start_new_page
        else
          @page_margin[:cover] = @page_margin[page.layout][:recto] if @media == 'prepress' && page_number == 0
          start_new_page unless page&.empty? # rubocop:disable Lint/SafeNavigationWithEmpty
          # NOTE: the base font must be set before any content is written to the main or scratch document
          # this method is called inside ink_title_page if the title page is active
          font @theme.base_font_family, size: @root_font_size, style: @theme.base_font_style
        end

        unless title_as_page
          body_start_page_number = page_number
          theme_font :heading, level: 1 do
            ink_general_heading doc, doc.doctitle, align: (@theme.heading_h1_text_align&.to_sym || :center), level: 1, role: :doctitle
          end if doc.header? && !doc.notitle
        end

        num_front_matter_pages = toc_page_nums = toc_num_levels = nil

        indent_section do
          toc_num_levels = (doc.attr 'toclevels', 2).to_i
          if (toc_at_top = (doc.attr? 'toc') && !((toc_placement = doc.attr 'toc-placement') == 'macro' || toc_placement == 'preamble') && !(get_entries_for_toc doc).empty?)
            start_new_page if @ppbook && verso_page?
            add_dest_for_block doc, id: 'toc', y: (at_page_top? ? page_height : nil)
            @toc_extent = allocate_toc doc, toc_num_levels, cursor, (title_as_page && theme.toc_break_after != 'auto')
          else
            @toc_extent = nil
          end

          if @ppbook && verso_page? && !(((next_block = doc.first_child)&.context == :preamble ? next_block.first_child : next_block)&.option? 'nonfacing')
            min_start_at = 0
            start_new_page
          else
            min_start_at = 1
          end

          if title_as_page
            zero_page_offset = has_front_cover ? 1 : 0
            first_page_offset = has_title_page ? zero_page_offset.next : zero_page_offset
            body_offset = (body_start_page_number = page_number) - 1
            if ::Integer === (running_content_start_at = @theme.running_content_start_at)
              running_content_body_offset = body_offset + [running_content_start_at.pred, min_start_at.pred].max
              running_content_start_at = 'body'
            else
              running_content_body_offset = body_offset
              case running_content_start_at
              when 'title'
                running_content_start_at = 'toc' unless has_title_page
              when 'toc'
                uses_start_at_toc = true
                running_content_start_at = 'body' unless toc_at_top
              when 'after-toc'
                uses_start_at_after_toc = true
                running_content_start_at = 'body'
              end
            end
            if ::Integer === (page_numbering_start_at = @theme.page_numbering_start_at)
              page_numbering_body_offset = body_offset + [page_numbering_start_at.pred, min_start_at.pred].max
              page_numbering_start_at = 'body'
            else
              page_numbering_body_offset = body_offset
              case page_numbering_start_at
              when 'cover'
                if has_front_cover
                  page_numbering_body_offset = 0
                else
                  page_numbering_start_at = 'title'
                end
              when 'title'
                page_numbering_start_at = 'toc' unless has_title_page
              when 'toc'
                uses_start_at_toc = true
                page_numbering_start_at = 'body' unless toc_at_top
              when 'after-toc'
                uses_start_at_after_toc = true
                page_numbering_start_at = 'body'
              end
            end
            # table values are number of pages to skip before starting running content and page numbering, respectively
            num_front_matter_pages = {
              %w(title cover) => [zero_page_offset, page_numbering_body_offset],
              %w(title title) => [zero_page_offset, zero_page_offset],
              %w(title toc) => [zero_page_offset, first_page_offset],
              %w(title body) => [zero_page_offset, page_numbering_body_offset],
              %w(toc cover) => [first_page_offset, page_numbering_body_offset],
              %w(toc title) => [first_page_offset, zero_page_offset],
              %w(toc toc) => [first_page_offset, first_page_offset],
              %w(toc body) => [first_page_offset, page_numbering_body_offset],
              %w(body cover) => [running_content_body_offset, page_numbering_body_offset],
              %w(body title) => [running_content_body_offset, zero_page_offset],
              %w(body toc) => [running_content_body_offset, first_page_offset],
            }[[running_content_start_at, page_numbering_start_at]] || [running_content_body_offset, page_numbering_body_offset]
          else
            body_offset = body_start_page_number - 1
            if ::Integer === (running_content_start_at = @theme.running_content_start_at)
              running_content_body_offset = body_offset + [running_content_start_at.pred, 0].max
            else
              running_content_body_offset = body_offset
            end
            if ::Integer === (page_numbering_start_at = @theme.page_numbering_start_at)
              page_numbering_body_offset = body_offset + [page_numbering_start_at.pred, 0].max
            elsif page_numbering_start_at == 'cover' && has_front_cover
              page_numbering_body_offset = 0
            else
              page_numbering_body_offset = body_offset
            end
            num_front_matter_pages = [running_content_body_offset, page_numbering_body_offset]
          end

          @index.start_page_number = num_front_matter_pages[1] + 1
          doc.set_attr 'pdf-anchor', (derive_anchor_from_id doc.id, 'top')
          doc.set_attr 'pdf-page-start', page_number

          if doctype == 'book' || (columns = @theme.page_columns || 1) < 2
            convert_section generate_manname_section doc if doctype == 'manpage' && (doc.attr? 'manpurpose')
            traverse doc
            # NOTE: for a book, these are leftover footnotes; for an article this is everything
            outdent_section { ink_footnotes doc }
          else
            column_box [bounds.left, cursor], columns: columns, width: bounds.width, reflow_margins: true, spacer: @theme.page_column_gap do
              convert_section generate_manname_section doc if doctype == 'manpage' && (doc.attr? 'manpurpose')
              traverse doc
              # NOTE: for a book, these are leftover footnotes; for an article this is everything
              outdent_section { ink_footnotes doc }
            end
          end

          if (toc_extent = @toc_extent)
            if title_as_page && !toc_at_top && (uses_start_at_toc || uses_start_at_after_toc)
              if uses_start_at_toc
                toc_offset = toc_extent.from.page - 1
                num_front_matter_pages[0] = toc_offset if @theme.running_content_start_at == 'toc'
                num_front_matter_pages[1] = toc_offset if @theme.page_numbering_start_at == 'toc'
              end
              if uses_start_at_after_toc
                after_toc_offset = toc_extent.to.page
                after_toc_offset += 1 if @ppbook && (recto_page? after_toc_offset)
                num_front_matter_pages[0] = after_toc_offset if @theme.running_content_start_at == 'after-toc'
                num_front_matter_pages[1] = after_toc_offset if @theme.page_numbering_start_at == 'after-toc'
              end
            end
            toc_page_nums = ink_toc doc, toc_num_levels, toc_extent.from.page, toc_extent.from.cursor, num_front_matter_pages[1]
          else
            toc_page_nums = []
          end

          # NOTE: delete orphaned page (a page was created but there was no additional content)
          # QUESTION: should we delete page if document is empty? (leaving no pages?)
          delete_current_page if page_count > 1 && page.empty?
        end

        unless page_count < body_start_page_number
          ink_running_content :header, doc, num_front_matter_pages, body_start_page_number unless doc.noheader || @theme.header_height.to_f == 0
          ink_running_content :footer, doc, num_front_matter_pages, body_start_page_number unless doc.nofooter || @theme.footer_height.to_f == 0
        end

        add_outline doc, (doc.attr 'outlinelevels', toc_num_levels), toc_page_nums, num_front_matter_pages[1], has_front_cover
        if (initial_zoom = @theme.page_initial_zoom&.to_sym)
          case initial_zoom
          when :Fit
            catalog.data[:OpenAction] = dest_fit state.pages[0]
          when :FitV
            catalog.data[:OpenAction] = dest_fit_vertically 0, state.pages[0]
          when :FitH
            catalog.data[:OpenAction] = dest_fit_horizontally page_height, state.pages[0]
          end
        end
        catalog.data[:ViewerPreferences] = { DisplayDocTitle: true }

        stamp_foreground_image doc, has_front_cover
        ink_cover_page doc, :back
        add_dest_for_top doc
        state.pages.each {|it| fit_trim_box it } if (@optimize&.[] :compliance)&.start_with? 'PDF/X'
        nil
      end

      # NOTE: embedded only makes sense if perhaps we are building
      # on an existing Prawn::Document instance; for now, just treat
      # it the same as a full document.
      alias convert_embedded convert_document

      def init_pdf doc
        # promote preface block to preface section
        doc.promote_preface_block
        # set default values for PDF-specific attributes if not otherwise specified (set or unset)
        doc.attributes['outline'] = '' if doc.attr_unspecified? 'outline'
        doc.attributes['outline-title'] = '' if doc.attr_unspecified? 'outline-title'
        doc.attributes['pagenums'] = '' if doc.attr_unspecified? 'pagenums'
        (instance_variables - @initial_instance_variables).each {|ivar| remove_instance_variable ivar } if state
        pdf_opts = build_pdf_options doc, (theme = load_theme doc)
        # QUESTION: should page options be preserved? (otherwise, not readily available)
        #@page_opts = { size: pdf_opts[:page_size], layout: pdf_opts[:page_layout] }
        ((::Prawn::Document.instance_method :initialize).bind self).call pdf_opts
        register_fonts theme.font_catalog, ((doc.attr 'pdf-fontsdir')&.sub '{docdir}', (doc.attr 'docdir')) || 'GEM_FONTS_DIR'
        renderer.min_version (@pdf_version = PDFVersions[doc.attr 'pdf-version'])
        @allow_uri_read = doc.attr? 'allow-uri-read'
        @cache_uri = doc.attr? 'cache-uri'
        @jail_dir = doc.safe < ::Asciidoctor::SafeMode::SAFE ? nil : doc.base_dir
        @media ||= doc.attr 'media', 'screen'
        case doc.attr 'pdf-folio-placement', (@media == 'prepress' ? 'physical' : 'virtual')
        when 'physical'
          @folio_placement = { basis: :physical }
        when 'physical-inverted'
          @folio_placement = { basis: :physical, inverted: true }
        when 'virtual-inverted'
          @folio_placement = { basis: :virtual, inverted: true }
        else
          @folio_placement = { basis: :virtual }
        end
        @page_margin = { cover: page_margin }
        @page_margin[:portrait] = @page_margin[:landscape] = { recto: (page_margin_recto = page_margin), verso: (page_margin_verso = page_margin) }
        if (rotated_page_margin = resolve_page_margin (doc.attr 'pdf-page-margin-rotated') || theme.page_margin_rotated)
          rotated_page_margin = expand_margin_value rotated_page_margin
          @edge_shorthand_cache = nil
          @page_margin[PageLayouts[(PageLayouts.index page.layout) - 1]] = { recto: rotated_page_margin, verso: (rotated_page_margin.drop 0) }
        end
        if @media == 'prepress'
          @ppbook = doc.doctype == 'book'
          if (page_margin_outer = theme.page_margin_outer)
            page_margin_recto[1] = page_margin_verso[3] = page_margin_outer
          end
          if (page_margin_inner = theme.page_margin_inner)
            page_margin_recto[3] = page_margin_verso[1] = page_margin_inner
          end
        else
          @ppbook = nil
        end
        @page_bg_image = {}
        @page_bg_color = resolve_theme_color :page_background_color, 'FFFFFF'
        default_kerning theme.base_font_kerning != 'none'
        @fallback_fonts = Array theme.font_fallbacks
        @root_font_size = theme.base_font_size
        @font_scale = 1
        @font_color = theme.base_font_color
        @text_decoration_width = theme.base_text_decoration_width
        @base_text_align = (text_align = doc.attr 'text-align') && TextAlignmentNames[text_align] ? text_align : theme.base_text_align
        @base_line_height = theme.base_line_height
        @cjk_line_breaks = doc.attr? 'scripts', 'cjk'
        if (hyphen_lang = (doc.attr 'hyphens') || ((doc.attr_unspecified? 'hyphens') ? @theme.base_hyphens : nil)) &&
            ((defined? ::Text::Hyphen::VERSION) || !(Helpers.require_library 'text/hyphen', 'text-hyphen', :warn).nil?)
          hyphen_lang = doc.attr 'lang' if !(::String === hyphen_lang) || hyphen_lang.empty?
          hyphen_lang = 'en_us' if hyphen_lang.nil_or_empty? || hyphen_lang == 'en'
          hyphen_lang = (hyphen_lang.tr '-', '_').downcase
          @hyphenator = ::Text::Hyphen.new language: hyphen_lang
        end
        @text_transform = nil
        @list_numerals = []
        @list_bullets = []
        @bottom_gutters = [{}]
        @rendered_footnotes = []
        @bibref_refs = ::Set.new
        @conum_glyphs = ConumSets[@theme.conum_glyphs || 'circled'] || (@theme.conum_glyphs.split ',').map do |r|
          from, to = r.lstrip.split '-', 2
          to ? ((get_char from)..(get_char to)).to_a : [(get_char from)]
        end.flatten
        @section_indent = (val = @theme.section_indent) && (expand_indent_value val)
        @toc_max_pagenum_digits = (doc.attr 'toc-max-pagenum-digits', 3).to_i
        @disable_running_content = { header: ::Set.new, footer: ::Set.new }
        @index ||= IndexCatalog.new
        # NOTE: we have to init Pdfmark class here while we have reference to the doc
        @pdfmark = (doc.attr? 'pdfmark') ? (Pdfmark.new doc) : nil
        # NOTE: defer instantiating optimizer until we know min pdf version
        if (optimize = doc.attr 'optimize') &&
            (optimizer = doc.options[:pdf_optimizer] || (Optimizer.for (doc.attr 'pdf-optimizer', 'rghost')))
          @optimize = (optimize.include? ',') ?
            ([:quality, :compliance].zip (optimize.split ',', 2)).to_h :
            ((optimize.include? '/') ? { compliance: optimize } : { quality: optimize })
          fit_trim_box if @optimize[:compliance]&.start_with? 'PDF/X'
          @optimize[:optimizer] = optimizer
        else
          @optimize = nil
        end
        image_info_cache
        # allocate_scratch_prototype calls create_scrate_prototype to set up the scratch prototype
        # scratch calls init_scratch on a copy of the prototype to instantiate a scratch document
        # push_scratch and pop_scratch make changes to the document catalog and attributes transactional
        allocate_scratch_prototype
        # NOTE: & prefix required here to pass resolved method as block of on_page_create method
        on_page_create(&(method :init_page).curry[doc])
        self
      end

      def build_pdf_options doc, theme
        page_margin = resolve_page_margin (doc.attr 'pdf-page-margin') || theme.page_margin

        if (doc.attr? 'pdf-page-size') && PageSizeRx =~ (doc.attr 'pdf-page-size')
          # e.g, [8.5in, 11in]
          if $1
            page_size = [$1, $2]
          # e.g, 8.5in x 11in
          elsif $3
            page_size = [$3, $4]
          # e.g, A4
          else
            page_size = $&
          end
        else
          page_size = theme.page_size
        end

        case page_size
        when ::String, ::Symbol
          # TODO: extract helper method to check for named page size
          page_size = page_size.to_s.upcase
          page_size = nil unless ::PDF::Core::PageGeometry::SIZES.key? page_size
        when ::Array
          if page_size.empty?
            page_size = nil
          else
            page_size[1] ||= page_size[0]
            page_size = (page_size.slice 0, 2).map do |dim|
              if ::Numeric === dim
                # dimension cannot be less than 0
                dim > 0 ? dim : break
              elsif ::String === dim && MeasurementPartsRx =~ dim
                # NOTE: truncate to max precision retained by PDF::Core
                (dim = (to_pt $1.to_f, $2).truncate 4) > 0 ? dim : break
              else
                break
              end
            end
          end
        else
          page_size = nil
        end

        if (page_layout = (doc.attr 'pdf-page-layout') || theme.page_layout).nil_or_empty? ||
            !(PageLayouts.include? (page_layout = page_layout.to_sym))
          page_layout = nil
        end

        {
          margin: (page_margin || 36),
          page_size: (page_size || 'A4'),
          page_layout: (page_layout || :portrait),
          info: (build_pdf_info doc),
          compress: (doc.attr? 'compress'),
          skip_page_creation: true,
          text_formatter: (FormattedText::Formatter.new theme: theme),
        }
      end

      # FIXME: Pdfmark should use the PDF info result
      def build_pdf_info doc
        info = {}
        if (doctitle = resolve_doctitle doc)
          info[:Title] = (sanitize doctitle).as_pdf
        end
        if (doc.attribute_locked? 'author') && !(doc.attribute_locked? 'authors')
          info[:Author] = (sanitize doc.attr 'author').as_pdf
        elsif doc.attr? 'authors'
          info[:Author] = (sanitize doc.attr 'authors').as_pdf
        elsif doc.attr? 'author' # rubocop:disable Lint/DuplicateBranch
          info[:Author] = (sanitize doc.attr 'author').as_pdf
        end
        info[:Subject] = (sanitize doc.attr 'subject').as_pdf if doc.attr? 'subject'
        info[:Keywords] = (sanitize doc.attr 'keywords').as_pdf if doc.attr? 'keywords'
        info[:Creator] = (doc.attr? 'publisher') ? (sanitize doc.attr 'publisher').as_pdf : (info[:Author] || '')
        info[:Producer] = (sanitize doc.attr 'producer').as_pdf if doc.attr? 'producer'
        if doc.attr? 'reproducible'
          info[:Producer] ||= 'Asciidoctor PDF, based on Prawn'.as_pdf
        else
          info[:Producer] ||= %(Asciidoctor PDF #{::Asciidoctor::PDF::VERSION}, based on Prawn #{::Prawn::VERSION}).as_pdf
          # NOTE: since we don't track the creation date of the input file, we map the ModDate header to the last modified
          # date of the input document and the CreationDate header to the date the PDF was produced by the converter.
          info[:ModDate] = (::Time.parse doc.attr 'docdatetime') rescue (now ||= ::Time.now)
          info[:CreationDate] = (::Time.parse doc.attr 'localdatetime') rescue (now || ::Time.now)
        end
        info
      end

      def load_theme doc
        @theme ||= begin # rubocop:disable Naming/MemoizedInstanceVariableName
          if (theme = doc.options[:pdf_theme])
            theme = theme.dup
            @themesdir = ::File.expand_path theme.__dir__ ||
              (user_themesdir = ((doc.attr 'pdf-themesdir')&.sub '{docdir}', (doc.attr 'docdir')) || ::Dir.pwd)
          elsif (theme_name = doc.attr 'pdf-theme')
            theme = ThemeLoader.load_theme theme_name, (user_themesdir = (doc.attr 'pdf-themesdir')&.sub '{docdir}', (doc.attr 'docdir'))
            @themesdir = theme.__dir__
          elsif (doc.attr 'media', 'screen') == 'screen'
            @themesdir = (theme = ThemeLoader.load_theme).__dir__
          else
            @themesdir = (theme = ThemeLoader.load_theme 'default-for-print').__dir__
          end
          prepare_theme theme
        rescue
          if user_themesdir
            message = %(could not locate or load the pdf theme `#{theme_name}' in #{user_themesdir})
          else
            message = %(could not locate or load the built-in pdf theme `#{theme_name}')
          end
          message += %( because of #{$!.class} #{$!.message})
          log :error, (message.sub %r/$/, '; reverting to default theme')
          @themesdir = (theme = ThemeLoader.load_theme).__dir__
          prepare_theme theme
        end
      end

      def prepare_theme theme
        theme.base_border_color = nil if theme.base_border_color == 'transparent'
        theme.base_font_color ||= '000000'
        theme.base_font_family ||= 'Helvetica'
        theme.base_font_style = theme.base_font_style&.to_sym || :normal
        theme.page_numbering_start_at ||= 'body'
        theme.running_content_start_at ||= 'body'
        theme.heading_chapter_break_before ||= 'always'
        theme.heading_part_break_before ||= 'always'
        theme.heading_margin_page_top ||= 0
        theme.heading_margin_top ||= 0
        theme.heading_margin_bottom ||= 0
        theme.prose_text_indent ||= 0
        theme.prose_text_indent_inner ||= 0
        theme.prose_margin_bottom ||= 0
        theme.block_margin_bottom ||= 0
        theme.list_indent ||= 0
        theme.list_item_spacing ||= 0
        theme.description_list_term_spacing ||= 0
        theme.description_list_description_indent ||= 0
        theme.table_border_color ||= (theme.base_border_color || '000000')
        theme.table_border_width ||= 0.5
        theme.thematic_break_border_color ||= (theme.base_border_color || '000000')
        theme.image_border_width ||= 0
        theme.code_linenum_font_color ||= '999999'
        theme.callout_list_margin_top_after_code ||= 0
        theme.role_unresolved_font_color ||= 'FF0000'
        theme.footnotes_margin_top ||= 'auto'
        theme.footnotes_item_spacing ||= 0
        theme.index_columns ||= 2
        theme.index_column_gap ||= theme.base_font_size
        theme.kbd_separator_content ||= %(+#{ZeroWidthSpace})
        theme.menu_caret_content ||= %(#{NoBreakSpace}\u203a )
        theme.title_page_authors_delimiter ||= ', '
        theme.toc_indent ||= 0
        theme.toc_hanging_indent ||= 0
        if ::Array === (quotes = theme.quotes)
          TypographicQuotes.each_with_index {|char, idx| quotes[idx] ||= char }
        else
          theme.quotes = TypographicQuotes
        end
        theme
      end

      def save_theme
        @theme = (original_theme = theme).dup
        yield
      ensure
        @theme = original_theme
      end

      def indent_section
        if (values = @section_indent)
          indent(values[0], values[1]) { yield }
        else
          yield
        end
      end

      def outdent_section enabled = true
        if enabled && (values = @section_indent)
          indent(-values[0], -values[1]) { yield }
        else
          yield
        end
      end

      def convert_section sect, _opts = nil
        if (sectname = sect.sectname) == 'abstract'
          # HACK: cheat a bit to hide this section from TOC; TOC should filter these sections
          sect.context = :open
          return convert_abstract sect
        elsif (index_section = sectname == 'index') && @index.empty?
          # override numbered_title to hide entry from TOC
          sect.define_singleton_method :numbered_title, ->(*) { '' }
          return
        end
        title = sect.numbered_title formal: true
        sep = (sect.attr 'separator') || (sect.document.attr 'title-separator') || ''
        if !sep.empty? && (title.include? (sep = %(#{sep} )))
          title, _, subtitle = title.rpartition sep
          title = %(#{title}\n<em class="subtitle">#{subtitle}</em>)
        end
        hlevel = sect.level.next
        text_align = (@theme[%(heading_h#{hlevel}_text_align)] || @theme.heading_text_align || @base_text_align).to_sym
        chapterlike = !(part = sectname == 'part') && (sectname == 'chapter' || (sect.document.doctype == 'book' && sect.level == 1))
        hidden = sect.option? 'notitle'
        hopts = { align: text_align, level: hlevel, part: part, chapterlike: chapterlike, outdent: !(part || chapterlike) }
        if part
          if @theme.heading_part_break_before == 'always'
            started_new = true
            start_new_part sect
          end
        elsif chapterlike
          if (@theme.heading_chapter_break_before == 'always' &&
              !(@theme.heading_part_break_after == 'avoid' && sect.first_section_of_part?)) ||
              (@theme.heading_part_break_after == 'always' && sect.first_section_of_part?)
            started_new = true
            start_new_chapter sect
          end
        end
        arrange_heading sect, title, hopts unless hidden || started_new || at_page_top?
        # QUESTION: should we store pdf-page-start, pdf-anchor & pdf-destination in internal map?
        sect.set_attr 'pdf-page-start', (start_pgnum = page_number)
        # QUESTION: should we just assign the section this generated id?
        # NOTE: section must have pdf-anchor in order to be listed in the TOC
        sect.set_attr 'pdf-anchor', (sect_anchor = derive_anchor_from_id sect.id, %(#{start_pgnum}-#{y.ceil}))
        add_dest_for_block sect, id: sect_anchor, y: (at_page_top? ? page_height : nil)
        theme_font :heading, level: hlevel do
          if part
            ink_part_title sect, title, hopts
          elsif chapterlike
            ink_chapter_title sect, title, hopts
          else
            ink_general_heading sect, title, hopts
          end
        end unless hidden

        if index_section
          outdent_section { convert_index_section sect }
        else
          traverse sect
        end
        outdent_section { ink_footnotes sect } if chapterlike
        sect.set_attr 'pdf-page-end', page_number
      end

      def convert_floating_title node
        title = node.title
        hlevel = node.level.next
        unless (text_align = resolve_text_align_from_role node.roles)
          text_align = (@theme[%(heading_h#{hlevel}_text_align)] || @theme.heading_text_align || @base_text_align).to_sym
        end
        hopts = { align: text_align, level: hlevel, outdent: node.parent.context == :section }
        arrange_heading node, title, hopts unless at_page_top? || node.last_child?
        add_dest_for_block node if node.id
        # QUESTION: should we decouple styles from section titles?
        theme_font :heading, level: hlevel do
          ink_general_heading node, title, hopts
        end
      end

      def convert_index_section node
        if ColumnBox === bounds || (columns = @theme.index_columns || 1) < 2
          convert_index_categories @index.categories, (node.document.attr 'index-pagenum-sequence-style')
        else
          end_cursor = nil
          column_box [bounds.left, cursor], columns: columns, width: bounds.width, reflow_margins: true, spacer: @theme.index_column_gap do
            convert_index_categories @index.categories, (node.document.attr 'index-pagenum-sequence-style')
            end_cursor = cursor if bounds.current_column == 0
          end
          # Q: could we move this logic into column_box?
          move_cursor_to end_cursor if end_cursor
        end
        nil
      end

      def convert_index_categories categories, pagenum_sequence_style = nil
        space_needed_for_category = @theme.description_list_term_spacing + (2 * (height_of_typeset_text 'A'))
        categories.each do |category|
          bounds.move_past_bottom if space_needed_for_category > cursor
          ink_prose category.name,
            align: :left,
            inline_format: false,
            margin_bottom: @theme.description_list_term_spacing,
            style: @theme.description_list_term_font_style&.to_sym
          category.terms.each {|term| convert_index_term term, pagenum_sequence_style }
          @theme.prose_margin_bottom > cursor ? bounds.move_past_bottom : (move_down @theme.prose_margin_bottom)
        end
      end

      def convert_index_term term, pagenum_sequence_style = nil
        term_fragments = term.name.fragments
        unless term.container?
          pagenum_fragment = (parse_text %(<a>#{DummyText}</a>), inline_format: true)[0]
          if @media == 'screen'
            case pagenum_sequence_style
            when 'page'
              pagenums = term.dests.uniq {|dest| dest[:page] }.map {|dest| pagenum_fragment.merge anchor: dest[:anchor], text: dest[:page] }
            when 'range'
              first_anchor_per_page = {}.tap {|accum| term.dests.each {|dest| accum[dest[:page]] ||= dest[:anchor] } }
              pagenums = (consolidate_ranges first_anchor_per_page.keys).map do |range|
                anchor = first_anchor_per_page[(range.include? '-') ? (range.partition '-')[0] : range]
                pagenum_fragment.merge text: range, anchor: anchor
              end
            else # term
              pagenums = term.dests.map {|dest| pagenum_fragment.merge text: dest[:page], anchor: dest[:anchor] }
            end
          else
            pagenums = consolidate_ranges term.dests.map {|dest| dest[:page] }.uniq
          end
          pagenums.each do |pagenum|
            if ::String === pagenum
              term_fragments << ({ text: %(, #{pagenum}) })
            else
              term_fragments << { text: ', ' }
              term_fragments << pagenum
            end
          end
        end
        subterm_indent = @theme.description_list_description_indent
        typeset_formatted_text term_fragments, (calc_line_metrics @base_line_height), align: :left, color: @font_color, hanging_indent: subterm_indent * 2, consolidate: true
        indent subterm_indent do
          term.subterms.each do |subterm|
            convert_index_term subterm, pagenum_sequence_style
          end
        end unless term.leaf?
      end

      def convert_preamble node
        # FIXME: core should not be promoting paragraph to preamble if there are no sections
        if (first_block = node.first_child)&.context == :paragraph && node.document.sections? && !first_block.role?
          first_block.set_attr 'role', 'lead'
        end
        traverse node
        theme_margin :block, :bottom, (next_enclosed_block node)
        convert_toc node, placement: 'preamble'
      end

      def convert_abstract node
        add_dest_for_block node if node.id
        outdent_section do
          pad_box @theme.abstract_padding do
            theme_font :abstract_title do
              ink_prose node.title, align: (@theme.abstract_title_text_align || @base_text_align).to_sym, margin_top: @theme.heading_margin_top, margin_bottom: @theme.heading_margin_bottom, line_height: (@theme.heading_line_height || @theme.base_line_height)
            end if node.title?
            theme_font :abstract do
              prose_opts = { align: (@theme.abstract_text_align || @base_text_align).to_sym, hyphenate: true, margin_bottom: 0 }
              # FIXME: allow theme to control more first line options
              if (line1_font_style = @theme.abstract_first_line_font_style&.to_sym) && line1_font_style != font_style
                case line1_font_style
                when :normal
                  first_line_options = { styles: [] }
                when :normal_italic
                  first_line_options = { styles: [:italic] }
                else
                  first_line_options = { styles: [font_style, line1_font_style] }
                end
              end
              if (line1_font_color = @theme.abstract_first_line_font_color)
                (first_line_options ||= {})[:color] = line1_font_color
              end
              if (line1_text_transform = @theme.abstract_first_line_text_transform)
                (first_line_options ||= {})[:text_transform] = line1_text_transform
              end
              prose_opts[:first_line_options] = first_line_options if first_line_options
              # FIXME: make this cleaner!!
              if node.blocks?
                node.blocks.each do |child|
                  if child.context == :paragraph
                    child.document.playback_attributes child.attributes
                    convert_paragraph child, prose_opts.merge
                    prose_opts.delete :first_line_options
                  else
                    # FIXME: this could do strange things if the wrong kind of content shows up
                    child.convert
                  end
                end
              elsif node.content_model != :compound && (string = node.content)
                if (text_align = resolve_text_align_from_role node.roles)
                  prose_opts[:align] = text_align
                end
                if IndentableTextAlignments[prose_opts[:align]] && (text_indent = @theme.prose_text_indent) > 0
                  prose_opts[:indent_paragraphs] = text_indent
                end
                ink_prose string, prose_opts
              end
            end
          end
        end
        # NOTE: next enclosed block here is confined to preamble
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      def convert_paragraph node, opts = nil
        add_dest_for_block node if node.id

        prose_opts = opts || { margin_bottom: 0, hyphenate: true }
        if (text_align = resolve_text_align_from_role (roles = node.roles), query_theme: true, remove_predefined: true)
          prose_opts[:align] = text_align
        else
          text_align = @base_text_align.to_sym
        end
        role_keys = roles.map {|role| %(role_#{role}) } unless roles.empty?
        if IndentableTextAlignments[text_align] &&
            ((text_indent = @theme.prose_text_indent) > 0 ||
            ((text_indent = @theme.prose_text_indent_inner) > 0 && node.previous_sibling&.context == :paragraph))
          prose_opts[:indent_paragraphs] = text_indent
        end
        if (bottom_gutter = @bottom_gutters[-1][node])
          prose_opts[:bottom_gutter] = bottom_gutter
        end

        block_next = next_enclosed_block node

        insert_margin_bottom = proc do
          if (margin_inner_val = @theme.prose_margin_inner) && block_next&.context == :paragraph
            margin_bottom margin_inner_val
          else
            theme_margin :prose, :bottom, block_next
          end
        end

        if (float_box = (@float_box ||= nil))
          ink_paragraph_in_float_box node, float_box, prose_opts, role_keys, block_next, insert_margin_bottom
        else
          # TODO: check if we're within one line of the bottom of the page
          # and advance to the next page if so (similar to logic for section titles)
          ink_caption node, labeled: false if node.title?
          role_keys ? theme_font_cascade(role_keys) { ink_prose node.content, prose_opts } : (ink_prose node.content, prose_opts)
          insert_margin_bottom.call
        end
      end

      def convert_admonition node
        type = node.attr 'name'
        label_text_align = @theme.admonition_label_text_align&.to_sym || :center
        # TODO: allow vertical_align to be a number
        if (label_valign = @theme.admonition_label_vertical_align&.to_sym || :middle) == :middle
          label_valign = :center
        end
        if (label_min_width = @theme.admonition_label_min_width)
          label_min_width = label_min_width.to_f
        end
        if (doc = node.document).attr? 'icons'
          if !(has_icon = node.attr? 'icon') && (doc.attr 'icons') == 'font'
            icons = 'font'
            icon_data = admonition_icon_data type.to_sym
            icon_size = (label_width = icon_data[:size] || 36) * (icon_data[:scale] || 2/3r).to_f
            label_width = label_min_width if label_min_width && label_min_width > label_width
          elsif (icon_path = has_icon || !(icon_path = @theme[%(admonition_icon_#{type})]&.[](:image)) ?
              (get_icon_image_path node, type) :
              (ThemeLoader.resolve_theme_asset (apply_subs_discretely doc, icon_path, subs: [:attributes], imagesdir: @themesdir), @themesdir)) &&
              (::File.readable? icon_path)
            icons = true
            icon_data = admonition_icon_data type.to_sym
            icon_width = (label_width = icon_data[:width] || 36) * (icon_data[:scale] || 2/3r).to_f
            label_width = label_min_width if label_min_width && label_min_width > label_width
          else
            log :warn, %(admonition icon image#{has_icon ? '' : ' for ' + type.upcase} not found or not readable: #{icon_path || (get_icon_image_path node, type, false)})
          end
        end
        unless icons
          label_text = sanitize node.caption
          theme_font_cascade [:admonition_label, %(admonition_label_#{type})] do
            label_text = transform_text label_text, @text_transform if @text_transform
            label_width = rendered_width_of_string label_text
            label_width = label_min_width if label_min_width && label_min_width > label_width
          end
        end
        cpad = expand_padding_value @theme.admonition_padding
        lpad = (lpad = @theme.admonition_label_padding) ? (expand_padding_value lpad) : cpad
        arrange_block node do |extent|
          add_dest_for_block node if node.id
          theme_fill_and_stroke_block :admonition, extent if extent
          pad_box [0, cpad[1], 0, lpad[3]] do
            if extent
              label_height = extent.single_page_height || cursor
              if (rule_width = @theme.admonition_column_rule_width || 0) > 0 &&
                  (rule_color = resolve_theme_color :admonition_column_rule_color, @theme.base_border_color, nil)
                rule_style = @theme.admonition_column_rule_style&.to_sym || :solid
                float do
                  extent.each_page do |first_page, last_page|
                    advance_page unless first_page
                    rule_segment_height = start_cursor = cursor
                    rule_segment_height -= last_page.cursor if last_page
                    bounding_box [bounds.left, start_cursor], width: label_width + lpad[1], height: rule_segment_height do
                      stroke_vertical_rule rule_color, at: bounds.right, line_style: rule_style, line_width: rule_width
                    end
                  end
                end
              end
              float do
                adjusted_font_size = nil
                bounding_box [bounds.left, cursor], width: label_width, height: label_height do
                  if icons == 'font'
                    # FIXME: we assume icon is square
                    icon_size = fit_icon_to_bounds icon_size
                    # NOTE: Prawn's vertical center is not reliable, so calculate it manually
                    if label_valign == :center
                      label_valign = :top
                      if (vcenter_pos = (label_height - icon_size) * 0.5) > 0
                        move_down vcenter_pos
                      end
                    end
                    icon icon_data[:name],
                      valign: label_valign,
                      align: label_text_align,
                      color: (icon_data[:stroke_color] || font_color),
                      size: icon_size
                  elsif icons
                    if (::Asciidoctor::Image.format icon_path) == 'svg'
                      begin
                        svg_obj = ::Prawn::SVG::Interface.new (::File.read icon_path, mode: 'r:UTF-8'), self,
                          position: label_text_align,
                          vposition: label_valign,
                          width: icon_width,
                          height: label_height,
                          fallback_font_name: fallback_svg_font_name,
                          enable_web_requests: allow_uri_read ? (method :load_open_uri).to_proc : false,
                          enable_file_requests_with_root: { base: (::File.dirname icon_path), root: @jail_dir },
                          cache_images: cache_uri
                        svg_obj.resize height: label_height if svg_obj.document.sizing.output_height > label_height
                        svg_obj.draw
                        svg_obj.document.warnings.each do |icon_warning|
                          log :warn, %(problem encountered in image: #{icon_path}; #{icon_warning})
                        end unless scratch?
                      rescue
                        log :warn, %(could not embed admonition icon image: #{icon_path}; #{$!.message})
                        icons = nil
                      end
                    else
                      begin
                        image_obj, image_info = ::File.open(icon_path, 'rb') {|fd| build_image_object fd }
                        icon_aspect_ratio = image_info.width.fdiv image_info.height
                        if (icon_height = icon_width * (1 / icon_aspect_ratio)) > label_height
                          icon_width *= label_height / icon_height
                        end
                        embed_image image_obj, image_info, width: icon_width, position: label_text_align, vposition: label_valign
                      rescue
                        log :warn, %(could not embed admonition icon image: #{icon_path}; #{$!.message})
                        icons = nil
                      end
                    end
                    unless icons
                      label_text = sanitize node.caption
                      theme_font_cascade [:admonition_label, %(admonition_label_#{type})] do
                        label_text = transform_text label_text, @text_transform if @text_transform
                        # NOTE: make sure the textual label fits in space already reserved
                        if (actual_label_width = rendered_width_of_string label_text) > label_width
                          adjusted_font_size = font_size * label_width / actual_label_width
                        end
                      end
                      redo
                    end
                  else
                    # NOTE: the label must fit in the alotted space or it shows up on another page!
                    # QUESTION: anyway to prevent text overflow in the case it doesn't fit?
                    theme_font_cascade [:admonition_label, %(admonition_label_#{type})] do
                      font_size adjusted_font_size if adjusted_font_size
                      # NOTE: Prawn's vertical center is not reliable, so calculate it manually
                      if label_valign == :center
                        label_valign = :top
                        if (vcenter_pos = (label_height - (height_of_typeset_text label_text, line_height: 1)) * 0.5) > 0
                          move_down vcenter_pos
                        end
                      end
                      @text_transform = nil # already applied to label
                      ink_prose label_text,
                        align: label_text_align,
                        valign: label_valign,
                        line_height: 1,
                        margin: 0,
                        inline_format: false, # already replaced character references
                        overflow: :shrink_to_fit,
                        disable_wrap_by_char: true
                    end
                  end
                end
              end
            end
            pad_box [cpad[0], 0, cpad[2], label_width + lpad[1] + cpad[3]], node do
              ink_caption node, category: :admonition, labeled: false if node.title?
              theme_font :admonition do
                traverse node
              end
            end
          end
        end
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      # QUESTION: can we avoid arranging fragments multiple times (conums & autofit) by eagerly preparing arranger?
      def convert_code node
        extensions = []
        source_chunks = source_string = bg_color_override = font_color_override = adjusted_font_size = nil
        theme_font :code do
          # HACK: disable built-in syntax highlighter; must be done before calling node.content!
          if node.style == 'source' && (highlighter = (syntax_hl = node.document.syntax_highlighter)&.highlight? && syntax_hl.name)
            case highlighter
            when 'coderay'
              Helpers.require_library CodeRayRequirePath, 'coderay' unless defined? ::Asciidoctor::Prawn::CodeRayEncoder
            when 'pygments'
              Helpers.require_library PygmentsRequirePath, 'pygments.rb' unless defined? ::Pygments::Ext::BlockStyles
            when 'rouge'
              Helpers.require_library RougeRequirePath, 'rouge' unless defined? ::Rouge::Formatters::Prawn
            else
              highlighter = nil
            end
            saved_subs = (subs = node.subs).drop 0
            callouts_enabled = subs.include? :callouts
            highlight_idx = subs.index :highlight
            # NOTE: scratch? here only applies if listing block is nested inside another block
            if !highlighter || scratch?
              highlighter = nil
              if highlight_idx
                # switch the :highlight sub back to :specialcharacters
                subs[highlight_idx] = :specialcharacters
              else
                saved_subs = nil
              end
              source_string = guard_indentation node.content
            elsif highlight_idx
              # NOTE: the source highlighter logic below handles the highlight and callouts subs
              if (subs - [:highlight, :callouts]).empty?
                subs.clear
                # NOTE: indentation guards will be added by the source highlighter logic
                source_string = expand_tabs node.content
              else
                if callouts_enabled
                  saved_lines = node.lines.drop 0
                  subs.delete :callouts
                  prev_subs = subs.drop 0
                  subs.clear
                  source_string, conum_mapping = extract_conums node.content
                  node.lines.replace (source_string.split LF)
                  subs.replace prev_subs
                  callouts_enabled = false
                end
                subs[highlight_idx] = :specialcharacters
                source_string = node.content || ''
                # NOTE: indentation guards will be added by the source highlighter logic
                source_string = expand_tabs unescape_xml (sanitize source_string, compact: false) unless source_string.empty?
                node.lines.replace saved_lines if saved_lines
              end
            else
              highlighter = saved_subs = nil
              source_string = guard_indentation node.content
            end
          else
            highlighter = nil
            if (node.subs.include? :callouts) && (CalloutConflictRx.match? node.source)
              node.lines.replace (node.lines.map {|l| (l.include? '<') ? (l.gsub CalloutConflictRx, %(\\1\u200b\\2)) : l })
            end
            source_string = guard_indentation node.content
          end

          case highlighter
          when 'coderay'
            source_string, conum_mapping = extract_conums source_string if callouts_enabled
            srclang = node.attr 'language', 'text'
            begin
              ::CodeRay::Scanners[(srclang = (srclang.start_with? 'html+') ? (srclang.slice 5, srclang.length).to_sym : srclang.to_sym)]
            rescue
              until ::LoadError === (cause ||= $!) || ::ArgumentError === cause
                raise $! unless (cause = cause.cause)
              end
              srclang = :text
            end
            fragments = (::CodeRay.scan source_string, srclang).to_prawn
            source_chunks = conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
          when 'pygments'
            unless (style = (node.document.attr 'pygments-style')) && (::Pygments::Ext::BlockStyles.available? style)
              style = 'pastie'
            end
            # QUESTION: allow border color to be set by theme for highlighted block?
            pg_block_styles = ::Pygments::Ext::BlockStyles.for style
            bg_color_override = pg_block_styles[:background_color]
            font_color_override = pg_block_styles[:font_color]
            if source_string.empty?
              source_chunks = []
            else
              lexer = (::Pygments::Lexer.find_by_alias node.attr 'language', 'text') || (::Pygments::Lexer.find_by_mimetype 'text/plain')
              lexer_opts = { nowrap: true, noclasses: true, stripnl: false, style: style }
              lexer_opts[:startinline] = !(node.option? 'mixed') if lexer.name == 'PHP'
              source_string, conum_mapping = extract_conums source_string if callouts_enabled
              # NOTE: highlight can return nil if something goes wrong; fallback to encoded source string if this happens
              result = (lexer.highlight source_string, options: lexer_opts) || (node.apply_subs source_string, [:specialcharacters])
              if node.attr? 'highlight'
                if (highlight_lines = node.resolve_lines_to_highlight source_string, (node.attr 'highlight')).empty?
                  highlight_lines = nil
                else
                  pg_highlight_bg_color = pg_block_styles[:highlight_background_color]
                  highlight_lines = {}.tap {|accum| highlight_lines.each {|linenum| accum[linenum] = pg_highlight_bg_color } }
                end
              end
              if (node.option? 'linenums') || (node.attr? 'linenums')
                linenums = (node.attr 'start', 1).to_i
                postprocess = true
                extensions << FormattedText::SourceWrap
              elsif conum_mapping || highlight_lines
                postprocess = true
              end
              fragments = text_formatter.format result
              fragments = restore_conums fragments, conum_mapping, linenums, highlight_lines if postprocess
              source_chunks = guard_indentation_in_fragments fragments
            end
          when 'rouge'
            formatter = (@rouge_formatter ||= ::Rouge::Formatters::Prawn.new theme: (node.document.attr 'rouge-style'), line_gap: @theme.code_line_gap, highlight_background_color: @theme.code_highlight_background_color)
            # QUESTION: allow border color to be set by theme for highlighted block?
            bg_color_override = formatter.background_color
            if source_string.empty?
              source_chunks = []
            else
              if (node.option? 'linenums') || (node.attr? 'linenums')
                formatter_opts = { line_numbers: true, start_line: (node.attr 'start', 1).to_i }
                extensions << FormattedText::SourceWrap
              else
                formatter_opts = {}
              end
              if (srclang = node.attr 'language')
                if srclang.include? '?'
                  if (lexer = ::Rouge::Lexer.find_fancy srclang)&.tag == 'php' && !(node.option? 'mixed') && !((lexer_opts = lexer.options).key? 'start_inline')
                    lexer = lexer.class.new lexer_opts.merge 'start_inline' => true
                  end
                elsif (lexer = ::Rouge::Lexer.find srclang)&.tag == 'php' && !(node.option? 'mixed')
                  lexer = lexer.new start_inline: true
                end
              end
              lexer ||= ::Rouge::Lexers::PlainText
              source_string, conum_mapping = extract_conums source_string if callouts_enabled
              if (node.attr? 'highlight') && !(hl_lines = (node.resolve_lines_to_highlight source_string, (node.attr 'highlight'))).empty?
                formatter_opts[:highlight_lines] = {}.tap {|accum| hl_lines.each {|linenum| accum[linenum] = true } }
              end
              fragments = formatter.format (lexer.lex source_string), formatter_opts rescue [text: source_string]
              source_chunks = conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
            end
          else
            # NOTE: only format if we detect a need (callouts or inline formatting)
            source_chunks = (XMLMarkupRx.match? source_string) ? (text_formatter.format source_string) : [text: source_string]
          end
          node.subs.replace saved_subs if saved_subs
          adjusted_font_size = ((node.option? 'autofit') || (node.document.attr? 'autofit-option')) ? (compute_autofit_font_size source_chunks, :code) : nil
        end

        if !(unbreakable = node.option? 'unbreakable') && (breakable_min_lines = @theme.code_breakable_min_lines) && (source_string.count LF) + 1 < breakable_min_lines
          node.set_option 'unbreakable'
          toggle_breakable = true
        end
        caption_below = @theme.code_caption_end&.to_sym == :bottom
        arrange_block node do |extent|
          add_dest_for_block node if node.id
          tare_first_page_content_stream do
            theme_fill_and_stroke_block :code, extent, background_color: bg_color_override, caption_node: caption_below ? nil : node
          end
          unless extent || unbreakable || (cursor >= (@theme.code_orphans_min_height || 0))
            delete_current_page
            raise NewPageRequiredError
          end
          pad_box @theme.code_padding, node do
            theme_font :code do
              typeset_formatted_text source_chunks, (calc_line_metrics @base_line_height),
                color: (font_color_override || @theme.code_font_color || @font_color),
                size: adjusted_font_size,
                bottom_gutter: @bottom_gutters[-1][node],
                extensions: extensions.empty? ? nil : extensions
            end
          end
        end
        node.remove_attr 'unbreakable-option' if toggle_breakable
        # TODO: add protection against the bottom caption being widowed
        ink_caption node, category: :code, end: :bottom if caption_below
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      alias convert_listing convert_code
      alias convert_literal convert_code
      alias convert_listing_or_literal convert_code

      def convert_collapsible node
        id = node.id
        title = (collapsible_marker = %(\u25bc )) + (node.title? ? node.title : 'Details')
        indent_by = theme_font(:caption) { rendered_width_of_string collapsible_marker }
        if !at_page_top? && (id || (node.option? 'unbreakable'))
          arrange_block node do
            add_dest_for_block node if id
            tare_first_page_content_stream { ink_caption title }
            indent(indent_by) { traverse node }
          end
        else
          add_dest_for_block node if id
          tare_first_page_content_stream { ink_caption title }
          indent(indent_by) { traverse node }
        end
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      def convert_example node
        return convert_collapsible node if node.option? 'collapsible'
        caption_bottom = @theme.example_caption_end&.to_sym == :bottom
        arrange_block node do |extent|
          add_dest_for_block node if node.id
          tare_first_page_content_stream do
            theme_fill_and_stroke_block :example, extent, caption_node: caption_bottom ? nil : node
          end
          pad_box @theme.example_padding, node do
            theme_font :example do
              traverse node
            end
          end
        end
        # TODO: add protection against the bottom caption being widowed
        ink_caption node, category: :example, end: :bottom if caption_bottom
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      def convert_open node
        return convert_abstract node if node.style == 'abstract'
        id = node.id
        has_title = node.title?
        if !at_page_top? && (has_title || id || (node.option? 'unbreakable'))
          arrange_block node do
            add_dest_for_block node if id
            tare_first_page_content_stream { ink_caption node, category: (node.style === 'table-container' ? :table : nil), labeled: false } if has_title
            traverse node
          end
        else
          add_dest_for_block node if id
          ink_caption node, labeled: false if has_title
          traverse node
        end
      end

      def convert_quote_or_verse node
        category = node.context == :quote ? :quote : :verse
        # NOTE: b_width and b_left_width are mutually exclusive
        if (b_left_width = @theme[%(#{category}_border_left_width)]) && b_left_width > 0
          b_left_width = nil unless (b_color = resolve_theme_color %(#{category}_border_color), @theme.base_border_color, nil)
        else
          b_left_width = nil
          b_width = nil if (b_width = @theme[%(#{category}_border_width)]) == 0
        end
        if (attribution = node.attr 'attribution')
          # NOTE: temporary workaround to allow bare & to be used without having to wrap value in single quotes
          attribution = escape_amp attribution if attribution.include? '&'
          if (citetitle = node.attr 'citetitle')&.include? '&'
            citetitle = escape_amp citetitle
          end
        end
        arrange_block node do |extent|
          add_dest_for_block node if node.id
          tare_first_page_content_stream do
            theme_fill_and_stroke_block category, extent, border_width: b_width, caption_node: node
          end
          if extent && b_left_width
            float do
              extent.each_page do |first_page, last_page|
                advance_page unless first_page
                b_height = start_cursor = cursor
                b_height -= last_page.cursor if last_page
                bounding_box [bounds.left, start_cursor], width: bounds.width, height: b_height do
                  stroke_vertical_rule b_color, line_width: b_left_width, at: b_left_width * 0.5
                end
              end
            end
          end
          pad_box @theme[%(#{category}_padding)], (attribution ? nil : node) do
            theme_font category do
              if category == :quote
                traverse node
              else # :verse
                content = guard_indentation node.content
                ink_prose content,
                  normalize: false,
                  align: (resolve_text_align_from_role node.roles) || :left,
                  hyphenate: true,
                  margin_bottom: 0,
                  bottom_gutter: (attribution ? nil : @bottom_gutters[-1][node])
              end
            end
            if attribution
              theme_margin :block, :bottom
              theme_font %(#{category}_cite) do
                attribution_parts = citetitle ? [attribution, citetitle] : [attribution]
                ink_prose %(#{EmDash} #{attribution_parts.join ', '}), align: :left, normalize: false, margin_bottom: 0
              end
            end
          end
        end
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      alias convert_quote convert_quote_or_verse
      alias convert_verse convert_quote_or_verse

      def convert_sidebar node
        arrange_block node do |extent|
          add_dest_for_block node if node.id
          theme_fill_and_stroke_block :sidebar, extent if extent
          pad_box @theme.sidebar_padding, node do
            tare_first_page_content_stream do
              theme_font :sidebar_title do
                # QUESTION: should we allow margins of sidebar title to be customized?
                ink_prose node.title, align: (@theme.sidebar_title_text_align || @theme.heading_text_align || @base_text_align).to_sym, margin_bottom: @theme.heading_margin_bottom, line_height: (@theme.heading_line_height || @theme.base_line_height)
              end
            end if node.title?
            theme_font :sidebar do
              traverse node
            end
          end
        end
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      def convert_colist node
        if !at_page_top? && ((prev_context = node.previous_sibling&.context) == :listing || prev_context == :literal)
          margin_top @theme.callout_list_margin_top_after_code
        end
        add_dest_for_block node if node.id
        @list_numerals << 1
        last_item = node.items[-1]
        item_spacing = @theme.callout_list_item_spacing || @theme.list_item_spacing
        item_opts = { margin_bottom: item_spacing, normalize_line_height: true }
        if (item_text_align = (resolve_text_align_from_role node.roles) || @theme.list_text_align&.to_sym)
          item_opts[:align] = item_text_align
        end
        theme_font :callout_list do
          line_metrics = theme_font(:conum) { calc_line_metrics @base_line_height }
          node.items.each do |item|
            allocate_space_for_list_item line_metrics
            item_opts[:margin_bottom] = 0 if item == last_item
            convert_colist_item item, item_opts
          end
        end
        @list_numerals.pop
        theme_margin :prose, :bottom, (next_enclosed_block node)
      end

      def convert_colist_item node, opts
        marker_width = nil
        @list_numerals << (index = @list_numerals.pop).next
        theme_font :conum do
          marker_width = rendered_width_of_string %(#{marker = conum_glyph index}x)
          marker_font_color = @theme.callout_list_marker_font_color || @font_color
          float do
            bounding_box [bounds.left, cursor], width: marker_width do
              ink_prose marker, align: :center, inline_format: false, margin: 0, color: marker_font_color
            end
          end
        end

        indent marker_width do
          traverse_list_item node, :colist, opts
        end
      end

      def convert_dlist node
        add_dest_for_block node if node.id

        case (style = node.style)
        when 'unordered', 'ordered'
          if style == 'unordered'
            list_style = :ulist
            (markers = @list_bullets) << :disc
          else
            list_style = :olist
            (markers = @list_numerals) << 1
          end
          list = List.new node.parent, list_style
          stack_subject = node.has_role? 'stack'
          subject_stop = node.attr 'subject-stop', (stack_subject ? nil : ':')
          node.items.each do |subjects, dd|
            subject = (Array subjects).first.text
            if dd
              list_item_text = %(+++<strong>#{subject}#{(StopPunctRx.match? sanitize subject) ? '' : subject_stop}</strong>#{dd.text? ? "#{stack_subject ? '<br>' : ' '}#{dd.text}" : ''}+++)
              list_item = ListItem.new list, list_item_text
              dd.blocks.each {|it| list_item << it } if dd.blocks?
            else
              list_item = ListItem.new list, %(+++<strong>#{subject}</strong>+++)
            end
            list << list_item
          end
          convert_list list
          markers.pop
        when 'horizontal'
          table_data = []
          term_padding = term_padding_no_blocks = term_font_color = term_transform = desc_padding = term_line_metrics = term_inline_format = term_kerning = nil
          max_term_width = 0
          theme_font :description_list_term do
            term_font_color = @font_color
            term_transform = @text_transform
            term_inline_format = (term_font_styles = font_styles).empty? ? true : [inherited: { styles: term_font_styles }]
            term_line_metrics = calc_line_metrics @base_line_height
            term_padding_no_blocks = [term_line_metrics.padding_top, 10, term_line_metrics.padding_bottom, 10]
            (term_padding = (term_padding_no_blocks.drop 0))[2] += @theme.prose_margin_bottom * 0.5
            desc_padding = [0, 10, 0, 10]
            term_kerning = default_kerning?
          end
          actual_node, node = node, node.dup
          (node.instance_variable_set :@blocks, node.items.map(&:dup)).each do |item|
            terms, desc = item
            term_text = terms.map(&:text).join ?\n
            term_text = transform_text term_text, term_transform if term_transform
            if (term_width = width_of term_text, inline_format: term_inline_format, kerning: term_kerning) > max_term_width
              max_term_width = term_width
            end
            row_data = [{
              text_color: term_font_color,
              kerning: term_kerning,
              content: term_text,
              inline_format: term_inline_format,
              padding: desc&.blocks? ? term_padding : term_padding_no_blocks,
              leading: term_line_metrics.leading,
              # FIXME: prawn-table doesn't have support for final_gap option
              #final_gap: term_line_metrics.final_gap,
              valign: :top,
            }]
            if desc
              desc_container = Block.new node, :open
              desc_container << (Block.new desc_container, :paragraph, source: (desc.instance_variable_get :@text), subs: :default) if desc.text?
              desc.blocks.each {|b| desc_container << b.dup } if desc.blocks?
              row_data << { content: (::Prawn::Table::Cell::AsciiDoc.new self, content: (item[1] = desc_container), text_color: @font_color, padding: desc_padding, valign: :top, source_location: desc.source_location) }
            else
              row_data << {}
            end
            table_data << row_data
          end
          max_term_width += (term_padding[1] + term_padding[3])
          term_column_width = [max_term_width, bounds.width * 0.5].min
          table table_data, position: :left, column_widths: [term_column_width] do
            cells.style border_width: 0
            @pdf.ink_table_caption node if node.title?
          end
          theme_margin :prose, :bottom, (next_enclosed_block actual_node) #unless actual_node.nested?
        when 'qanda'
          @list_numerals << 1
          convert_list node
          @list_numerals.pop
        else
          # TODO: check if we're within one line of the bottom of the page
          # and advance to the next page if so (similar to logic for section titles)
          ink_caption node, category: :description_list, labeled: false if node.title?

          term_spacing = @theme.description_list_term_spacing
          term_height = theme_font(:description_list_term) { height_of_typeset_text 'A' }
          prose_height = height_of_typeset_text 'A'
          node.items.each do |terms, desc|
            advance_page if !at_page_top? && cursor < (nlines = terms.size + (desc && desc.text? ? 1 : 0)) * term_height + (nlines - 1) * term_spacing + (desc && !desc.text? && desc.blocks? ? term_spacing + prose_height : 0)
            theme_font :description_list_term do
              if (term_font_styles = font_styles).empty?
                term_font_styles = nil
              end
              terms.each_with_index do |term, idx|
                # QUESTION: should we pass down styles in other calls to ink_prose
                ink_prose term.text, margin_top: (idx > 0 ? term_spacing : 0), margin_bottom: 0, align: :left, normalize_line_height: true, styles: term_font_styles
              end
            end
            indent @theme.description_list_description_indent do
              #margin_bottom (desc.simple? ? @theme.list_item_spacing : term_spacing)
              margin_bottom term_spacing
              traverse_list_item desc, :dlist_desc, normalize_line_height: true, margin_bottom: ((next_enclosed_block desc, descend: true) ? nil : 0)
            end if desc
          end
          theme_margin :prose, :bottom, (next_enclosed_block node) unless node.nested?
        end
      end

      def convert_olist node
        add_dest_for_block node if node.id
        # TODO: move list_numeral resolve to a method
        case node.style
        when 'decimal'
          list_numeral = 1
        when 'loweralpha'
          list_numeral = 'a'
        when 'upperalpha'
          list_numeral = 'A'
        when 'lowerroman'
          list_numeral = RomanNumeral.new 'i', :lower
        when 'upperroman'
          list_numeral = RomanNumeral.new 'I', :upper
        when 'lowergreek'
          list_numeral = LowercaseGreekA
        when 'unstyled', 'unnumbered', 'no-bullet'
          list_numeral = nil
        when 'none'
          list_numeral = ''
        else # rubocop:disable Lint/DuplicateBranch
          list_numeral = 1
        end
        if !list_numeral.nil_or_empty? && (start = (node.attr 'start') || ((node.option? 'reversed') ? node.items.size : nil))
          if (start = start.to_i) > 1
            (start - 1).times { list_numeral = list_numeral.next }
          elsif start < 1 && !(::String === list_numeral)
            (start - 1).abs.times { list_numeral = list_numeral.pred }
          end
        end
        @list_numerals << list_numeral
        convert_list node
        @list_numerals.pop
      end

      def convert_ulist node
        add_dest_for_block node if node.id
        # TODO: move bullet_type to method on List (or helper method)
        if node.option? 'checklist'
          @list_bullets << :checkbox
        else
          if (style = node.style)
            case style
            when 'bibliography'
              bullet_type = :square
            when 'unstyled', 'no-bullet'
              bullet_type = nil
            else
              if Bullets.key? (candidate = style.to_sym)
                bullet_type = candidate
              else
                log :warn, %(unknown unordered list style: #{candidate})
                bullet_type = :disc
              end
            end
          else
            case node.list_level
            when 1
              bullet_type = :disc
            when 2
              bullet_type = :circle
            else
              bullet_type = :square
            end
          end
          @list_bullets << bullet_type
        end
        convert_list node
        @list_bullets.pop
      end

      def convert_list node
        # TODO: check if we're within one line of the bottom of the page
        # and advance to the next page if so (similar to logic for section titles)
        ink_caption node, category: :list, labeled: false if node.title?

        opts = {}
        if (text_align = resolve_text_align_from_role node.roles)
          opts[:align] = text_align
        elsif node.style == 'bibliography'
          opts[:align] = :left
        elsif (text_align = @theme.list_text_align&.to_sym) # rubocop:disable Lint/DuplicateBranch
          # NOTE: theme setting only affects alignment of list text (not nested blocks)
          opts[:align] = text_align
        end

        line_metrics = calc_line_metrics @base_line_height
        #complex = false
        # ...or if we want to give all items in the list the same treatment
        #complex = node.items.any(&:compound?)
        if (node.context == :ulist && !@list_bullets[-1]) || (node.context == :olist && !@list_numerals[-1])
          if node.style == 'unstyled'
            # unstyled takes away all indentation
            list_indent = 0
          elsif (list_indent = @theme.list_indent) > 0
            # no-bullet aligns text with left-hand side of bullet position (as though there's no bullet)
            list_indent = [list_indent - (rendered_width_of_string %(#{node.context == :ulist ? ?\u2022 : '1.'}x)), 0].max
          end
        else
          list_indent = @theme.list_indent
        end
        indent list_indent do
          node.items.each do |item|
            allocate_space_for_list_item line_metrics
            convert_list_item item, node, opts
          end
        end
        theme_margin :prose, :bottom, (next_enclosed_block node) unless node.nested?
      end

      def convert_list_item node, list, opts = {}
        # TODO: move this to a draw_bullet (or draw_marker) method
        marker_style = {}
        marker_style[:font_color] = @theme.list_marker_font_color || @font_color
        marker_style[:font_family] = font_family
        marker_style[:font_size] = font_size
        marker_style[:line_height] = @base_line_height
        case (list_type = list.context)
        when :dlist
          # NOTE: list.style is always 'qanda'
          junction = node[1]
          @list_numerals << (index = @list_numerals.pop).next
          marker = %(#{index}.)
        when :olist
          junction = node
          if (index = @list_numerals.pop)
            if index == ''
              marker = ''
            else
              marker = node.parent.style == 'decimal' && index.abs < 10 ? %(#{index < 0 ? '-' : ''}0#{index.abs}.) : %(#{index}.)
              dir = (node.parent.option? 'reversed') ? :pred : :next
              @list_numerals << (index.public_send dir)
              [:font_color, :font_family, :font_size, :font_style, :line_height].each do |prop|
                marker_style[prop] = @theme[%(olist_marker_#{prop})] || marker_style[prop]
              end
            end
          end
        else # :ulist
          junction = node
          if (marker_type = @list_bullets[-1])
            if marker_type == :checkbox
              # QUESTION: should we remove marker indent if not a checkbox?
              if node.attr? 'checkbox'
                marker_type = (node.attr? 'checked') ? :checked : :unchecked
                marker = @theme[%(ulist_marker_#{marker_type}_content)] || BallotBox[marker_type]
              end
            else
              marker = @theme[%(ulist_marker_#{marker_type}_content)] || Bullets[marker_type]
            end
            [:font_color, :font_family, :font_size, :font_style, :line_height].each do |prop|
              marker_style[prop] = @theme[%(ulist_marker_#{marker_type}_#{prop})] || @theme[%(ulist_marker_#{prop})] || marker_style[prop]
            end if marker
          end
        end

        if marker
          if marker_style[:font_family] == 'fa'
            log :info, 'deprecated fa icon set found in theme; use fas, far, or fab instead'
            marker_style[:font_family] = FontAwesomeIconSets.find {|candidate| (icon_font_data candidate).yaml[candidate].value? marker } || 'fas'
          end
          marker_style[:font_style] &&= marker_style[:font_style].to_sym
          marker_gap = rendered_width_of_char 'x'
          font marker_style[:font_family], size: marker_style[:font_size], style: marker_style[:font_style] do
            marker_width = rendered_width_of_string marker
            # NOTE: compensate if character_spacing is not applied to first character
            # see https://github.com/prawnpdf/prawn/commit/c61c5d48841910aa11b9e3d6f0e01b68ce435329
            character_spacing_correction = 0
            character_spacing(-0.5) do
              character_spacing_correction = 0.5 if (rendered_width_of_char 'x', character_spacing: -0.5) == marker_gap
            end
            marker_height = height_of_typeset_text marker, line_height: marker_style[:line_height], single_line: true
            start_position = bounds.left - marker_width - marker_gap + character_spacing_correction
            float do
              advance_page if @media == 'prepress' && cursor < marker_height
              flow_bounding_box position: start_position, width: marker_width do
                ink_prose marker,
                  align: :right,
                  character_spacing: -0.5,
                  color: marker_style[:font_color],
                  inline_format: false,
                  line_height: marker_style[:line_height],
                  style: marker_style[:font_style],
                  margin: 0,
                  normalize: false,
                  single_line: true
              end
            end
          end
        end

        opts = opts.merge margin_bottom: 0, normalize_line_height: true
        if junction
          if junction.compound?
            opts.delete :margin_bottom
          elsif next_enclosed_block junction, descend: true
            opts[:margin_bottom] = @theme.list_item_spacing
          end
        end
        traverse_list_item node, list_type, opts
      end

      def convert_image node, opts = {}
        target, image_format = (node.extend ::Asciidoctor::Image).target_and_format

        unless image_format == 'pdf'
          if (float_to = node.attr 'float') && ((BlockFloatNames.include? float_to) ? float_to : (float_to = nil))
            alignment = float_to.to_sym
          elsif (alignment = node.attr 'align')
            alignment = (BlockAlignmentNames.include? alignment) ? alignment.to_sym : :left
          elsif !(alignment = node.roles.reverse.find {|role| BlockAlignmentNames.include? role }&.to_sym)
            alignment = @theme.image_align&.to_sym || :left
          end
        end

        if image_format == 'gif' && !(defined? ::GMagick::Image)
          log :warn, %(GIF image format not supported. Install the prawn-gmagick gem or convert #{target} to PNG.)
          image_path = nil
        elsif ::Asciidoctor::Image::Base64Encoded === target
          image_path = target
        elsif (image_path = resolve_image_path node, target, image_format, (opts.fetch :relative_to_imagesdir, true))
          if image_format == 'pdf'
            if ::File.readable? image_path
              if (replace = page.empty?) && ((parent = node.parent).attr? 'pdf-page-start', page_number) && (parent.attr? 'pdf-anchor')
                replace_parent = parent
              end
              if (id = node.id) || replace_parent
                add_dest_block = proc do
                  node_dest = dest_top
                  if id
                    node.set_attr 'pdf-destination', node_dest
                    add_dest id, node_dest
                  end
                  if replace_parent
                    replace_parent.set_attr 'pdf-destination', node_dest
                    add_dest (replace_parent.attr 'pdf-anchor'), node_dest
                  end
                end
              end
              # NOTE: import_page automatically advances to next page afterwards
              if (pgnums = node.attr 'pages')
                (resolve_pagenums pgnums).each_with_index do |pgnum, idx|
                  if idx == 0
                    import_page image_path, page: pgnum, replace: replace, &add_dest_block
                  else
                    import_page image_path, page: pgnum, replace: true
                  end
                end
              else
                import_page image_path, page: [(node.attr 'page', nil, 1).to_i, 1].max, replace: replace, &add_dest_block
              end
              return
            else
              log :warn, %(pdf to insert not found or not readable: #{image_path})
              image_path = nil
            end
          elsif !(::File.readable? image_path)
            log :warn, %(image to embed not found or not readable: #{image_path})
            image_path = nil
          end
        end

        return on_image_error :missing, node, target, (opts.merge align: alignment) unless image_path

        # TODO: support cover (aka canvas) image layout using "canvas" (or "cover") role
        case (width = resolve_explicit_width node.attributes, bounds_width: (available_w = bounds.width), support_vw: true, use_fallback: true, constrain_to_bounds: true)
        when ViewportWidth
          # TODO: add `to_pt page_width` method to ViewportWidth type
          width = page_width * (width.to_f / 100)
        when ImageWidth
          scale = width.to_f / 100
          width = nil
        end

        caption_end = @theme.image_caption_end&.to_sym || :bottom
        caption_max_width = @theme.image_caption_max_width
        caption_max_width = 'fit-content' if float_to && !(caption_max_width&.start_with? 'fit-content')
        # NOTE: if width is not set explicitly and max-width is fit-content, caption height may not be accurate
        caption_h = node.title? ? (ink_caption node, category: :image, end: caption_end, block_align: alignment, block_width: width, max_width: caption_max_width, dry_run: true, force_top_margin: caption_end == :bottom) : 0

        align_to_page = node.option? 'align-to-page'
        pinned = opts[:pinned]

        begin
          rendered_h = rendered_w = nil
          span_page_width_if align_to_page do
            if image_format == 'svg'
              if ::Asciidoctor::Image::Base64Encoded === image_path
                svg_data = image_path.unpack1 'm'
                file_request_root = false
              else
                svg_data = ::File.read image_path, mode: 'r:UTF-8'
                file_request_root = { base: (::File.dirname image_path), root: @jail_dir }
              end
              svg_obj = ::Prawn::SVG::Interface.new svg_data, self,
                width: width,
                fallback_font_name: fallback_svg_font_name,
                enable_web_requests: allow_uri_read ? (method :load_open_uri).to_proc : false,
                enable_file_requests_with_root: file_request_root,
                cache_images: cache_uri
              rendered_w = (svg_size = svg_obj.document.sizing).output_width
              if scale
                svg_size = svg_obj.resize width: (rendered_w = [available_w, rendered_w * scale].min)
              elsif !width && (svg_obj.document.root.attributes.key? 'width') && rendered_w > available_w
                # NOTE: restrict width to available width (prawn-svg already coerces to pixels)
                svg_size = svg_obj.resize width: (rendered_w = available_w)
              end
              # NOTE: shrink image so it fits within available space; group image & caption
              if (rendered_h = svg_size.output_height) > (available_h = cursor - caption_h)
                unless pinned || at_page_top? || (node.first_child? && (node.parent.attr? 'pdf-at-top'))
                  advance_page
                  available_h = cursor - caption_h
                end
                rendered_w = (svg_obj.resize height: (rendered_h = available_h)).output_width if rendered_h > available_h
              end
              add_dest_for_block node if node.id
              ink_caption node, category: :image, end: :top, block_align: alignment, block_width: rendered_w, max_width: caption_max_width if caption_end == :top && node.title?
              image_y = y
              left = bounds.left
              # NOTE: prawn-svg does not compute :at for alignment correctly in column box, so resort to our own logic
              case alignment
              when :center
                left += (available_w - rendered_w) * 0.5
              when :right
                left += available_w - rendered_w
              end
              svg_obj.options[:at] = [left, (image_cursor = cursor)]
              svg_obj.draw # NOTE: cursor advances automatically
              svg_obj.document.warnings.each do |img_warning|
                log :warn, %(problem encountered in image: #{image_path}; #{img_warning})
              end unless scratch?
              draw_image_border image_cursor, rendered_w, rendered_h, alignment unless pinned || (node.role? && (node.has_role? 'noborder'))
              if (link = node.attr 'link')
                add_link_to_image link, { width: rendered_w, height: rendered_h }, position: alignment, y: image_y
              end
            else
              # FIXME: this code really needs to be better organized!
              # NOTE: use low-level API to access intrinsic dimensions; build_image_object caches image data previously loaded
              image_obj, image_info = ::Asciidoctor::Image::Base64Encoded === image_path ?
                  ::StringIO.open((image_path.unpack1 'm'), 'rb') {|fd| build_image_object fd } :
                  ::File.open(image_path, 'rb') {|fd| build_image_object fd }
              actual_w = to_pt image_info.width, :px
              width = actual_w * scale if scale
              # NOTE: if width is not specified, scale native width & height from px to pt and restrict width to available width
              rendered_w, rendered_h = image_info.calc_image_dimensions width: (width || [available_w, actual_w].min)
              # NOTE: shrink image so it fits within available space; group image & caption
              if rendered_h > (available_h = cursor - caption_h)
                unless pinned || at_page_top? || (node.first_child? && (node.parent.attr? 'pdf-at-top'))
                  advance_page
                  available_h = cursor - caption_h
                end
                rendered_w = (image_info.calc_image_dimensions height: (rendered_h = available_h))[0] if rendered_h > available_h
              end
              add_dest_for_block node if node.id
              ink_caption node, category: :image, end: :top, block_align: alignment, block_width: rendered_w, max_width: caption_max_width if caption_end == :top && node.title?
              image_y = y
              left = bounds.left
              # NOTE: prawn does not compute :at for alignment correctly in column box, so resort to our own logic
              case alignment
              when :center
                left += (available_w - rendered_w) * 0.5
              when :right
                left += available_w - rendered_w
              end
              # NOTE: specify both width and height to avoid recalculation
              embed_image image_obj, image_info, at: [left, (image_cursor = cursor)], height: rendered_h, width: rendered_w
              draw_image_border image_cursor, rendered_w, rendered_h, alignment unless pinned || (node.role? && (node.has_role? 'noborder'))
              if (link = node.attr 'link')
                add_link_to_image link, { width: rendered_w, height: rendered_h }, position: alignment, y: image_y
              end
              # NOTE: Asciidoctor disables automatic advancement of cursor for raster images, so move cursor manually
              move_down rendered_h if y == image_y
            end
          end
          ink_caption node, category: :image, end: :bottom, block_align: alignment, block_width: rendered_w, max_width: caption_max_width if caption_end == :bottom && node.title?
          if !pinned && (block_next = next_enclosed_block node)
            if float_to && (supports_float_wrapping? block_next) && rendered_w < bounds.width
              init_float_box node, rendered_w, rendered_h + caption_h, float_to
            else
              theme_margin :block, :bottom, block_next
            end
          end
        rescue => e
          raise if ::StopIteration === e
          on_image_error :exception, node, target, (opts.merge align: alignment, message: %(could not embed image: #{image_path}; #{e.message}#{(recommend_prawn_gmagick? e, image_format) ? %(; install prawn-gmagick gem to add support for #{image_format&.upcase || 'unknown'} image format) : ''}))
        end
      end

      def convert_audio node
        add_dest_for_block node if node.id
        audio_path = node.media_uri node.attr 'target'
        play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
        ink_prose %(#{play_symbol}#{NoBreakSpace}<a href="#{audio_path}">#{audio_path}</a> <em>(audio)</em>), normalize: false, margin: 0
        ink_caption node, labeled: false, end: :bottom if node.title?
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      def convert_video node
        case (poster = node.attr 'poster')
        when 'youtube'
          video_path = %(https://www.youtube.com/watch?v=#{video_id = node.attr 'target'})
          # see http://stackoverflow.com/questions/2068344/how-do-i-get-a-youtube-video-thumbnail-from-the-youtube-api
          poster = allow_uri_read ? %(https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg) : nil
          type = 'YouTube video'
        when 'vimeo'
          video_path = %(https://vimeo.com/#{video_id = node.attr 'target'})
          if allow_uri_read
            poster = load_open_uri.open_uri(%(https://vimeo.com/api/oembed.xml?url=https%3A//vimeo.com/#{video_id}&width=1280), 'r') {|f| (VimeoThumbnailRx.match f.read)[1] } rescue nil
          else
            poster = nil
          end
          type = 'Vimeo video'
        else
          video_path = node.media_uri node.attr 'target'
          type = 'video'
        end

        if poster.nil_or_empty?
          add_dest_for_block node if node.id
          play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
          ink_prose %(#{play_symbol}#{NoBreakSpace}<a href="#{video_path}">#{video_path}</a> <em>(#{type})</em>), normalize: false, margin: 0
          ink_caption node, labeled: false, end: :bottom if node.title?
          theme_margin :block, :bottom, (next_enclosed_block node)
        else
          original_attributes = node.attributes.merge
          begin
            node.update_attributes 'target' => poster, 'link' => video_path
            convert_image node
          ensure
            node.attributes.replace original_attributes
          end
        end
      end

      # NOTE: to insert sequential page breaks, you must put {nbsp} between page breaks
      def convert_page_break node
        if (page_layout = node.attr 'page-layout').nil_or_empty?
          unless node.role? && (page_layout = (node.roles.map(&:to_sym) & PageLayouts)[-1])
            page_layout = nil
          end
        elsif !(PageLayouts.include? (page_layout = page_layout.to_sym))
          page_layout = nil
        end

        if at_page_top? && !(node.option? 'always')
          if page_layout && page_layout != page.layout && page.empty?
            delete_current_page
            advance_page layout: page_layout, margin: @page_margin[page_layout][page_side nil, @folio_placement[:inverted]]
          end
        elsif page_layout
          bounds.current_column = bounds.last_column if ColumnBox === bounds && !(node.has_role? 'column')
          advance_page layout: page_layout, margin: @page_margin[page_layout][page_side nil, @folio_placement[:inverted]]
        else
          bounds.current_column = bounds.last_column if ColumnBox === bounds && !(node.has_role? 'column')
          advance_page
        end
      end

      def convert_pass node
        theme_font :code do
          typeset_formatted_text [text: (guard_indentation node.content), color: @theme.base_font_color], (calc_line_metrics @base_line_height)
        end
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      def convert_stem node
        arrange_block node do |extent|
          add_dest_for_block node if node.id
          tare_first_page_content_stream { theme_fill_and_stroke_block :code, extent, caption_node: node }
          pad_box @theme.code_padding, node do
            theme_font :code do
              typeset_formatted_text [text: (guard_indentation node.content), color: @font_color],
                (calc_line_metrics @base_line_height),
                bottom_gutter: @bottom_gutters[-1][node]
            end
          end
        end
        theme_margin :block, :bottom, (next_enclosed_block node)
      end

      def convert_table node
        caption_end = (theme = @theme).table_caption_end&.to_sym || :top
        if !at_page_top? && ((unbreakable = node.option? 'unbreakable') || ((node.option? 'breakable') && (node.id || node.title?)))
          # NOTE: we use the current node as the parent so we can navigate back into the document model
          (table_container = Block.new node, :open) << (table_dup = node.dup)
          # NOTE: we need to duplicate the attributes so that the unbreakable/breakable option is preserved on subsequent conversions
          table_dup.instance_variable_set :@attributes, node.attributes.dup
          if unbreakable
            table_dup.remove_attr 'unbreakable-option'
            table_container.set_attr 'unbreakable-option'
          else
            table_dup.remove_attr 'breakable-option'
          end
          table_container.style = 'table-container'
          table_container.id, table_dup.id = table_dup.id, nil
          if caption_end == :top && table_dup.title?
            table_container.title = ''
            table_container.instance_variable_set :@converted_title, table_dup.captioned_title
            table_dup.title = nil
          end
          return convert_open table_container
        end
        add_dest_for_block node if node.id
        # TODO: we could skip a lot of the logic below when num_rows == 0
        num_rows = node.attr 'rowcount'
        num_cols = node.columns.size
        table_header_size = false
        prev_font_scale, @font_scale = @font_scale, 1 if node.document.nested?

        tbl_bg_color = resolve_theme_color :table_background_color
        # QUESTION: should we fallback to page background color? (which is never transparent)
        #tbl_bg_color = resolve_theme_color :table_background_color, @page_bg_color
        # ...and if so, should we try to be helpful and use @page_bg_color for tables nested in blocks?
        #unless tbl_bg_color
        #  tbl_bg_color = @page_bg_color unless [:section, :document].include? node.parent.context
        #end

        # NOTE: emulate table bg color by using it as a fallback value for each element
        head_bg_color = resolve_theme_color :table_head_background_color, tbl_bg_color
        foot_bg_color = resolve_theme_color :table_foot_background_color, tbl_bg_color
        body_bg_color = resolve_theme_color :table_body_background_color, tbl_bg_color
        body_stripe_bg_color = resolve_theme_color :table_body_stripe_background_color, tbl_bg_color

        base_header_cell_data = nil
        header_cell_line_metrics = nil
        body_cell_padding = expand_padding_value theme.table_cell_padding

        table_data = []
        theme_font :table do
          head_rows = node.rows[:head]
          body_rows = node.rows[:body]
          #if (hrows = node.attr 'hrows') && (shift_rows = hrows.to_i - head_rows.size) > 0
          #  head_rows = head_rows.drop 0
          #  body_rows = body_rows.drop 0
          #  shift_rows.times { head_rows << body_rows.shift unless body_rows.empty? }
          #end
          theme_font :table_head do
            table_header_size = head_rows.size
            head_font_info = font_info
            head_line_metrics = calc_line_metrics theme.table_head_line_height || theme.table_cell_line_height || @base_line_height
            head_cell_padding = (theme.table_head_cell_padding ? (expand_padding_value theme.table_head_cell_padding) : body_cell_padding).drop 0
            head_cell_padding[0] += head_line_metrics.padding_top
            head_cell_padding[2] += head_line_metrics.padding_bottom
            # QUESTION: why doesn't text transform inherit from table?
            head_transform = resolve_text_transform :table_head_text_transform, nil
            base_cell_data = {
              inline_format: [normalize: true],
              background_color: head_bg_color,
              text_color: @font_color,
              size: head_font_info[:size],
              font: head_font_info[:family],
              font_style: head_font_info[:style],
              kerning: default_kerning?,
              padding: head_cell_padding,
              leading: head_line_metrics.leading,
              # TODO: patch prawn-table to pass through final_gap option
              #final_gap: head_line_metrics.final_gap,
            }
            head_rows.each do |row|
              table_data << (row.map do |cell|
                cell_text = head_transform ? (transform_text cell.text.strip, head_transform) : cell.text.strip
                cell_text = hyphenate_text cell_text, @hyphenator if defined? @hyphenator
                base_cell_data.merge \
                  content: cell_text,
                  colspan: cell.colspan || 1,
                  align: (cell.attr 'halign').to_sym,
                  valign: (val = cell.attr 'valign') == 'middle' ? :center : val.to_sym,
                  source_location: cell.source_location
              end)
            end
          end unless head_rows.empty?

          base_cell_data = {
            font: (body_font_info = font_info)[:family],
            font_style: body_font_info[:style],
            size: body_font_info[:size],
            kerning: default_kerning?,
            text_color: @font_color,
          }
          body_cell_line_metrics = calc_line_metrics (theme.table_cell_line_height || @base_line_height)
          (body_rows + node.rows[:foot]).each do |row|
            table_data << (row.map do |cell|
              cell_data = base_cell_data.merge \
                colspan: cell.colspan || 1,
                rowspan: cell.rowspan || 1,
                align: (cell.attr 'halign').to_sym,
                valign: (val = cell.attr 'valign') == 'middle' ? :center : val.to_sym,
                source_location: cell.source_location
              cell_line_metrics = body_cell_line_metrics
              case cell.style
              when :emphasis
                cell_data[:font_style] = :italic
              when :strong
                cell_data[:font_style] = :bold
              when :header
                unless base_header_cell_data
                  theme_font_cascade [:table_head, :table_header_cell] do
                    header_cell_font_info = font_info
                    base_header_cell_data = {
                      text_color: @font_color,
                      font: header_cell_font_info[:family],
                      size: header_cell_font_info[:size],
                      font_style: header_cell_font_info[:style],
                      text_transform: @text_transform,
                    }
                    header_cell_line_metrics = calc_line_metrics @base_line_height
                  end
                  if (val = resolve_theme_color :table_header_cell_background_color, head_bg_color)
                    base_header_cell_data[:background_color] = val
                  end
                end
                cell_data.update base_header_cell_data
                cell_transform = cell_data.delete :text_transform
                cell_line_metrics = header_cell_line_metrics
              when :monospaced
                cell_data.delete :font_style
                cell_line_height = @base_line_height
                theme_font :codespan do
                  mono_cell_font_info = font_info
                  cell_data[:font] = mono_cell_font_info[:family]
                  cell_data[:size] = mono_cell_font_info[:size]
                  cell_data[:text_color] = @font_color
                  cell_line_metrics = calc_line_metrics cell_line_height
                end
              when :literal
                # NOTE: we want the raw AsciiDoc in this case
                cell_data[:content] = guard_indentation cell.instance_variable_get :@text
                # NOTE: the absence of the inline_format option implies it's disabled
                cell_data.delete :font_style
                # QUESTION: should we introduce a dedicated category?
                theme_font :code do
                  literal_cell_font_info = font_info
                  cell_data[:font] = literal_cell_font_info[:family]
                  cell_data[:size] = literal_cell_font_info[:size] * (cell_data[:size].to_f / @root_font_size)
                  cell_data[:text_color] = @font_color
                  cell_line_metrics = calc_line_metrics @base_line_height
                end
              when :asciidoc
                cell_data.delete :kerning
                if theme.table_asciidoc_cell_style == 'initial'
                  cell_data.delete :font
                  cell_data.delete :font_style
                  cell_data.delete :size
                  cell_data.delete :text_color
                end
                # NOTE: line metrics get applied when AsciiDoc content is converted
                cell_line_metrics = nil
                asciidoc_cell = ::Prawn::Table::Cell::AsciiDoc.new self, (cell_data.merge content: cell.inner_document, padding: body_cell_padding, root_font_size: @root_font_size)
                cell_data = { content: asciidoc_cell, source_location: cell.source_location }
              end
              if cell_line_metrics
                cell_padding = body_cell_padding.drop 0
                cell_padding[0] += cell_line_metrics.padding_top
                cell_padding[2] += cell_line_metrics.padding_bottom
                cell_data[:leading] = cell_line_metrics.leading
                # TODO: patch prawn-table to pass through final_gap option
                #cell_data[:final_gap] = cell_line_metrics.final_gap
                cell_data[:padding] = cell_padding
              end
              unless cell_data.key? :content
                cell_text = cell.text.strip
                cell_text = transform_text cell_text, cell_transform if cell_transform
                cell_text = hyphenate_text cell_text, @hyphenator if defined? @hyphenator
                cell_text = cell_text.gsub CjkLineBreakRx, ZeroWidthSpace if @cjk_line_breaks
                if cell_text.include? DoubleLF
                  # FIXME: hard breaks not quite the same result as separate paragraphs; need custom cell impl here
                  cell_data[:content] = (cell_text.split BlankLineRx).map {|l| l.tr_s WhitespaceChars, ' ' }.join DoubleLF
                  cell_data[:inline_format] = true
                else
                  cell_data[:content] = cell_text
                  cell_data[:inline_format] = [normalize: true]
                end
              end
              if node.document.attr? 'cellbgcolor'
                if (cell_bg_color = node.document.attr 'cellbgcolor') == 'transparent'
                  cell_data[:background_color] = body_bg_color
                elsif (cell_bg_color.start_with? '#') && (HexColorRx.match? cell_bg_color)
                  cell_data[:background_color] = cell_bg_color.slice 1, cell_bg_color.length
                end
              end
              cell_data
            end)
          end
        end

        # NOTE: Prawn crashes if table data is empty, so ensure there's at least one row
        if table_data.empty?
          log(:warn) { message_with_context 'no rows found in table', source_location: node.source_location }
          table_data << ::Array.new([node.columns.size, 1].max) { { content: '' } }
        end

        rect_side_names = [:top, :right, :bottom, :left]
        grid_axis_names = [:rows, :cols]
        border_color = (rect_side_names.zip expand_rect_values theme.table_border_color, 'transparent').to_h
        border_style = (rect_side_names.zip (expand_rect_values theme.table_border_style, :solid).map(&:to_sym)).to_h
        border_width = (rect_side_names.zip expand_rect_values theme.table_border_width, 0).to_h
        grid_color = (grid_axis_names.zip expand_grid_values (theme.table_grid_color || [border_color[:top], border_color[:left]]), 'transparent').to_h
        grid_style = (grid_axis_names.zip (expand_grid_values (theme.table_grid_style || [border_style[:top], border_style[:left]]), :solid).map(&:to_sym)).to_h
        grid_width = (grid_axis_names.zip expand_grid_values (theme.table_grid_width || [border_width[:top], border_width[:left]]), 0).to_h

        if table_header_size
          head_border_bottom_color = theme.table_head_border_bottom_color || grid_color[:rows]
          head_border_bottom_style = theme.table_head_border_bottom_style&.to_sym || grid_style[:rows]
          head_border_bottom_width = theme.table_head_border_bottom_width || (grid_width[:rows] * 2.5)
        end

        case (grid = node.attr 'grid', 'all', 'table-grid')
        when 'all'
          # keep inner borders
        when 'cols'
          grid_width[:rows] = 0
        when 'rows'
          grid_width[:cols] = 0
        else # none
          grid_width[:rows] = grid_width[:cols] = 0
        end

        case (frame = node.attr 'frame', 'all', 'table-frame')
        when 'all'
          # keep outer borders
        when 'topbot', 'ends'
          border_width[:left] = border_width[:right] = 0
        when 'sides'
          border_width[:top] = border_width[:bottom] = 0
        else # none
          border_width[:top] = border_width[:right] = border_width[:bottom] = border_width[:left] = 0
        end

        if node.option? 'autowidth'
          table_width = (node.attr? 'width') ? bounds.width * ((node.attr 'tablepcwidth') / 100.0) :
              (((node.has_role? 'stretch')) ? bounds.width : nil)
          column_widths = []
        else
          table_width = bounds.width * ((node.attr 'tablepcwidth') / 100.0)
          column_widths = node.columns.map {|col| ((col.attr 'colpcwidth') * table_width) / 100.0 }
        end

        if ((alignment = node.attr 'align') && (BlockAlignmentNames.include? alignment)) ||
            (alignment = (node.roles & BlockAlignmentNames)[-1])
          alignment = alignment.to_sym
        else
          alignment = theme.table_align&.to_sym || :left
        end

        caption_max_width = theme.table_caption_max_width || 'fit-content'

        table_settings = {
          header: table_header_size,
          # NOTE: position is handled by this method
          position: :left,
          # NOTE: the border color, style, and width of the outer frame is set in the table callback block
          width: table_width,
          column_widths: column_widths,
        }
        cell_style = { border_color: grid_color.values, border_lines: grid_style.values, border_width: grid_width.values }

        # QUESTION: should we support nth; should we support sequence of roles?
        case node.attr 'stripes', nil, 'table-stripes'
        when 'all'
          table_settings[:row_colors] = [body_stripe_bg_color]
        when 'even'
          table_settings[:row_colors] = [body_bg_color, body_stripe_bg_color]
        when 'odd'
          table_settings[:row_colors] = [body_stripe_bg_color, body_bg_color]
        else # none
          table_settings[:row_colors] = [body_bg_color]
        end

        left_padding = right_padding = nil
        table table_data, table_settings do
          instance_variable_set :@node, node
          # NOTE: cell_style must be applied manually to be compatible with both prawn-table 0.2.2 and prawn-table 0.2.3
          cells.style cell_style
          @column_widths = column_widths unless column_widths.empty?
          # NOTE: call width to capture resolved table width
          table_width = width
          @pdf.ink_table_caption node, alignment, table_width, caption_max_width if caption_end == :top && node.title?
          # NOTE: align using padding instead of bounding_box as prawn-table does
          # using a bounding_box across pages mangles the margin box of subsequent pages
          if alignment != :left && table_width != (this_bounds = @pdf.bounds).width
            if alignment == :center
              left_padding = right_padding = (this_bounds.width - width) * 0.5
              this_bounds.add_left_padding left_padding
              this_bounds.add_right_padding right_padding
            else # :right
              left_padding = this_bounds.width - width
              this_bounds.add_left_padding left_padding
            end
          end
          if grid == 'none' && frame == 'none'
            (rows table_header_size - 1).tap do |r|
              r.border_bottom_color = head_border_bottom_color
              r.border_bottom_line = head_border_bottom_style
              r.border_bottom_width = head_border_bottom_width
            end if table_header_size
          else
            # apply the grid setting first across all cells
            cells.border_width = [grid_width[:rows], grid_width[:cols], grid_width[:rows], grid_width[:cols]]

            if table_header_size
              (rows table_header_size - 1).tap do |r|
                r.border_bottom_color = head_border_bottom_color
                r.border_bottom_line = head_border_bottom_style
                r.border_bottom_width = head_border_bottom_width
              end
              (rows table_header_size).tap do |r|
                r.border_top_color = head_border_bottom_color
                r.border_top_line = head_border_bottom_style
                r.border_top_width = head_border_bottom_width
              end if num_rows > table_header_size
            end

            # top edge of table
            (rows 0).tap do |r|
              r.border_top_color, r.border_top_line, r.border_top_width = border_color[:top], border_style[:top], border_width[:top]
            end
            # right edge of table
            (columns num_cols - 1).tap do |r|
              r.border_right_color, r.border_right_line, r.border_right_width = border_color[:right], border_style[:right], border_width[:right]
            end
            # bottom edge of table
            (rows num_rows - 1).tap do |r|
              r.border_bottom_color, r.border_bottom_line, r.border_bottom_width = border_color[:bottom], border_style[:bottom], border_width[:bottom]
            end
            # left edge of table
            (columns 0).tap do |r|
              r.border_left_color, r.border_left_line, r.border_left_width = border_color[:left], border_style[:left], border_width[:left]
            end
          end

          # QUESTION: should cell padding be configurable for foot row cells?
          unless node.rows[:foot].empty?
            foot_row = row num_rows.pred
            foot_row.background_color = foot_bg_color
            # FIXME: find a way to do this when defining the cells
            foot_row.text_color = theme.table_foot_font_color if theme.table_foot_font_color
            foot_row.size = theme.table_foot_font_size if theme.table_foot_font_size
            foot_row.font = theme.table_foot_font_family if theme.table_foot_font_family
            foot_row.font_style = theme.table_foot_font_style.to_sym if theme.table_foot_font_style
            # HACK: we should do this transformation when creating the cell
            #if (foot_transform = resolve_text_transform :table_foot_text_transform, nil)
            #  foot_row.each {|c| c.content = (transform_text c.content, foot_transform) if c.content }
            #end
          end
        end
        if left_padding
          bounds.subtract_left_padding left_padding
          bounds.subtract_right_padding right_padding if right_padding
        end
        ink_table_caption node, alignment, table_width, caption_max_width, caption_end if caption_end == :bottom && node.title?
        theme_margin :block, :bottom, (next_enclosed_block node)
      rescue ::Prawn::Errors::CannotFit
        log :error, (message_with_context 'cannot fit contents of table cell into specified column width', source_location: node.source_location)
      ensure
        @font_scale = prev_font_scale if prev_font_scale
      end

      def convert_thematic_break node
        pad_box @theme.thematic_break_padding || [@theme.thematic_break_margin_top, 0] do
          if (b_color = resolve_theme_color :thematic_break_border_color)
            stroke_horizontal_rule b_color,
              line_width: @theme.thematic_break_border_width,
              line_style: (@theme.thematic_break_border_style&.to_sym || :solid)
          end
        end
        conceal_page_top { theme_margin :block, :bottom, (next_enclosed_block node) }
      end

      def convert_toc node, opts = {}
        # NOTE: only allow document to have a single managed toc
        return if @toc_extent
        is_macro = (placement = opts[:placement] || 'macro') == 'macro'
        if ((doc = node.document).attr? 'toc-placement', placement) && (doc.attr? 'toc') && !(get_entries_for_toc doc).empty?
          start_toc_page node, placement if (is_book = doc.doctype == 'book')
          add_dest_for_block node, id: (node.id || 'toc') if is_macro
          toc_extent = @toc_extent = allocate_toc doc, (doc.attr 'toclevels', 2).to_i, cursor, (title_as_page = is_book || (doc.attr? 'title-page'))
          if title_as_page
            if @theme.page_numbering_start_at == 'toc'
              @index.start_page_number = toc_extent.from.page
            elsif @theme.page_numbering_start_at == 'after-toc'
              new_start_page_number = toc_extent.to.page + 1
              new_start_page_number += 1 if @ppbook && (verso_page? new_start_page_number)
              @index.start_page_number = new_start_page_number
            end
          end
          if is_macro
            @disable_running_content[:header] += toc_extent.page_range if node.option? 'noheader'
            @disable_running_content[:footer] += toc_extent.page_range if node.option? 'nofooter'
          end
        end
        nil
      end

      def traverse node, opts = {}
        # NOTE: need to reconfigure document to use scratch converter in scratch document
        if self == (prev_converter = node.document.converter)
          prev_converter = nil
        else
          node.document.instance_variable_set :@converter, self
        end
        if node.blocks?
          node.content
        elsif node.content_model != :compound && (string = node.content)
          prose_opts = opts.merge hyphenate: true, margin_bottom: 0
          if (text_align = resolve_text_align_from_role node.roles)
            prose_opts[:align] = text_align
          end
          if (bottom_gutter = @bottom_gutters[-1][node])
            prose_opts[:bottom_gutter] = bottom_gutter
          end
          ink_prose string, prose_opts
        end
      ensure
        node.document.instance_variable_set :@converter, prev_converter if prev_converter
      end

      def traverse_list_item node, list_type, opts = {}
        if list_type == :dlist # qanda
          terms, desc = node
          terms.each {|term| ink_prose %(<em>#{term.text}</em>), (opts.merge margin_bottom: @theme.description_list_term_spacing) }
          if desc
            ink_prose desc.text, (opts.merge hyphenate: true) if desc.text?
            traverse desc
          end
        else
          if (primary_text = node.text).nil_or_empty?
            ink_prose DummyText, opts if node.empty?
          else
            ink_prose primary_text, (opts.merge hyphenate: true)
          end
          traverse node
        end
      end

      def convert_inline_anchor node
        doc = node.document
        target = node.target
        case node.type
        when :link
          anchor = node.id ? %(<a id="#{node.id}">#{DummyText}</a>) : ''
          class_attr = ''
          if (role = node.role)
            class_attr = %( class="#{role}")
          end
          if (@media ||= doc.attr 'media', 'screen') != 'screen' && (target.start_with? 'mailto:')
            if (bare_target = target.slice 7, target.length) == (text = node.text)
              role = role ? role + ' bare' : 'bare'
            end
            bare_target = target unless doc.attr? 'hide-uri-scheme'
          else
            bare_target = target
            text = node.text
          end
          if role && (role == 'bare' || ((roles = role.split).include? 'bare'))
            # QUESTION: should we insert breakable chars into URI when building fragment instead?
            text = breakable_uri text if role == 'bare' || !(roles.include? 'nobreak')
            %(#{anchor}<a href="#{target}"#{class_attr}>#{text}</a>)
          # NOTE: @media may not be initialized if method is called before convert phase
          elsif (doc.attr? 'show-link-uri') || (@media != 'screen' && (doc.attr_unspecified? 'show-link-uri'))
            # QUESTION: should we insert breakable chars into URI when building fragment instead?
            # TODO: allow style of printed link to be controlled by theme
            %(#{anchor}<a href="#{target}"#{class_attr}>#{text}</a> [<font size="0.85em">#{breakable_uri bare_target}</font>&#93;)
          else
            %(#{anchor}<a href="#{target}"#{class_attr}>#{text}</a>)
          end
        when :xref
          # NOTE: non-nil path indicates this is an inter-document xref that's not included in current document
          if (path = node.attributes['path'])
            # NOTE: we don't use local as that doesn't work on the web
            %(<a href="#{target}">#{node.text || path}</a>)
          elsif (refid = node.attributes['refid'])
            if !(text = node.text) && AbstractNode === (ref = doc.catalog[:refs][refid]) && (@resolving_xref ||= (outer = true)) && outer
              if (text = ref.xreftext node.attr 'xrefstyle', nil, true)&.include? '<a'
                text = text.gsub DropAnchorRx, ''
              end
              if ref.inline? && ref.type == :bibref && !scratch? && (@bibref_refs.add? refid)
                anchor = %(<a id="_bibref_ref_#{refid}">#{DummyText}</a>)
              end
              @resolving_xref = nil
            end
            %(#{anchor || ''}<a anchor="#{derive_anchor_from_id refid}">#{text || "[#{refid}]"}</a>).gsub ']', '&#93;'
          else
            %(<a anchor="#{doc.attr 'pdf-anchor'}">#{node.text || '[^top&#93;'}</a>)
          end
        when :ref
          # NOTE: destination is created inside callback registered by FormattedTextTransform#build_fragment
          %(<a id="#{node.id}">#{DummyText}</a>)
        when :bibref
          id = node.id
          # NOTE: technically node.text should be node.reftext, but subs have already been applied to text
          reftext = (reftext = node.reftext) ? %([#{reftext}]) : %([#{id}])
          reftext = %(<a anchor="_bibref_ref_#{id}">#{reftext}</a>) if @bibref_refs.include? id
          # NOTE: destination is created inside callback registered by FormattedTextTransform#build_fragment
          %(<a id="#{id}">#{DummyText}</a>#{reftext})
        else
          log :warn, %(unknown anchor type: #{node.type.inspect})
          nil
        end
      end

      def convert_inline_break node
        %(#{node.text}<br>)
      end

      def convert_inline_button node
        %(<button>#{((load_theme node.document).button_content || '%s').sub '%s', node.text}</button>)
      end

      def convert_inline_callout node
        result = (conum_font_family = @theme.conum_font_family) == font_name ? (conum_glyph node.text.to_i) : %(<font name="#{conum_font_family}">#{conum_glyph node.text.to_i}</font>)
        if (conum_font_color = @theme.conum_font_color)
          # NOTE: CMYK value gets flattened here, but is restored by formatted text parser
          result = %(<font color="#{conum_font_color}">#{result}</font>)
        end
        result
      end

      def convert_inline_footnote node
        if (index = node.attr 'index') && (fn = node.document.footnotes.find {|candidate| candidate.index == index })
          anchor = node.type == :xref ? '' : %(<a id="_footnoteref_#{index}">#{DummyText}</a>)
          if defined? @rendered_footnotes
            label = (@rendered_footnotes.include? fn) ? fn.label : (index - @rendered_footnotes.length)
          else
            label = index
          end
          %(<sup class="wj">#{anchor}<a anchor="_footnotedef_#{index}">[#{label}]</a></sup>)
        elsif node.type == :xref
          %(<sup class="wj"><font color="#{theme.role_unresolved_font_color}">[#{node.text}]</font></sup>)
        else
          log :warn, %(unknown footnote type: #{node.type.inspect})
          nil
        end
      end

      def convert_inline_icon node
        if (icons = (doc = node.document).attr 'icons') == 'font'
          if (icon_name = node.target).include? '@'
            icon_name, icon_set = icon_name.split '@', 2
            explicit_icon_set = true
          elsif (icon_set = node.attr 'set')
            explicit_icon_set = true
          else
            icon_set = doc.attr 'icon-set', 'fa'
          end
          if icon_set == 'fa' || !(IconSets.include? icon_set)
            icon_set = 'fa'
            # legacy name from Font Awesome < 5
            if (remapped_icon_name = resolve_legacy_icon_name icon_name)
              requested_icon_name = icon_name
              icon_set, icon_name = remapped_icon_name.split '-', 2
              glyph = (icon_font_data icon_set).unicode icon_name
              log(:info) { %(#{requested_icon_name} icon found in deprecated fa icon set; using #{icon_name} from #{icon_set} icon set instead) }
            # new name in Font Awesome >= 5 (but document is configured to use fa icon set)
            else
              font_data = nil
              if (resolved_icon_set = FontAwesomeIconSets.find {|candidate| (font_data = icon_font_data candidate).unicode icon_name rescue nil })
                icon_set = resolved_icon_set
                glyph = font_data.unicode icon_name
                log(:info) { %(#{icon_name} icon not found in deprecated fa icon set; using match found in #{resolved_icon_set} icon set instead) }
              end
            end
          else
            glyph = (icon_font_data icon_set).unicode icon_name rescue nil
          end
          unless glyph || explicit_icon_set || !icon_name.start_with?(*IconSetPrefixes)
            icon_set, icon_name = icon_name.split '-', 2
            glyph = (icon_font_data icon_set).unicode icon_name rescue nil
          end
          if glyph
            if node.attr? 'size'
              case (size = node.attr 'size')
              when 'lg'
                size_attr = ' size="1.333em"'
              when 'fw'
                size_attr = ' width="1em"'
              else
                size_attr = %( size="#{size.sub 'x', 'em'}")
              end
            else
              size_attr = ''
            end
            class_attr = node.role? ? %( class="#{node.role}") : ''
            # TODO: support rotate and flip attributes
            %(<font name="#{icon_set}"#{size_attr}#{class_attr}>#{glyph}</font>)
          else
            log :warn, %(#{icon_name} is not a valid icon name in the #{icon_set} icon set)
            %([#{node.attr 'alt'}&#93;)
          end
        elsif icons
          image_path = ::File.absolute_path %(#{icon_name = node.target}.#{image_format = doc.attr 'icontype', 'png'}), (doc.attr 'iconsdir')
          if ::File.readable? image_path
            %(<img src="#{image_path}" format="#{image_format}" alt="#{node.attr 'alt'}" fit="line">)
          else
            log :warn, %(image icon for '#{icon_name}' not found or not readable: #{image_path})
            %([#{icon_name}&#93;)
          end
        else
          %([#{node.attr 'alt'}&#93;)
        end
      end

      def convert_inline_image node
        if node.type == 'icon'
          img = convert_inline_icon node
        else
          target, image_format = (node.extend ::Asciidoctor::Image).target_and_format
          if image_format == 'gif' && !(defined? ::GMagick::Image)
            log :warn, %(GIF image format not supported. Install the prawn-gmagick gem or convert #{target} to PNG.)
            img = %([#{node.attr 'alt'}&#93;)
          # NOTE: an image with a data URI is handled using a temporary file
          elsif (image_path = resolve_image_path node, target, image_format)
            if ::File.readable? image_path
              class_attr = (role = node.role) ? %( class="#{role}") : ''
              fit_attr = (fit = node.attr 'fit') ? %( fit="#{fit}") : ''
              if (width = resolve_explicit_width node.attributes)
                if ImageWidth === width
                  if state # check that converter is initialized
                    width = (intrinsic_image_width image_path, image_format) * (width.to_f / 100)
                  else
                    width = %(auto*#{width})
                  end
                elsif node.parent.context == :table_cell && ::String === width && (width.end_with? '%')
                  width += (intrinsic_image_width image_path, image_format).to_s
                end
                width_attr = %( width="#{width}")
              elsif state # check that converter is initialized
                width_attr = %( width="#{intrinsic_image_width image_path, image_format}")
              else
                width_attr = ' width="auto"' # defer operation until arranger runs
              end
              img = %(<img src="#{image_path}" format="#{image_format}" alt="#{encode_quotes node.attr 'alt'}"#{width_attr}#{class_attr}#{fit_attr}>)
            else
              log :warn, %(image to embed not found or not readable: #{image_path})
              img = %([#{node.attr 'alt'}&#93;)
            end
          else
            img = %([#{node.attr 'alt'}&#93;)
          end
        end
        (node.attr? 'link') ? %(<a href="#{node.attr 'link'}">#{img}</a>) : img
      end

      def convert_inline_indexterm node
        visible = node.type == :visible
        if scratch?
          visible ? node.text : ''
        else
          unless defined? @index
            # NOTE: initialize index and text formatter in case converter is called before PDF is initialized
            @index = IndexCatalog.new
            @text_formatter = FormattedText::Formatter.new theme: (load_theme node.document)
          end
          # NOTE: page number (:page key) is added by InlineDestinationMarker
          dest = { anchor: (anchor_name = @index.next_anchor_name) }
          anchor = %(<a id="#{anchor_name}" type="indexterm"#{visible ? ' visible="true"' : ''}>#{DummyText}</a>)
          if visible
            visible_term = node.text
            @index.store_primary_term (FormattedString.new parse_text visible_term, inline_format: [normalize: true]), dest
            %(#{anchor}#{visible_term})
          else
            @index.store_term (node.attr 'terms').map {|term| FormattedString.new parse_text term, inline_format: [normalize: true] }, dest
            anchor
          end
        end
      end

      def convert_inline_kbd node
        if (keys = node.attr 'keys').size == 1
          %(<kbd>#{keys[0]}</kbd>)
        else
          keys.map {|key| %(<kbd>#{key}</kbd>) }.join (load_theme node.document).kbd_separator_content
        end
      end

      def convert_inline_menu node
        menu = node.attr 'menu'
        caret = (load_theme node.document).menu_caret_content
        if !(submenus = node.attr 'submenus').empty?
          %(<menu>#{[menu, *submenus, (node.attr 'menuitem')].join caret}</menu>)
        elsif (menuitem = node.attr 'menuitem')
          %(<menu>#{menu}#{caret}#{menuitem}</menu>)
        else
          %(<menu>#{menu}</menu>)
        end
      end

      def convert_inline_quoted node
        case node.type
        when :emphasis
          open, close, is_tag = ['<em>', '</em>', true]
        when :strong
          open, close, is_tag = ['<strong>', '</strong>', true]
        when :monospaced, :asciimath, :latexmath
          open, close, is_tag = ['<code>', '</code>', true]
        when :superscript
          open, close, is_tag = ['<sup>', '</sup>', true]
        when :subscript
          open, close, is_tag = ['<sub>', '</sub>', true]
        when :double
          open, close = (load_theme node.document).quotes.slice 0, 2
          quotes = true
        when :single
          open, close = (load_theme node.document).quotes.slice 2, 2
          quotes = true
        when :mark
          open, close, is_tag = ['<mark>', '</mark>', true]
        else
          open = close = ''
        end

        inner_text = node.text

        if quotes && (len = inner_text.length) > 3 && (inner_text.end_with? '...') &&
            !((inner_text_trunc = inner_text.slice 0, len - 3).end_with? ?\\)
          inner_text = inner_text_trunc + '&#8230;'
        end

        if (roles = node.role)
          quoted_text = is_tag ? %(#{open.chop} class="#{roles}">#{inner_text}#{close}) : %(<span class="#{roles}">#{open}#{inner_text}#{close}</span>)
        else
          quoted_text = %(#{open}#{inner_text}#{close})
        end

        # NOTE: destination is created inside callback registered by FormattedTextTransform#build_fragment
        node.id ? %(<a id="#{node.id}">#{DummyText}</a>#{quoted_text}) : quoted_text
      end

      # If an id is provided or the node passed as the first argument has an id,
      # add a named destination to the document equivalent to the node id at the
      # current y position. If the node does not have an id and an id is not
      # specified, do nothing.
      #
      # If the node is a section, and the current y position is the top of the
      # page, set the y position equal to the page height to improve the navigation
      # experience. If the current x position is at or inside the left margin, set
      # the x position equal to 0 (left edge of page) to improve the navigation
      # experience.
      def add_dest_for_block node, id: nil, y: nil
        if !scratch? && (id ||= node.id)
          dest_x = bounds.absolute_left.truncate 4
          # QUESTION: when content is aligned to left margin, should we keep precise x value or just use 0?
          dest_x = 0 if dest_x <= page_margin_left
          unless (dest_y = y)
            dest_y = @y
            dest_y += [page_height - dest_y, -@theme.block_anchor_top.to_f].min
          end
          # TODO: find a way to store only the ref of the destination; look it up when we need it
          node.set_attr 'pdf-destination', (node_dest = (dest_xyz dest_x, dest_y))
          add_dest id, node_dest
        end
        nil
      end

      def add_outline doc, num_levels, toc_page_nums, num_front_matter_pages, has_front_cover
        if ::String === num_levels
          if num_levels.include? ':'
            num_levels, expand_levels = num_levels.split ':', 2
            num_levels = num_levels.empty? ? (doc.attr 'toclevels', 2).to_i : num_levels.to_i
            expand_levels = expand_levels.to_i
          else
            num_levels = expand_levels = num_levels.to_i
          end
        else
          expand_levels = num_levels
        end
        front_matter_counter = RomanNumeral.new 0, :lower
        pagenum_labels = {}

        num_front_matter_pages.times do |n|
          pagenum_labels[n] = { P: (::PDF::Core::LiteralString.new front_matter_counter.next!.to_s) }
        end

        # add labels for each content page, which is required for reader's page navigator to work correctly
        (num_front_matter_pages..(page_count - 1)).each_with_index do |n, i|
          pagenum_labels[n] = { P: (::PDF::Core::LiteralString.new (i + 1).to_s) }
        end

        unless toc_page_nums.none? || (toc_title = doc.attr 'toc-title').nil_or_empty?
          toc_section = insert_toc_section doc, toc_title, toc_page_nums
        end

        outline.define do
          initial_pagenum = has_front_cover ? 2 : 1
          # FIXME: use sanitize: :plain_text on Document#doctitle once available
          if document.page_count >= initial_pagenum && (outline_title = doc.attr 'outline-title') &&
              (outline_title.empty? ? (outline_title = document.resolve_doctitle doc) : outline_title)
            page title: (document.sanitize outline_title), destination: (document.dest_top initial_pagenum)
          end
          # QUESTION: is there any way to get add_outline_level to invoke in the context of the outline?
          document.add_outline_level self, doc.sections, num_levels, expand_levels
        end if doc.attr? 'outline'

        toc_section&.remove

        catalog.data[:PageLabels] = state.store.ref Nums: pagenum_labels.flatten
        primary_page_mode, secondary_page_mode = PageModes[(doc.attr 'pdf-page-mode') || @theme.page_mode]
        catalog.data[:PageMode] = primary_page_mode
        catalog.data[:NonFullScreenPageMode] = secondary_page_mode if secondary_page_mode
        nil
      end

      def add_outline_level outline, sections, num_levels, expand_levels
        sections.each do |sect|
          next if (num_levels_for_sect = (sect.attr 'outlinelevels', num_levels).to_i) < (level = sect.level) ||
            ((sect.option? 'notitle') && sect == sect.document.last_child && sect.empty?)
          sect_title = sanitize sect.numbered_title formal: true
          next if sect_title.empty?
          sect_destination = sect.attr 'pdf-destination'
          if level < num_levels_for_sect && sect.sections?
            outline.section sect_title, destination: sect_destination, closed: expand_levels < 1 do
              add_outline_level outline, sect.sections, num_levels_for_sect, (expand_levels - 1)
            end
          else
            outline.page title: sect_title, destination: sect_destination
          end
        end
      end

      def apply_subs_discretely doc, value, opts = {}
        if (imagesdir = opts[:imagesdir])
          imagesdir_to_restore = doc.attr 'imagesdir'
          doc.set_attr 'imagesdir', imagesdir
          remove_docimagesdir = doc.set_attr 'docimagesdir', (::File.absolute_path imagesdir_to_restore.to_s, (doc.attr 'docdir', '')), false
        end
        if (page_layout = opts[:page_layout])
          page_layout_to_restore = doc.attr 'page-layout'
          doc.set_attr 'page-layout', page.layout.to_s
        end
        # FIXME: get sub_attributes to handle drop-line w/o a warning
        doc.set_attr 'attribute-missing', 'skip' unless (attribute_missing = doc.attr 'attribute-missing') == 'skip'
        value = value.gsub '\{', '\\\\\\{' if (escaped_attr_ref = value.include? '\{')
        value = (subs = opts[:subs]) ? (doc.apply_subs value, subs) : (doc.apply_subs value)
        value = (value.split LF).delete_if {|line| SimpleAttributeRefRx.match? line }.join LF if opts[:drop_lines_with_unresolved_attributes] && (value.include? '{')
        value = value.gsub '\{', '{' if escaped_attr_ref
        doc.set_attr 'attribute-missing', attribute_missing unless attribute_missing == 'skip'
        page_layout_to_restore ? (doc.set_attr 'page-layout', page_layout_to_restore) : (doc.remove_attr 'page-layout') if page_layout
        if imagesdir
          imagesdir_to_restore ? (doc.set_attr 'imagesdir', imagesdir_to_restore) : (doc.remove_attr 'imagesdir')
          doc.remove_attr 'docimagesdir' if remove_docimagesdir
        end
        value
      end

      # Position the cursor for where to ink the specified section title or discrete heading node.
      #
      # This method computes whether there's enough room on the page to prevent the specified node
      # from being orphaned. If there's not enough room, the method will advance the cursor to
      # the next page. This method is not called if the cursor is already at the top of the page or
      # whether this node has no node that follows it in document order.
      def arrange_heading node, title, opts
        if (min_height_after = @theme.heading_min_height_after) == 'auto' || (node.option? 'breakable')
          orphaned = nil
          doc = node.document
          dry_run single_page: true do
            push_scratch doc
            start_page = page
            theme_font :heading, level: opts[:level] do
              if opts[:part]
                ink_part_title node, title, opts
              elsif opts[:chapterlike]
                ink_chapter_title node, title, opts
              else
                ink_general_heading node, title, opts
              end
            end
            if page == start_page
              page.tare_content_stream
              orphaned = stop_if_first_page_empty { node.context == :section ? (traverse node) : (convert node.next_sibling) }
            end
          ensure
            pop_scratch doc
          end
          advance_page if orphaned
        else
          theme_font :heading, level: (hlevel = opts[:level]) do
            if (space_below = ::Numeric === min_height_after ? min_height_after : 0) > 0 && (node.context == :section ? node.blocks? : !node.last_child?)
              space_below += @theme[%(heading_h#{hlevel}_margin_bottom)] || @theme.heading_margin_bottom
            else
              space_below = 0
            end
            h_padding_t, h_padding_r, h_padding_b, h_padding_l = expand_padding_value @theme[%(heading_h#{hlevel}_padding)]
            h_fits = indent h_padding_l, h_padding_r do
              cursor >= (height_of_typeset_text title, inline_format: true, text_transform: @text_transform) +
                h_padding_t + h_padding_b + (@theme[%(heading_h#{hlevel}_margin_top)] || @theme.heading_margin_top) + space_below
            end
            advance_page unless h_fits
          end
        end
        nil
      end

      # NOTE: only used when tabsize attribute is not specified
      # tabs must always be replaced with spaces in order for the indentation guards to work
      def expand_tabs string
        if string.nil_or_empty?
          ''
        elsif string.include? TAB
          full_tab_space = ' ' * (tab_size = 4)
          (string.split LF, -1).map do |line|
            if line.empty? || !(tab_idx = line.index TAB)
              line
            else
              if tab_idx == 0
                leading_tabs = 0
                line.each_byte do |b|
                  break unless b == 9
                  leading_tabs += 1
                end
                line = %(#{full_tab_space * leading_tabs}#{rest = line.slice leading_tabs, line.length})
                next line unless rest.include? TAB
              end
              # keeps track of how many spaces were added to adjust offset in match data
              spaces_added = 0
              idx = 0
              result = ''
              line.each_char do |c|
                if c == TAB
                  # calculate how many spaces this tab represents, then replace tab with spaces
                  if (offset = idx + spaces_added) % tab_size == 0
                    spaces_added += (tab_size - 1)
                    result += full_tab_space
                  else
                    unless (spaces = tab_size - offset % tab_size) == 1
                      spaces_added += (spaces - 1)
                    end
                    result += (' ' * spaces)
                  end
                else
                  result += c
                end
                idx += 1
              end
              result
            end
          end.join LF
        else
          string
        end
      end

      # Extract callout marks from string, indexed by 0-based line number
      # Return an Array with the processed string as the first argument
      # and the mapping of lines to conums as the second.
      def extract_conums string
        conum_mapping = {}
        auto_num = 0
        string = (string.split LF).map.with_index do |line, line_num|
          # FIXME: we get extra spaces before numbers if more than one on a line
          if line.include? '<'
            line = line.gsub CalloutExtractRx do
              # honor the escape
              if $1 == ?\\
                $&.sub $1, ''
              else
                (conum_mapping[line_num] ||= []) << ($3 == '.' ? (auto_num += 1) : $3.to_i)
                ''
              end
            end
            # NOTE: use first position to store space that precedes conums
            if (conum_mapping.key? line_num) && (line.end_with? ' ')
              trimmed_line = line.rstrip
              conum_mapping[line_num].unshift line.slice trimmed_line.length, line.length
              line = trimmed_line
            end
          end
          line
        end.join LF
        conum_mapping = nil if conum_mapping.empty?
        [string, conum_mapping]
      end

      # Restore the conums into the Array of formatted text fragments
      #--
      # QUESTION: can this be done more efficiently?
      # QUESTION: can we reuse arrange_fragments_by_line?
      def restore_conums fragments, conum_mapping, linenums = nil, highlight_lines = nil
        lines = []
        line_num = 0
        # reorganize the fragments into an array of lines
        fragments.each do |fragment|
          line = (lines[line_num] ||= [])
          if (text = fragment[:text]) == LF
            lines[line_num += 1] ||= []
          elsif text.include? LF
            (text.split LF, -1).each_with_index do |line_in_fragment, idx|
              line = (lines[line_num += 1] ||= []) unless idx == 0
              line << (fragment.merge text: line_in_fragment) unless line_in_fragment.empty?
            end
          else
            line << fragment
          end
        end
        conum_font_color = @theme.conum_font_color
        if (conum_font_name = @theme.conum_font_family) == font_name
          conum_font_name = nil
        end
        last_line_num = lines.size - 1
        if linenums
          pad_size = (last_line_num + 1).to_s.length
          linenum_color = @theme.code_linenum_font_color
        end
        # append conums to appropriate lines, then flatten to an array of fragments
        lines.flat_map.with_index do |line, cur_line_num|
          last_line = cur_line_num == last_line_num
          visible_line_num = cur_line_num + (linenums || 1)
          if highlight_lines && (highlight_bg_color = highlight_lines[visible_line_num])
            line.unshift text: DummyText, background_color: highlight_bg_color, highlight: true, inline_block: true, extend: true, width: 0, callback: [FormattedText::TextBackgroundAndBorderRenderer]
          end
          line.unshift text: %(#{visible_line_num.to_s.rjust pad_size} ), linenum: visible_line_num, color: linenum_color if linenums
          if conum_mapping && (conums = conum_mapping.delete cur_line_num)
            line << { text: conums.shift } if ::String === conums[0]
            conum_text = conums.map {|num| conum_glyph num }.join ' '
            conum_fragment = { text: conum_text }
            conum_fragment[:color] = conum_font_color if conum_font_color
            conum_fragment[:font] = conum_font_name if conum_font_name
            line << conum_fragment
          end
          line << { text: LF } unless last_line
          line
        end
      end

      def fallback_svg_font_name
        @theme.svg_fallback_font_family || @theme.base_font_family
      end

      # Add an indentation guard at the start of indented lines.
      # Expand tabs to spaces if tabs are present
      def guard_indentation string
        unless (string = expand_tabs string).empty?
          string[0] = GuardedIndent if string.start_with? ' '
          string.gsub! InnerIndent, GuardedInnerIndent if string.include? InnerIndent
        end
        string
      end

      def guard_indentation_in_fragments fragments
        start_of_line = true
        fragments.each do |fragment|
          next if (text = fragment[:text]).empty?
          if start_of_line && (text.start_with? ' ')
            fragment[:text] = GuardedIndent + (((text = text.slice 1, text.length).include? InnerIndent) ? (text.gsub InnerIndent, GuardedInnerIndent) : text)
          elsif text.include? InnerIndent
            fragment[:text] = text.gsub InnerIndent, GuardedInnerIndent
          end
          start_of_line = text.end_with? LF
        end
        fragments
      end

      def height_of_typeset_text string, opts = {}
        if (transform = opts[:text_transform])
          string = transform_text string, transform
        end
        if (inline_format = opts[:inline_format]) && (InlineFormatSniffRx.match? string)
          fragments = parse_text string, inline_format: inline_format
        else
          fragments = [{ text: string }]
        end
        line_metrics = (calc_line_metrics opts[:line_height] || @base_line_height)
        (height_of_formatted fragments, leading: line_metrics.leading, final_gap: line_metrics.final_gap) + line_metrics.padding_top + (opts[:single_line] ? 0 : line_metrics.padding_bottom)
      end

      # Render the caption in the current document. If the dry_run option is true, return the height.
      #
      # The subject argument can either be a String or an AbstractNode. If
      # subject is an AbstractNode, only call this method if the node has a
      # title (i.e., subject.title? returns true).
      def ink_caption subject, opts = {}
        if opts.delete :dry_run
          return (dry_run keep_together: true, single_page: :enforce do
            if opts.delete :force_top_margin
              conceal_page_top { ink_caption subject, opts }
            else
              ink_caption subject, opts
            end
          end).single_page_height
        end
        if ::Asciidoctor::AbstractBlock === subject
          string = (opts.delete :labeled) == false ? subject.title : subject.captioned_title
        else
          string = subject.to_s
        end
        block_align = opts.delete :block_align
        block_width = opts.delete :block_width
        category_caption = (category = opts[:category]) ? %(#{category}_caption) : 'caption'
        caption_margin_outside = @theme[%(#{category_caption}_margin_outside)] || @theme.caption_margin_outside
        caption_margin_inside = @theme[%(#{category_caption}_margin_inside)] || @theme.caption_margin_inside
        container_width = bounds.width
        indent_by = [0, 0]
        if (align = @theme[%(#{category_caption}_align)] || @theme.caption_align)
          align = align == 'inherit' ? (block_align || @base_text_align.to_sym) : align.to_sym
        else
          align = @base_text_align.to_sym
        end
        if (text_align = @theme[%(#{category_caption}_text_align)] || @theme.caption_text_align)
          text_align = text_align == 'inherit' ? align : text_align.to_sym
        else
          text_align = align
        end
        if (max_width = opts.delete :max_width) && max_width != 'none'
          if ::String === max_width
            if max_width.start_with? 'fit-content'
              block_width ||= container_width
              unless max_width.end_with? 't', '()'
                max_width = block_width * (max_width.slice 12, max_width.length - 1).to_f / 100.0
                if (caption_width_delta = block_width - max_width) > 0
                  case align
                  when :right
                    indent_by[0] += caption_width_delta
                  when :center
                    indent_by[0] += caption_width_delta * 0.5
                    indent_by[1] += caption_width_delta * 0.5
                  else # :left, nil
                    indent_by[1] += caption_width_delta
                  end
                end
              end
              max_width = block_width
            elsif max_width.end_with? '%'
              max_width = [max_width.to_f / 100 * bounds.width, bounds.width].min
              block_align = align
            else
              max_width = [max_width.to_f, bounds.width].min
              block_align = align
            end
          else
            max_width = [max_width, bounds.width].min
            block_align = align
          end
          if (remainder = container_width - max_width) > 0
            case block_align
            when :right
              indent_by[0] += remainder
            when :center
              indent_by[0] += remainder * 0.5
              indent_by[1] += remainder * 0.5
            else # :left, nil
              indent_by[1] += remainder
            end
          end
        end
        theme_font_cascade ['caption', category_caption] do
          if ((opts.delete :end) || (opts.delete :side) || :top) == :top
            margin = { top: caption_margin_outside, bottom: caption_margin_inside }
          else
            margin = { top: caption_margin_inside, bottom: caption_margin_outside }
          end
          unless (inherited = apply_text_decoration [], :caption).empty?
            opts = opts.merge inherited
          end
          unless scratch? || !(bg_color = @theme[%(#{category_caption}_background_color)] || @theme.caption_background_color)
            caption_height = height_of_typeset_text string, inline_format: true, text_transform: @text_transform
            fill_at = [bounds.left, cursor]
            fill_at[1] -= (margin[:top] || 0) unless at_page_top?
            float { bounding_box(fill_at, width: container_width, height: caption_height) { fill_bounds bg_color } }
          end
          indent(*indent_by) do
            ink_prose string, ({
              margin_top: margin[:top],
              margin_bottom: margin[:bottom],
              align: text_align,
              normalize: false,
              normalize_line_height: true,
              hyphenate: true,
            }.merge opts)
          end
        end
        nil
      end

      # Render the caption for a table and return the height of the rendered content
      def ink_table_caption node, table_alignment = :left, table_width = nil, max_width = nil, end_ = :top
        ink_caption node, category: :table, end: end_, block_align: table_alignment, block_width: table_width, max_width: max_width
      end

      def ink_chapter_title node, title, opts = {}
        ink_general_heading node, title, (opts.merge outdent: true)
      end

      alias ink_part_title ink_chapter_title

      def ink_cover_page doc, face
        image_path, image_opts = resolve_background_image doc, @theme, %(#{face}-cover-image), theme_key: %(cover_#{face}_image).to_sym, symbolic_paths: ['', '~']
        return unless image_path
        if image_path.empty?
          go_to_page page_count if face == :back
          start_new_page_discretely
          # NOTE: open graphics state to prevent page from being reused
          open_graphics_state if face == :front
          return
        elsif image_path == '~'
          @page_margin[:cover] = @page_margin[page.layout][:recto] if @media == 'prepress'
          return
        end

        go_to_page page_count if face == :back
        if image_opts[:format] == 'pdf'
          import_page image_path, (image_opts.merge advance: face != :back, advance_if_missing: false)
        else
          begin
            image_page image_path, image_opts
          rescue
            log :warn, %(could not embed #{face} cover image: #{image_path}; #{$!.message})
          end
        end
      end

      # QUESTION: if a footnote ref appears in a separate chapter, should the footnote def be duplicated?
      def ink_footnotes node
        return if (fns = (doc = node.document).footnotes - @rendered_footnotes).empty?
        theme_margin :block, :bottom if node.context == :document || node == node.document.last_child
        theme_margin :footnotes, :top unless (valign_bottom = @theme.footnotes_margin_top == 'auto')
        with_dry_run do |extent|
          if valign_bottom && (single_page_height = extent&.single_page_height) && (delta = cursor - single_page_height - 0.0001) > 0
            move_down delta
          end
          theme_font :footnotes do
            (title = doc.attr 'footnotes-title') && (ink_caption title, category: :footnotes)
            item_spacing = @theme.footnotes_item_spacing
            index_offset = @rendered_footnotes.length
            sect_xreftext = node.context == :section && (node.xreftext node.document.attr 'xrefstyle')
            fns.each do |fn|
              label = (index = fn.index) - index_offset
              if sect_xreftext
                fn.singleton_class.send :attr_accessor, :label unless fn.respond_to? :label=
                fn.label = %(#{label} - #{sect_xreftext})
              end
              ink_prose %(<a id="_footnotedef_#{index}">#{DummyText}</a><strong><a anchor="_footnoteref_#{index}">#{label}.</a></strong> #{fn.text}), margin_bottom: item_spacing, hyphenate: true
            end
            @rendered_footnotes += fns if extent
          end
        end
        nil
      end

      def ink_general_heading _node, title, opts = {}
        ink_heading title, opts
      end

      # NOTE: ink_heading doesn't set the theme font because it's used for various types of headings
      def ink_heading string, opts = {}
        if (h_level = opts[:level])
          h_category = %(heading_h#{h_level})
        end
        unless (top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top))
          if at_page_top?
            if h_category && (top_margin = @theme[%(#{h_category}_margin_page_top)] || @theme.heading_margin_page_top) > 0
              move_down top_margin
            end
            top_margin = 0
          else
            top_margin = (h_category ? @theme[%(#{h_category}_margin_top)] : nil) || @theme.heading_margin_top
          end
        end
        bot_margin = margin || (opts.delete :margin_bottom) || (h_category ? @theme[%(#{h_category}_margin_bottom)] : nil) || @theme.heading_margin_bottom
        if (transform = resolve_text_transform opts)
          string = transform_text string, transform
        end
        outdent_section opts.delete :outdent do
          margin_top top_margin
          start_cursor = cursor
          start_page_number = page_number
          pad_box h_category ? @theme[%(#{h_category}_padding)] : nil do
            # QUESTION: should we move inherited styles to typeset_text?
            if (inherited = apply_text_decoration font_styles, :heading, h_level).empty?
              inline_format_opts = true
            else
              inline_format_opts = [{ inherited: inherited }]
            end
            typeset_text string, (calc_line_metrics (opts.delete :line_height) || @base_line_height), {
              color: @font_color,
              inline_format: inline_format_opts,
              align: @base_text_align.to_sym,
            }.merge(opts)
          end
          if h_category && @theme[%(#{h_category}_border_width)] && (@theme[%(#{h_category}_border_color)] || @theme.base_border_color)
            start_cursor = bounds.top unless page_number == start_page_number
            float do
              bounding_box [bounds.left, start_cursor], width: bounds.width, height: start_cursor - cursor do
                theme_fill_and_stroke_bounds h_category
              end
            end
          end
          margin_bottom bot_margin
        end
      end

      # NOTE: inline_format option is true by default
      # NOTE: single_line option is not compatible with this method
      def ink_prose string, opts = {}
        top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || 0
        bot_margin = margin || (opts.delete :margin_bottom) || @theme.prose_margin_bottom
        if (transform = resolve_text_transform opts)
          string = transform_text string, transform
        end
        string = hyphenate_text string, @hyphenator if (opts.delete :hyphenate) && (defined? @hyphenator)
        # NOTE: used by extensions; ensures linked text gets formatted using the link styles
        if (anchor = opts.delete :anchor)
          string = anchor == true ? %(<a>#{string}</a>) : %(<a anchor="#{anchor}">#{string}</a>)
        end
        margin_top top_margin
        # NOTE: normalize makes endlines soft (replaces "\n" with ' ')
        inline_format_opts = { normalize: (opts.delete :normalize) != false }
        if (styles = opts.delete :styles)
          inline_format_opts[:inherited] = {
            styles: styles,
            text_decoration_color: (opts.delete :text_decoration_color),
            text_decoration_width: (opts.delete :text_decoration_width),
          }.compact
        end
        result = typeset_text string, (calc_line_metrics (opts.delete :line_height) || @base_line_height), {
          color: @font_color,
          inline_format: [inline_format_opts],
          align: @base_text_align.to_sym,
        }.merge(opts)
        margin_bottom bot_margin
        result
      end

      def allocate_running_content_layout doc, page, periphery, cache
        cache[layout = page.layout] ||= begin
          page_margin_recto = @page_margin[layout][:recto]
          trim_margin_recto = @theme[%(#{periphery}_recto_margin)] || @theme[%(#{periphery}_margin)] || [0, 'inherit', 0, 'inherit']
          trim_margin_recto = (expand_margin_value trim_margin_recto).map.with_index {|v, i| i.odd? && v == 'inherit' ? page_margin_recto[i] : v.to_f }
          trim_content_margin_recto = @theme[%(#{periphery}_recto_content_margin)] || @theme[%(#{periphery}_content_margin)] || [0, 'inherit', 0, 'inherit']
          trim_content_margin_recto = (expand_margin_value trim_content_margin_recto).map.with_index {|v, i| i.odd? && v == 'inherit' ? page_margin_recto[i] - trim_margin_recto[i] : v.to_f }
          if (trim_padding_recto = @theme[%(#{periphery}_recto_padding)] || @theme[%(#{periphery}_padding)])
            trim_padding_recto = (expand_padding_value trim_padding_recto).map.with_index {|v, i| v + trim_content_margin_recto[i] }
          else
            trim_padding_recto = trim_content_margin_recto
          end
          page_margin_verso = @page_margin[layout][:verso]
          trim_margin_verso = @theme[%(#{periphery}_verso_margin)] || @theme[%(#{periphery}_margin)] || [0, 'inherit', 0, 'inherit']
          trim_margin_verso = (expand_margin_value trim_margin_verso).map.with_index {|v, i| i.odd? && v == 'inherit' ? page_margin_verso[i] : v.to_f }
          trim_content_margin_verso = @theme[%(#{periphery}_verso_content_margin)] || @theme[%(#{periphery}_content_margin)] || [0, 'inherit', 0, 'inherit']
          trim_content_margin_verso = (expand_margin_value trim_content_margin_verso).map.with_index {|v, i| i.odd? && v == 'inherit' ? page_margin_verso[i] - trim_margin_verso[i] : v.to_f }
          if (trim_padding_verso = @theme[%(#{periphery}_verso_padding)] || @theme[%(#{periphery}_padding)])
            trim_padding_verso = (expand_padding_value trim_padding_verso).map.with_index {|v, i| v + trim_content_margin_verso[i] }
          else
            trim_padding_verso = trim_content_margin_verso
          end
          valign, valign_offset = @theme[%(#{periphery}_vertical_align)]
          if (valign = valign&.to_sym || :middle) == :middle
            valign = :center
          end
          trim_styles = {
            line_metrics: (trim_line_metrics = calc_line_metrics @theme[%(#{periphery}_line_height)] || @base_line_height),
            # NOTE: we've already verified this property is set
            height: (trim_height = @theme[%(#{periphery}_height)]),
            bg_color: (resolve_theme_color %(#{periphery}_background_color).to_sym),
            border_width: (trim_border_width = @theme[%(#{periphery}_border_width)] || 0),
            border_color: trim_border_width > 0 ? (resolve_theme_color %(#{periphery}_border_color).to_sym, @theme.base_border_color) : nil,
            border_style: (@theme[%(#{periphery}_border_style)]&.to_sym || :solid),
            column_rule_width: (trim_column_rule_width = @theme[%(#{periphery}_column_rule_width)] || 0),
            column_rule_color: trim_column_rule_width > 0 ? (resolve_theme_color %(#{periphery}_column_rule_color).to_sym) : nil,
            column_rule_style: (@theme[%(#{periphery}_column_rule_style)]&.to_sym || :solid),
            column_rule_spacing: (@theme[%(#{periphery}_column_rule_spacing)] || 0),
            valign: valign_offset ? [valign, valign_offset] : valign,
            img_valign: @theme[%(#{periphery}_image_vertical_align)],
            top: {
              recto: periphery == :header ? page_height - trim_margin_recto[0] : trim_height + trim_margin_recto[2],
              verso: periphery == :header ? page_height - trim_margin_verso[0] : trim_height + trim_margin_verso[2],
            },
            left: {
              recto: (trim_left_recto = trim_margin_recto[3]),
              verso: (trim_left_verso = trim_margin_verso[3]),
            },
            width: {
              recto: (trim_width_recto = page_width - trim_left_recto - trim_margin_recto[1]),
              verso: (trim_width_verso = page_width - trim_left_verso - trim_margin_verso[1]),
            },
            padding: {
              recto: trim_padding_recto,
              verso: trim_padding_verso,
            },
            content_left: {
              recto: trim_left_recto + trim_padding_recto[3],
              verso: trim_left_verso + trim_padding_verso[3],
            },
            content_width: (trim_content_width = {
              recto: trim_width_recto - trim_padding_recto[1] - trim_padding_recto[3],
              verso: trim_width_verso - trim_padding_verso[1] - trim_padding_verso[3],
            }),
            content_height: (trim_content_height = {
              recto: trim_height - trim_padding_recto[0] - trim_padding_recto[2] - (trim_border_width * 0.5),
              verso: trim_height - trim_padding_verso[0] - trim_padding_verso[2] - (trim_border_width * 0.5),
            }),
            prose_content_height: {
              recto: trim_content_height[:recto] - trim_line_metrics.padding_top - trim_line_metrics.padding_bottom,
              verso: trim_content_height[:verso] - trim_line_metrics.padding_top - trim_line_metrics.padding_bottom,
            },
            # NOTE: content offset adjusts y position to account for border
            content_offset: (periphery == :footer ? trim_border_width * 0.5 : 0),
          }
          case trim_styles[:img_valign]
          when nil
            trim_styles[:img_valign] = valign
          when 'middle'
            trim_styles[:img_valign] = :center
          when 'top', 'center', 'bottom'
            trim_styles[:img_valign] = trim_styles[:img_valign].to_sym
          end

          if (trim_bg_image_recto = resolve_background_image doc, @theme, %(#{periphery}_background_image).to_sym, container_size: [trim_width_recto, trim_height])&.first
            trim_bg_image = { recto: trim_bg_image_recto }
            if trim_width_recto == trim_width_verso
              trim_bg_image[:verso] = trim_bg_image_recto
            else
              trim_bg_image[:verso] = resolve_background_image doc, @theme, %(#{periphery}_background_image).to_sym, container_size: [trim_width_verso, trim_height]
            end
          end

          colspec_dict = {}.tap do |acc|
            PageSides.each do |side|
              side_trim_content_width = trim_content_width[side]
              if (custom_colspecs = @theme[%(#{periphery}_#{side}_columns)] || @theme[%(#{periphery}_columns)])
                case (colspecs = (custom_colspecs.to_s.tr ',', ' ').split).size
                when 0, 1
                  colspecs = { left: '0', center: colspecs[0] || '100', right: '0' }
                when 2
                  colspecs = { left: colspecs[0], center: '0', right: colspecs[1] }
                else # 3
                  colspecs = { left: colspecs[0], center: colspecs[1], right: colspecs[2] }
                end
                tot_width = 0
                side_colspecs = {}.tap do |accum|
                  colspecs.each do |col, spec|
                    if (alignment_char = spec.chr).to_i.to_s == alignment_char
                      alignment = :left
                      rel_width = spec.to_f
                    else
                      alignment = AlignmentTable[alignment_char]
                      rel_width = (spec.slice 1, spec.length).to_f
                    end
                    tot_width += rel_width
                    accum[col] = { align: alignment, width: rel_width, x: 0 }
                  end
                end
                # QUESTION: should we allow the columns to overlap (capping width at 100%)?
                side_colspecs.each_value {|colspec| colspec[:width] = (colspec[:width] / tot_width) * side_trim_content_width }
                side_colspecs[:right][:x] = (side_colspecs[:center][:x] = side_colspecs[:left][:width]) + side_colspecs[:center][:width]
                acc[side] = side_colspecs
              else
                acc[side] = {
                  left: { align: :left, width: side_trim_content_width, x: 0 },
                  center: { align: :center, width: side_trim_content_width, x: 0 },
                  right: { align: :right, width: side_trim_content_width, x: 0 },
                }
              end
            end
          end

          content_dict = {}.tap do |acc|
            PageSides.each do |side|
              side_content = {}
              ColumnPositions.each do |position|
                next if (val = @theme[%(#{periphery}_#{side}_#{position}_content)]).nil_or_empty?
                val = val.to_s unless ::String === val
                if (val.include? ':') && val =~ ImageAttributeValueRx
                  attrlist = $2
                  image_attrs = (::Asciidoctor::AttributeList.new attrlist).parse %w(alt width)
                  image_path, image_format = ::Asciidoctor::Image.target_and_format $1, image_attrs
                  image_path = apply_subs_discretely doc, image_path, subs: [:attributes], imagesdir: @themesdir
                  if (image_path = resolve_image_path doc, image_path, image_format, @themesdir) && (::File.readable? image_path)
                    image_opts = resolve_image_options image_path, image_format, image_attrs, container_size: [colspec_dict[side][position][:width], trim_content_height[side]]
                    side_content[position] = [image_path, image_opts, image_attrs['link']]
                  else
                    # NOTE: allows inline image handler to report invalid reference and replace with alt text
                    side_content[position] = %(image:#{image_path}[#{attrlist}])
                  end
                else
                  side_content[position] = val
                end
              end

              acc[side] = side_content
            end
          end

          if (trim_bg_color = trim_styles[:bg_color]) || trim_bg_image || trim_border_width > 0
            stamp_names = { recto: %(#{layout}_#{periphery}_recto), verso: %(#{layout}_#{periphery}_verso) }
            PageSides.each do |side|
              create_stamp stamp_names[side] do
                canvas do
                  bounding_box [trim_styles[:left][side], trim_styles[:top][side]], width: trim_styles[:width][side], height: trim_height do
                    fill_bounds trim_bg_color if trim_bg_color
                    # NOTE: must draw line before image or SVG will cause border to disappear
                    stroke_horizontal_rule trim_styles[:border_color], line_width: trim_border_width, line_style: trim_styles[:border_style], at: (periphery == :header ? bounds.height : 0) if trim_border_width > 0
                    image trim_bg_image[side][0], ({ position: :center, vposition: :center }.merge trim_bg_image[side][1]) if trim_bg_image
                  end
                end
              end
            end
          end

          [trim_styles, colspec_dict, content_dict, stamp_names]
        end
      end

      # TODO: delegate to ink_page_header and ink_page_footer per page
      def ink_running_content periphery, doc, skip = [1, 1], body_start_page_number = 1
        skip_pages, skip_pagenums = skip
        # NOTE: find and advance to first non-imported content page to use as model page
        return unless (content_start_page_number = state.pages[skip_pages..-1].index {|it| !it.imported_page? })
        content_start_page_number += (skip_pages + 1)
        num_pages = page_count
        prev_page_number = page_number
        go_to_page content_start_page_number

        # FIXME: probably need to treat doctypes differently
        is_book = doc.doctype == 'book'
        header = doc.header? ? doc.header : nil
        sectlevels = (@theme[%(#{periphery}_sectlevels)] || 2).to_i
        sections = doc.find_by(context: :section) {|sect| sect.level <= sectlevels && sect != header }
        toc_title = (doc.attr 'toc-title').to_s if (toc_page_nums = @toc_extent&.page_range)
        disable_on_pages = @disable_running_content[periphery]

        title_method = TitleStyles[@theme[%(#{periphery}_title_style)]]
        # FIXME: we need a proper model for all this page counting
        # FIXME: we make a big assumption that part & chapter start on new pages
        # index parts, chapters and sections by the physical page number on which they start
        part_start_pages = {}
        chapter_start_pages = {}
        section_start_pages = {}
        trailing_section_start_pages = {}
        sections.each do |sect|
          pgnum = (sect.attr 'pdf-page-start').to_i
          if is_book && ((sect_is_part = sect.sectname == 'part') || sect.level == 1)
            if sect_is_part
              part_start_pages[pgnum] ||= sect
            else
              chapter_start_pages[pgnum] ||= sect
              # FIXME: need a better way to indicate that part has ended
              part_start_pages[pgnum] = '' if sect.sectname == 'appendix' && !part_start_pages.empty?
            end
          else
            trailing_section_start_pages[pgnum] = sect
            section_start_pages[pgnum] ||= sect
          end
        end

        # index parts, chapters, and sections by the physical page number on which they appear
        parts_by_page = SectionInfoByPage.new title_method
        chapters_by_page = SectionInfoByPage.new title_method
        sections_by_page = SectionInfoByPage.new title_method
        # QUESTION: should the default part be the doctitle?
        last_part = nil
        # QUESTION: should we enforce that the preamble is a preface?
        last_chap = is_book ? :pre : nil
        last_sect = nil
        sect_search_threshold = 1
        (1..num_pages).each do |pgnum|
          if (part = part_start_pages[pgnum])
            last_part = part
            last_chap = nil
            last_sect = nil
          end
          if (chap = chapter_start_pages[pgnum])
            last_chap = chap
            last_sect = nil
          end
          if (sect = section_start_pages[pgnum])
            last_sect = sect
          elsif part || chap
            sect_search_threshold = pgnum
          # NOTE: we didn't find a section on this page; look back to find last section started
          elsif last_sect
            (sect_search_threshold..(pgnum - 1)).reverse_each do |prev|
              if (sect = trailing_section_start_pages[prev])
                last_sect = sect
                break
              end
            end
          end
          parts_by_page[pgnum] = last_part
          if toc_page_nums&.cover? pgnum
            if is_book
              chapters_by_page[pgnum] = toc_title
              sections_by_page[pgnum] = nil
            else
              chapters_by_page[pgnum] = nil
              sections_by_page[pgnum] = section_start_pages[pgnum] || toc_title
            end
            toc_page_nums = nil if toc_page_nums.end == pgnum
          elsif last_chap == :pre
            chapters_by_page[pgnum] = pgnum < body_start_page_number ? doc.doctitle : (doc.attr 'preface-title', 'Preface')
            sections_by_page[pgnum] = last_sect
          else
            chapters_by_page[pgnum] = last_chap
            sections_by_page[pgnum] = last_sect
          end
        end

        doctitle = resolve_doctitle doc, true
        # NOTE: set doctitle again so it's properly escaped
        doc.set_attr 'doctitle', doctitle.combined
        doc.set_attr 'document-title', doctitle.main
        doc.set_attr 'document-subtitle', doctitle.subtitle
        doc.set_attr 'page-count', (num_pages - skip_pagenums)

        pagenums_enabled = doc.attr? 'pagenums'
        periphery_layout_cache = {}
        # NOTE: Prawn fails to properly set color spaces on empty pages, but repeater relies on them
        # prefer simpler fix below call to repeat; keep this workaround in case that workaround stops working
        #(content_start_page_number..num_pages).each do |pgnum|
        #  next if (disable_on_pages.include? pgnum) || (pg = state.pages[pgnum - 1]).imported_page? || !pg.graphic_state.color_space.empty?
        #  go_to_page pgnum
        #  set_color_space :fill, (color_space graphic_state.fill_color)
        #  set_color_space :stroke, (color_space graphic_state.stroke_color)
        #end
        #go_to_page content_start_page_number if page_number != content_start_page_number
        # NOTE: this block is invoked during PDF generation, during call to #write -> #render_file and thus after #convert_document
        repeat (content_start_page_number..num_pages), dynamic: true do
          pgnum = page_number
          # NOTE: don't write on pages which are imported / inserts (otherwise we can get a corrupt PDF)
          next if page.imported_page? || (disable_on_pages.include? pgnum)
          virtual_pgnum = pgnum - skip_pagenums
          pgnum_label = (virtual_pgnum < 1 ? (RomanNumeral.new pgnum, :lower) : virtual_pgnum).to_s
          side = page_side (@folio_placement[:basis] == :physical ? pgnum : virtual_pgnum), @folio_placement[:inverted]
          doc.set_attr 'page-layout', page.layout.to_s

          # NOTE: running content is cached per page layout
          # QUESTION: should allocation be per side?
          trim_styles, colspec_dict, content_dict, stamp_names = allocate_running_content_layout doc, page, periphery, periphery_layout_cache
          # FIXME: we need to have a content setting for chapter pages
          content_by_position, colspec_by_position = content_dict[side], colspec_dict[side]

          doc.set_attr 'page-number', pgnum_label if pagenums_enabled
          # QUESTION: should the fallback value be nil instead of empty string? or should we remove attribute if no value?
          doc.set_attr 'part-title', ((part_info = parts_by_page[pgnum])[:title] || '')
          if (part_numeral = part_info[:numeral])
            doc.set_attr 'part-numeral', part_numeral
          else
            doc.remove_attr 'part-numeral'
          end
          doc.set_attr 'chapter-title', ((chap_info = chapters_by_page[pgnum])[:title] || '')
          if (chap_numeral = chap_info[:numeral])
            doc.set_attr 'chapter-numeral', chap_numeral
          else
            doc.remove_attr 'chapter-numeral'
          end
          doc.set_attr 'section-title', ((sect_info = sections_by_page[pgnum])[:title] || '')
          doc.set_attr 'section-or-chapter-title', (sect_info[:title] || chap_info[:title] || '')

          stamp stamp_names[side] if stamp_names

          canvas do
            bounding_box [trim_styles[:content_left][side], trim_styles[:top][side]], width: trim_styles[:content_width][side], height: trim_styles[:height] do
              theme_font_cascade [periphery, %(#{periphery}_#{side})] do
                if trim_styles[:column_rule_color] && (trim_column_rule_width = trim_styles[:column_rule_width]) > 0
                  trim_column_rule_spacing = trim_styles[:column_rule_spacing]
                else
                  trim_column_rule_width = nil
                end
                prev_position = nil
                ColumnPositions.each do |position|
                  next unless (content = content_by_position[position])
                  next unless (colspec = colspec_by_position[position])[:width] > 0
                  left, colwidth = colspec[:x], colspec[:width]
                  if trim_column_rule_width && colwidth < bounds.width
                    if (trim_column_rule = prev_position)
                      left += (trim_column_rule_spacing * 0.5)
                      colwidth -= trim_column_rule_spacing
                    else
                      colwidth -= (trim_column_rule_spacing * 0.5)
                    end
                  end
                  # FIXME: we need to have a content setting for chapter pages
                  if ::Array === content
                    redo_with_content = nil
                    # NOTE: float ensures cursor position is restored and returns us to current page if we overrun
                    float do
                      # NOTE: bounding_box is redundant if both vertical padding and border width are 0
                      bounding_box [left, bounds.top - trim_styles[:padding][side][0] - trim_styles[:content_offset]], width: colwidth, height: trim_styles[:content_height][side] do
                        # NOTE: image vposition respects padding; use negative image_vertical_align value to revert
                        image_opts = content[1].merge position: colspec[:align], vposition: trim_styles[:img_valign]
                        begin
                          image_info = image content[0], image_opts
                          if (image_link = content[2])
                            image_info = { width: image_info.scaled_width, height: image_info.scaled_height } unless image_opts[:format] == 'svg'
                            add_link_to_image image_link, image_info, image_opts
                          end
                        rescue
                          redo_with_content = image_opts[:alt]
                          log :warn, %(could not embed image in running content: #{content[0]}; #{$!.message})
                        end
                      end
                    end
                    if redo_with_content
                      content_by_position[position] = redo_with_content
                      redo
                    end
                  else
                    theme_font %(#{periphery}_#{side}_#{position}) do
                      # NOTE: minor optimization
                      if content == '{page-number}'
                        content = pagenums_enabled ? pgnum_label : nil
                      else
                        content = apply_subs_discretely doc, content, drop_lines_with_unresolved_attributes: true, imagesdir: @themesdir
                        content = transform_text content, @text_transform if @text_transform
                      end
                      formatted_text_box (parse_text content, inline_format: [normalize: true]),
                        at: [left, bounds.top - trim_styles[:padding][side][0] - trim_styles[:content_offset] + ((Array trim_styles[:valign])[0] == :center ? font.descender * 0.5 : 0)],
                        color: @font_color,
                        width: colwidth,
                        height: trim_styles[:prose_content_height][side],
                        align: colspec[:align],
                        valign: trim_styles[:valign],
                        leading: trim_styles[:line_metrics].leading,
                        final_gap: false,
                        overflow: :truncate
                    end
                  end
                  bounding_box [colspec[:x], bounds.top - trim_styles[:padding][side][0] - trim_styles[:content_offset]], width: colspec[:width], height: trim_styles[:content_height][side] do
                    stroke_vertical_rule trim_styles[:column_rule_color], at: bounds.left, line_style: trim_styles[:column_rule_style], line_width: trim_column_rule_width
                  end if trim_column_rule
                  prev_position = position
                end
              end
            end
          end
        end
        # NOTE: force repeater to consult color spaces on current page instead of the page on which repeater was created
        # if this stops working, use the commented code above repeat call instead
        unless (repeater_graphic_state = repeaters[-1].instance_variable_get :@graphic_state).singleton_methods.include? :color_space
          # NOTE: must convert override method to proc since we're are changing bind argument
          repeater_graphic_state.define_singleton_method :color_space, (method :page_color_space).to_proc
        end
        go_to_page prev_page_number
        nil
      end

      def ink_title_page doc
        # QUESTION: allow alignment per element on title page?
        title_text_align = (@theme.title_page_text_align || @base_text_align).to_sym

        if @theme.title_page_logo_display != 'none' && (logo_image_path = (doc.attr 'title-logo-image') || (logo_image_from_theme = @theme.title_page_logo_image))
          if (logo_image_path.include? ':') && logo_image_path =~ ImageAttributeValueRx
            logo_image_attrs = (::Asciidoctor::AttributeList.new $2).parse %w(alt width height)
            if logo_image_from_theme
              relative_to_imagesdir = false
              logo_image_path = apply_subs_discretely doc, $1, subs: [:attributes], imagesdir: @themesdir
              logo_image_path = ThemeLoader.resolve_theme_asset logo_image_path, @themesdir unless (::File.absolute_path? logo_image_path) || (doc.is_uri? logo_image_path)
            else
              relative_to_imagesdir = true
              logo_image_path = $1
            end
          else
            logo_image_attrs = {}
            relative_to_imagesdir = false
            if logo_image_from_theme
              logo_image_path = apply_subs_discretely doc, logo_image_path, subs: [:attributes], imagesdir: @themesdir
              logo_image_path = ThemeLoader.resolve_theme_asset logo_image_path, @themesdir unless (::File.absolute_path? logo_image_path) || (doc.is_uri? logo_image_path)
            end
          end
          if (::Asciidoctor::Image.target_and_format logo_image_path)[1] == 'pdf'
            log :error, %(PDF format not supported for title page logo image: #{logo_image_path})
          else
            logo_image_attrs['target'] = logo_image_path
            # NOTE: at the very least, title_text_align will be a valid alignment value
            logo_image_attrs['align'] = [(logo_image_attrs.delete 'align'), @theme.title_page_logo_align, title_text_align.to_s].find {|val| (BlockAlignmentNames.include? val) }
            if (logo_image_top = logo_image_attrs['top'] || @theme.title_page_logo_top)
              initial_y, @y = @y, (resolve_top logo_image_top)
            end
            # NOTE: pinned option keeps image on same page
            indent (@theme.title_page_logo_margin_left || 0), (@theme.title_page_logo_margin_right || 0) do
              # FIXME: add API to Asciidoctor for creating blocks outside of extensions
              convert_image (::Asciidoctor::Block.new doc, :image, content_model: :empty, attributes: logo_image_attrs), relative_to_imagesdir: relative_to_imagesdir, pinned: true
            end
            @y = initial_y if initial_y
          end
        end

        theme_font :title_page do
          if (title_top = @theme.title_page_title_top)
            @y = resolve_top title_top
          end
          unless @theme.title_page_title_display == 'none'
            doctitle = doc.doctitle partition: true
            move_down @theme.title_page_title_margin_top || 0
            indent (@theme.title_page_title_margin_left || 0), (@theme.title_page_title_margin_right || 0) do
              theme_font :title_page_title do
                ink_prose doctitle.main, align: title_text_align, margin: 0
              end
            end
            move_down @theme.title_page_title_margin_bottom || 0
          end
          if @theme.title_page_subtitle_display != 'none' && (subtitle = (doctitle || (doc.doctitle partition: true)).subtitle)
            move_down @theme.title_page_subtitle_margin_top || 0
            indent (@theme.title_page_subtitle_margin_left || 0), (@theme.title_page_subtitle_margin_right || 0) do
              theme_font :title_page_subtitle do
                ink_prose subtitle, align: title_text_align, margin: 0
              end
            end
            move_down @theme.title_page_subtitle_margin_bottom || 0
          end
          if @theme.title_page_authors_display != 'none' && (doc.attr? 'authors')
            move_down @theme.title_page_authors_margin_top || 0
            indent (@theme.title_page_authors_margin_left || 0), (@theme.title_page_authors_margin_right || 0) do
              generic_authors_content = @theme.title_page_authors_content
              authors_content = {
                name_only: @theme.title_page_authors_content_name_only || generic_authors_content,
                with_email: @theme.title_page_authors_content_with_email || generic_authors_content,
                with_url: @theme.title_page_authors_content_with_url || generic_authors_content,
              }
              authors = doc.authors.map.with_index do |author, idx|
                with_author doc, author, idx == 0 do
                  author_content_key = (url = doc.attr 'url') ? ((url.start_with? 'mailto:') ? :with_email : :with_url) : :name_only
                  if (author_content = authors_content[author_content_key])
                    apply_subs_discretely doc, author_content, drop_lines_with_unresolved_attributes: true, imagesdir: @themesdir
                  else
                    doc.attr 'author'
                  end
                end
              end.join @theme.title_page_authors_delimiter
              theme_font :title_page_authors do
                ink_prose authors, align: title_text_align, margin: 0, normalize: true
              end
            end
            move_down @theme.title_page_authors_margin_bottom || 0
          end
          if @theme.title_page_revision_display != 'none'
            if (revision_content = @theme.title_page_revision_content)
              revision_content = apply_subs_discretely doc, revision_content, drop_lines_with_unresolved_attributes: true, imagesdir: @themesdir
            else
              delimiters = [', ', ': ']
              if (delimiter_overrides = @theme.title_page_revision_delimiter)
                delimiter_overrides = [delimiter_overrides] unless Array === delimiter_overrides
                delimiters[0..delimiter_overrides.size - 1] = delimiter_overrides
              end
              revision_content = (doc.attr? 'revnumber') ? [([(doc.attr 'version-label'), (doc.attr 'revnumber')].compact.join ' ')] : []
              if doc.attr? 'revdate'
                revision_content << delimiters[0] unless revision_content.empty?
                revision_content << (doc.attr 'revdate')
              end
              if doc.attr? 'revremark'
                revision_content << delimiters[1] unless revision_content.empty?
                revision_content << (doc.attr 'revremark')
              end
              revision_content = revision_content.join
            end
            unless revision_content.empty?
              move_down @theme.title_page_revision_margin_top || 0
              indent (@theme.title_page_revision_margin_left || 0), (@theme.title_page_revision_margin_right || 0) do
                theme_font :title_page_revision do
                  ink_prose revision_content, align: title_text_align, margin: 0, normalize: false
                end
              end
              move_down @theme.title_page_revision_margin_bottom || 0
            end
          end
        end
      end

      def allocate_toc doc, toc_num_levels, toc_start_cursor, break_after_toc
        toc_start_page_number = page_number
        to_page = nil
        extent = dry_run onto: self do
          to_page = (ink_toc doc, toc_num_levels, toc_start_page_number, toc_start_cursor).end
          theme_margin :block, :bottom unless break_after_toc
        end
        # NOTE: patch for custom converters that allocate extra TOC pages without actually creating them
        if to_page > extent.to.page
          extent.to.page = to_page
          extent.to.cursor = bounds.height
        end
        # NOTE: reserve pages for the toc; leaves cursor on page after last page in toc
        if break_after_toc
          extent.each_page { start_new_page }
        else
          extent.each_page {|first_page| start_new_page unless first_page }
          move_cursor_to extent.to.cursor
        end
        extent
      end

      def get_entries_for_toc node
        node.sections
      end

      # NOTE: num_front_matter_pages not used during a dry run
      def ink_toc doc, num_levels, toc_page_number, start_cursor, num_front_matter_pages = 0
        go_to_page toc_page_number unless (page_number == toc_page_number) || scratch?
        start_page_number = page_number
        move_cursor_to start_cursor
        unless (toc_title = doc.attr 'toc-title').nil_or_empty?
          theme_font_cascade [[:heading, level: 2], :toc_title] do
            toc_title_text_align = (@theme.toc_title_text_align || @theme.heading_h2_text_align || @theme.heading_text_align || @base_text_align).to_sym
            ink_general_heading doc, toc_title, align: toc_title_text_align, level: 2, outdent: true, role: :toctitle
          end
        end
        # QUESTION: should we skip this whole method if num_levels < 0?
        unless num_levels < 0
          dot_leader = theme_font :toc do
            # TODO: we could simplify by using nested theme_font :toc_dot_leader
            if (dot_leader_font_style = @theme.toc_dot_leader_font_style&.to_sym || :normal) != font_style
              font_style dot_leader_font_style
            end
            font_size @theme.toc_dot_leader_font_size
            {
              font_color: @theme.toc_dot_leader_font_color || @font_color,
              font_style: dot_leader_font_style,
              font_size: font_size,
              levels: ((dot_leader_l = @theme.toc_dot_leader_levels) == 'none' ? ::Set.new :
                  (dot_leader_l && dot_leader_l != 'all' ? dot_leader_l.to_s.split.map(&:to_i).to_set : nil)),
              text: (dot_leader_text = @theme.toc_dot_leader_content || DotLeaderTextDefault),
              width: dot_leader_text.empty? ? 0 : (rendered_width_of_string dot_leader_text),
              # TODO: spacer gives a little bit of room between dots and page number
              spacer: { text: NoBreakSpace, size: (spacer_font_size = @font_size * 0.25) },
              spacer_width: (rendered_width_of_char NoBreakSpace, size: spacer_font_size),
            }
          end
          theme_margin :toc, :top
          ink_toc_level (get_entries_for_toc doc), num_levels, dot_leader, num_front_matter_pages
        end
        # NOTE: range must be calculated relative to toc_page_number; absolute page number in scratch document is arbitrary
        toc_page_numbers = (toc_page_number..(toc_page_number + (page_number - start_page_number)))
        go_to_page page_count unless scratch?
        toc_page_numbers
      end

      def ink_toc_level entries, num_levels, dot_leader, num_front_matter_pages
        # NOTE: font options aren't always reliable, so store size separately
        toc_font_info = theme_font :toc do
          { font: font, size: @font_size }
        end
        hanging_indent = @theme.toc_hanging_indent
        entries.each do |entry|
          next if (num_levels_for_entry = (entry.attr 'toclevels', num_levels).to_i) < (entry_level = entry.level + 1).pred ||
            ((entry.option? 'notitle') && entry == entry.document.last_child && entry.empty?)
          entry_title = entry.context == :section ? entry.numbered_title : (entry.title? ? entry.title : (entry.xreftext 'basic'))
          next if entry_title.empty?
          theme_font :toc, level: entry_level do
            entry_title = entry_title.gsub DropAnchorRx, '' if entry_title.include? '<a'
            entry_title = transform_text entry_title, @text_transform if @text_transform
            pgnum_label_placeholder_width = rendered_width_of_string '0' * @toc_max_pagenum_digits
            # NOTE: only write title (excluding dots and page number) if this is a dry run
            if scratch?
              indent 0, pgnum_label_placeholder_width do
                # NOTE: must wrap title in empty anchor element in case links are styled with different font family / size
                ink_prose entry_title, anchor: true, normalize: false, hanging_indent: hanging_indent, normalize_line_height: true, margin: 0
              end
            else
              entry_anchor = (entry.attr 'pdf-anchor') || entry.id
              if !(physical_pgnum = entry.attr 'pdf-page-start') &&
                  (target_page_ref = (get_dest entry_anchor)&.first) &&
                  (target_page_idx = state.pages.index {|candidate| candidate.dictionary == target_page_ref })
                physical_pgnum = target_page_idx + 1
              end
              if physical_pgnum
                virtual_pgnum = physical_pgnum - num_front_matter_pages
                pgnum_label = (virtual_pgnum < 1 ? (RomanNumeral.new physical_pgnum, :lower) : virtual_pgnum).to_s
              else
                pgnum_label = '?'
              end
              start_page_number = page_number
              start_cursor = cursor
              start_dots = nil
              entry_title_inherited = (apply_text_decoration ::Set.new, :toc, entry_level).merge anchor: entry_anchor, color: @font_color
              # NOTE: use text formatter to add anchor overlay to avoid using inline format with synthetic anchor tag
              entry_title_fragments = text_formatter.format entry_title, inherited: entry_title_inherited
              line_metrics = calc_line_metrics @base_line_height
              indent 0, pgnum_label_placeholder_width do
                fragment_positions = []
                entry_title_fragments.each do |fragment|
                  fragment_positions << (fragment_position = ::Asciidoctor::PDF::FormattedText::FragmentPositionRenderer.new)
                  (fragment[:callback] ||= []) << fragment_position
                end
                typeset_formatted_text entry_title_fragments, line_metrics, hanging_indent: hanging_indent, normalize_line_height: true
                break unless (last_fragment_position = fragment_positions.select(&:page_number)[-1])
                start_dots = last_fragment_position.right + hanging_indent
                last_fragment_cursor = last_fragment_position.top + line_metrics.padding_top
                start_cursor = last_fragment_cursor if last_fragment_position.page_number > start_page_number || (start_cursor - last_fragment_cursor) > line_metrics.height
              end
              # NOTE: this will leave behind a gap where this entry would have been
              break unless start_dots
              end_cursor = cursor
              move_cursor_to start_cursor
              # NOTE: we're guaranteed to be on the same page as the final line of the entry
              if dot_leader[:width] > 0 && (dot_leader[:levels] ? (dot_leader[:levels].include? entry_level.pred) : true)
                pgnum_label_width = rendered_width_of_string pgnum_label
                pgnum_label_font_settings = { color: @font_color, font: font_family, size: @font_size, styles: font_styles }
                save_font do
                  # NOTE: the same font is used for dot leaders throughout toc
                  set_font toc_font_info[:font], dot_leader[:font_size]
                  font_style dot_leader[:font_style]
                  num_dots = [((bounds.width - start_dots - dot_leader[:spacer_width] - pgnum_label_width) / dot_leader[:width]).floor, 0].max
                  # FIXME: dots don't line up in columns if width of page numbers differ
                  typeset_formatted_text [
                    { text: dot_leader[:text] * num_dots, color: dot_leader[:font_color] },
                    dot_leader[:spacer],
                    ({ text: pgnum_label, anchor: entry_anchor }.merge pgnum_label_font_settings),
                  ], line_metrics, align: :right
                end
              else
                typeset_formatted_text [{ text: pgnum_label, color: @font_color, anchor: entry_anchor }], line_metrics, align: :right
              end
              move_cursor_to end_cursor
            end
          end
          indent @theme.toc_indent do
            ink_toc_level (get_entries_for_toc entry), num_levels_for_entry, dot_leader, num_front_matter_pages
          end if num_levels_for_entry >= entry_level
        end
      end

      # Retrieve the intrinsic image dimensions for the specified path in pt.
      #
      # Returns a Hash containing :width and :height keys that map to the image's
      # intrinsic width and height values (in pt).
      def intrinsic_image_dimensions path, format
        if format == 'svg'
          # NOTE: prawn-svg automatically converts intrinsic width and height to pt
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
        # NOTE: image can't be read, so it won't be used anyway
        { width: 0, height: 0 }
      end

      def intrinsic_image_width path, format
        (intrinsic_image_dimensions path, format)[:width]
      end

      # Sends the specified message to the log unless this method is called from the scratch document
      def log severity, message = nil, &block
        logger.send severity, message, &block unless scratch?
      end

      # Insert a margin at the specified side if the cursor is not at the top of
      # the page. Start a new page if amount is greater than the remaining space on
      # the page.
      def margin amount, _side
        if (amount || 0) == 0 || at_page_top?
          0
        elsif cursor > amount
          move_down amount
          amount
        else
          # move cursor to top of next page
          bounds.move_past_bottom
          0
        end
      end

      # Insert a bottom margin equal to amount unless cursor is at the top of the
      # page (not likely). Start a new page instead if amount is greater than the
      # remaining space on the page.
      def margin_bottom amount
        margin amount, :bottom
      end

      # Insert a top margin equal to amount if cursor is not at the top of the
      # page. Start a new page instead if amount is greater than the remaining
      # space on the page.
      def margin_top amount
        margin amount, :top
      end

      def next_enclosed_block block, descend: false
        return if (context = block.context) == :document
        parent_context = (parent = block.parent).context
        if (list_item = context == :list_item)
          return block.first_child if descend && block.blocks?
          siblings = parent.items
        else
          siblings = parent.blocks
        end
        siblings = siblings.flatten if parent_context == :dlist
        if block != siblings[-1]
          context == :open && block.style == 'table-container' ?
            (next_enclosed_block parent) :
            (self_idx = siblings.index block) && siblings[self_idx + 1]
        elsif parent_context == :list_item || (parent_context == :open && parent.style != 'abstract') || parent_context == :section
          next_enclosed_block parent
        elsif list_item && (grandparent = parent.parent).context == :list_item
          next_enclosed_block grandparent
        end
      end

      def register_fonts font_catalog, fonts_dir
        return unless font_catalog
        dirs = (fonts_dir.split ValueSeparatorRx, -1).map {|dir| dir == 'GEM_FONTS_DIR' || dir.empty? ? ThemeLoader::FontsDir : dir }
        font_catalog.each do |key, styles|
          register_font key => ({}.tap do |accum|
            styles.each do |style, path|
              found = dirs.any? do |dir|
                resolved_font_path = font_path path, dir
                accum[style.to_sym] = resolved_font_path if ::File.readable? resolved_font_path
              end
              raise ::Errno::ENOENT, ((File.absolute_path? path) ? %(#{path} not found) : %(#{path} not found in #{fonts_dir.gsub ValueSeparatorRx, ' or '})) unless found
            end
          end)
        end
      end

      # Compute the rendered width of a char, taking fallback fonts into account
      def rendered_width_of_char char, opts = {}
        unless @fallback_fonts.empty? || (font.glyph_present? char)
          @fallback_fonts.each do |fallback_font|
            font fallback_font do
              return width_of_string char, opts if font.glyph_present? char
            end
          end
        end
        width_of_string char, opts
      end

      # Compute the rendered width of a string, taking fallback fonts into account
      def rendered_width_of_string str, opts = {}
        opts = opts.merge kerning: default_kerning?
        if str.length == 1
          rendered_width_of_char str, opts
        elsif (chars = str.each_char).all? {|char| font.glyph_present? char }
          width_of_string str, opts
        else
          char_widths = chars.map {|char| rendered_width_of_char char, opts }
          char_widths.sum + (char_widths.length * character_spacing)
        end
      end

      # Resolve the path and sizing of the background image either from a document attribute or theme key.
      #
      # Returns the argument list for the image method if the document attribute or theme key is found. Otherwise,
      # nothing. The first argument in the argument list is the image path. If that value is nil, the background
      # image is disabled. The second argument is the options hash to specify the dimensions, such as width and fit.
      def resolve_background_image doc, theme, key, opts = {}
        if ::String === key
          theme_key = opts.delete :theme_key
          image_path = (doc.attr key) || (from_theme = theme[theme_key || (key.tr '-', '_').to_sym])
        else
          image_path = from_theme = theme[key]
        end
        symbolic_paths = opts.delete :symbolic_paths
        return unless image_path
        return [image_path, {}] if symbolic_paths&.include? image_path
        return [] if image_path == 'none' || image_path == ''
        if (image_path.include? ':') && image_path =~ ImageAttributeValueRx
          image_attrs = (::Asciidoctor::AttributeList.new $2).parse %w(alt width)
          image_path = $1
          image_relative_to = true
        end
        if from_theme
          image_path = apply_subs_discretely doc, image_path, subs: [:attributes], imagesdir: (image_relative_to = @themesdir), page_layout: page.layout.to_s
        elsif image_path.include? '{page-layout}'
          image_path = image_path.sub '{page-layout}', page.layout.to_s
        end
        image_path, image_format = ::Asciidoctor::Image.target_and_format image_path, image_attrs
        image_path = resolve_image_path doc, image_path, image_format, image_relative_to

        return unless image_path

        unless ::File.readable? image_path
          log :warn, %(#{key.to_s.tr '-_', ' '} not found or readable: #{image_path})
          return
        end

        if image_format == 'pdf'
          [image_path, page: [image_attrs&.[]('page').to_i, 1].max, format: image_format]
        else
          [image_path, (resolve_image_options image_path, image_format, image_attrs, (({ background: true, container_size: [page_width, page_height] }.merge opts)))]
        end
      end

      def resolve_doctitle doc, partition = nil
        if doc.header?
          doc.doctitle partition: partition
        elsif partition
          ::Asciidoctor::Document::Title.new (doc.attr 'untitled-label'), separator: (doc.attr 'title-separator')
        else
          doc.attr 'untitled-label'
        end
      end

      # Resolves the explicit width, if specified, as a PDF pt value.
      #
      # Resolves the explicit width, first considering the pdfwidth attribute, then the scaledwidth
      # attribute, then the theme default (if enabled by the :use_fallback option), and finally the
      # width attribute. If the specified value is in pixels, the value is scaled by 75% to perform
      # approximate CSS px to PDF pt conversion. If the value is a percentage, and the
      # bounds_width option is given, the percentage of the bounds_width value is returned.
      # Otherwise, the percentage width is returned.
      #--
      # QUESTION: should we enforce positive result?
      def resolve_explicit_width attrs, opts = {}
        bounds_width = opts[:bounds_width]
        # QUESTION: should we restrict width to bounds_width for pdfwidth?
        if attrs.key? 'pdfwidth'
          if (width = attrs['pdfwidth']).end_with? '%'
            bounds_width ? (width.to_f / 100) * bounds_width : width
          elsif width.end_with? 'iw'
            (width.chomp 'iw').extend ImageWidth
          elsif opts[:support_vw] && (width.end_with? 'vw')
            (width.chomp 'vw').extend ViewportWidth
          else
            str_to_pt width
          end
        elsif attrs.key? 'scale'
          (attrs['scale'] + '').extend ImageWidth
        elsif attrs.key? 'scaledwidth'
          # NOTE: the parser automatically appends % if value is unitless
          if (width = attrs['scaledwidth']).end_with? '%'
            bounds_width ? (width.to_f / 100) * bounds_width : width
          else
            str_to_pt width
          end
        elsif opts[:use_fallback] && (width = @theme.image_width)
          if ::Numeric === width
            width
          elsif (width = width.to_s).end_with? '%'
            bounds_width ? (width.to_f / 100) * bounds_width : bounds_width
          elsif opts[:support_vw] && (width.end_with? 'vw')
            (width.chomp 'vw').extend ViewportWidth
          else
            str_to_pt width
          end
        elsif attrs.key? 'width'
          if (width = attrs['width']).end_with? '%'
            width = (width.to_f / 100) * bounds_width if bounds_width
          elsif DigitsRx.match? width
            width = to_pt width.to_f, :px
          else
            return
          end
          bounds_width && opts[:constrain_to_bounds] ? [bounds_width, width].min : width
        end
      end

      def resolve_image_options image_path, image_format, image_attrs, opts = {}
        if image_format == 'svg'
          image_opts = {
            enable_file_requests_with_root: { base: (::File.dirname image_path), root: @jail_dir },
            enable_web_requests: allow_uri_read ? (method :load_open_uri).to_proc : false,
            cache_images: cache_uri,
            fallback_font_name: fallback_svg_font_name,
            format: 'svg',
          }
        else
          image_opts = {}
        end
        container_size = opts[:container_size]
        if image_attrs
          if (alt = image_attrs['alt'])
            image_opts[:alt] = %([#{alt}])
          end
          if (background = opts[:background]) && (image_pos = image_attrs['position']) && (image_pos = resolve_background_position image_pos, nil)
            image_opts.update image_pos
          end
          if (image_fit = image_attrs['fit'] || (background ? 'contain' : nil))
            image_fit = 'contain' if image_format == 'svg' && image_fit == 'fill'
            container_width, container_height = container_size
            case image_fit
            when 'none'
              if (image_width = resolve_explicit_width image_attrs, bounds_width: container_width)
                image_opts[:width] = image_width
              end
            when 'scale-down'
              # NOTE: if width and height aren't set in SVG, real width and height are computed after stretching viewbox to fit page
              if (image_width = resolve_explicit_width image_attrs, bounds_width: container_width)
                if image_width > container_width
                  image_opts[:fit] = container_size
                else
                  image_size = intrinsic_image_dimensions image_path, image_format
                  if image_width * (image_size[:height].to_f / image_size[:width]) > container_height
                    image_opts[:fit] = container_size
                  else
                    image_opts[:width] = image_width
                  end
                end
              else
                image_size = intrinsic_image_dimensions image_path, image_format
                image_opts[:fit] = container_size if image_size[:width] > container_width || image_size[:height] > container_height
              end
            when 'cover'
              # QUESTION: should we take explicit width into account?
              image_size = intrinsic_image_dimensions image_path, image_format
              if container_width * (image_size[:height].to_f / image_size[:width]) < container_height
                image_opts[:height] = container_height
              else
                image_opts[:width] = container_width
              end
            when 'fill'
              image_opts[:width] = container_width
              image_opts[:height] = container_height
            else # 'contain'
              image_opts[:fit] = container_size
            end
          elsif (image_width = resolve_explicit_width image_attrs, bounds_width: container_size[0])
            image_opts[:width] = image_width
          else # default to fit=contain if sizing is not specified
            image_opts[:fit] = container_size
          end
        else
          image_opts[:fit] = container_size
        end
        image_opts
      end

      # Resolve the system path of the specified image path.
      #
      # Resolve and normalize the absolute system path of the specified image,
      # taking into account the imagesdir attribute. If an image path is not
      # specified, the path is read from the target attribute of the specified
      # document node.
      #
      # If the target is a URI and the allow-uri-read attribute is set on the
      # document, read the file contents to a temporary file and return the path to
      # the temporary file. If the target is a URI and the allow-uri-read attribute
      # is not set, or the URI cannot be read, this method returns a nil value.
      #
      # When a temporary file is used, the file is stored in @tmp_files to be cleaned up after conversion.
      def resolve_image_path node, image_path, image_format, relative_to = true
        doc = node.document
        if relative_to == true
          imagesdir = nil if (imagesdir = doc.attr 'imagesdir').nil_or_empty? || imagesdir == '.' || imagesdir == './'
        else
          imagesdir = relative_to
        end
        # NOTE: base64 logic currently used for inline images
        if ::Asciidoctor::Image::Base64Encoded === image_path
          return @tmp_files[image_path] if @tmp_files.key? image_path
          tmp_image = ::Tempfile.create %W(image- .#{image_format})
          tmp_image.binmode unless image_format == 'svg'
          tmp_image.write image_path.unpack1 'm'
          tmp_image.close
          @tmp_files[image_path] = tmp_image.path
        # NOTE: this will catch a classloader resource path on JRuby (e.g., uri:classloader:/path/to/image)
        elsif ::File.absolute_path? image_path
          ::File.absolute_path image_path
        elsif !(is_url = url? image_path) && imagesdir && (::File.absolute_path? imagesdir)
          ::File.absolute_path image_path, imagesdir
        # handle case when image is a URI
        elsif is_url || (imagesdir && (url? imagesdir) && (image_path = node.normalize_web_path image_path, imagesdir, false))
          if !allow_uri_read
            log :warn, %(cannot embed remote image: #{image_path} (allow-uri-read attribute not enabled))
            return
          elsif @tmp_files.key? image_path
            return @tmp_files[image_path]
          end
          tmp_image = ::Tempfile.create ['image-', image_format && %(.#{image_format})]
          tmp_image.binmode if (binary = image_format != 'svg')
          begin
            load_open_uri.open_uri(image_path, (binary ? 'rb' : 'r')) {|fd| tmp_image.write fd.read }
            tmp_image.close
            @tmp_files[image_path] = tmp_image.path
          rescue
            @tmp_files[image_path] = nil
            log :warn, %(could not retrieve remote image: #{image_path}; #{$!.message})
            tmp_image.close
            unlink_tmp_file tmp_image.path
            nil
          end
        # handle case when image is a local file
        else
          node.normalize_system_path image_path, imagesdir, nil, target_name: 'image'
        end
      end

      def resolve_page_margin value
        return if value.nil_or_empty?
        case value
        when ::Array
          value = value.slice 0, 4 if value.length > 4
          value.map {|v| ::Numeric === v ? v : (str_to_pt v.to_s) }
        when ::Numeric
          [value]
        when ::String
          if (value.start_with? '[') && (value.end_with? ']')
            return if (value = (value.slice 1, value.length - 2).rstrip).empty?
            if (value = value.split ',', -1).length > 4
              value = value.slice 0, 4
            end
            value.map {|v| str_to_pt v.rstrip }
          else
            [(str_to_pt value)]
          end
        end
      end

      def resolve_text_align_from_role roles, query_theme: false, remove_predefined: false
        if (align_role = roles.reverse.find {|role| TextAlignmentRoles[role] })
          roles.replace roles - TextAlignmentRoles.keys if remove_predefined
          (align_role.slice 5, align_role.length).to_sym
        elsif query_theme
          roles.reverse.each do |role|
            if (text_align = @theme[%(role_#{role}_text_align)])
              return text_align.to_sym
            end
          end
          nil
        end
      end

      # Deprecated
      alias resolve_alignment_from_role resolve_text_align_from_role

      def stamp_foreground_image doc, has_front_cover
        pages = state.pages
        if (first_page = (has_front_cover ? (pages.drop 1) : pages).find {|it| !it.imported_page? }) &&
            (first_page_num = (pages.index first_page) + 1) &&
            (fg_image = resolve_background_image doc, @theme, 'page-foreground-image') && fg_image[0]
          stamps = ::Set.new
          (first_page_num..page_count).each do |num|
            go_to_page num
            next if page.imported_page?
            unless stamps.include? (stamp_name = %(foreground-image-#{page.layout}))
              create_stamp stamp_name do
                canvas { image fg_image[0], ({ position: :center, vposition: :center }.merge fg_image[1]) }
              end
              stamps << stamp_name
            end
            stamp stamp_name
          end
        end
      end

      def start_new_chapter chapter
        start_new_page unless at_page_top?
        start_new_page if @ppbook && verso_page? && !(chapter.option? 'nonfacing')
      end

      alias start_new_part start_new_chapter

      # Returns a Boolean indicating whether the title page was created
      def start_title_page doc
        return unless doc.header? && !doc.notitle && @theme.title_page != false

        # NOTE: a new page may have already been started at this point, so decide what to do with it
        if page.empty?
          page.reset_content if (recycle = @ppbook ? recto_page? : true)
        elsif @ppbook && page_number > 0 && recto_page?
          start_new_page
        end
        if (bg_image = resolve_background_image doc, @theme, 'title-page-background-image')
          side = page_side (recycle ? nil : page_number + 1), @folio_placement[:inverted]
          prev_bg_image = get_page_bg_image doc, @theme, (layout = page.layout), side
          @page_bg_image[layout][side] = bg_image[0] && bg_image
        end
        if (bg_color = resolve_theme_color :title_page_background_color)
          prev_bg_color = @page_bg_color
          @page_bg_color = bg_color
        end
        recycle ? float { init_page doc, self } : start_new_page
        @page_bg_image[layout][side] = prev_bg_image if bg_image
        @page_bg_color = prev_bg_color if bg_color
        true
      end

      def start_toc_page node, placement
        start_new_page unless at_page_top?
        start_new_page if @ppbook && verso_page? && !(placement == 'macro' && (node.option? 'nonfacing'))
      end

      def supports_float_wrapping? node
        node.context == :paragraph
      end

      def theme_fill_and_stroke_block category, extent, opts = {}
        node_with_caption = nil unless (node_with_caption = opts[:caption_node])&.title?
        unless extent
          ink_caption node_with_caption, category: category if node_with_caption
          return
        end
        if (b_width = (opts.key? :border_width) ? opts[:border_width] : @theme[%(#{category}_border_width)])
          if ::Array === b_width
            b_width = b_width[0]
            b_radius = 0
          end
          b_width = nil unless b_width.to_f > 0
        end
        if (bg_color = opts[:background_color] || @theme[%(#{category}_background_color)]) == 'transparent'
          bg_color = nil
        end
        unless b_width || bg_color
          ink_caption node_with_caption, category: category if node_with_caption
          return
        end
        b_color = resolve_theme_color %(#{category}_border_color).to_sym, @theme.base_border_color, @page_bg_color
        b_radius ||= (@theme[%(#{category}_border_radius)] || 0) + (b_width || 0)
        if b_width
          if b_color == @page_bg_color # let page background cut into block background
            b_gap_color, b_shift = @page_bg_color, (b_width * 0.5)
          elsif (b_gap_color = bg_color) && b_gap_color != b_color
            b_shift = 0
          else # let page background cut into border
            b_gap_color, b_shift = @page_bg_color, 0
          end
        else # let page background cut into block background; guarantees b_width is set
          b_shift, b_gap_color = (b_width ||= 0.5) * 0.5, @page_bg_color
        end
        ink_caption node_with_caption, category: category if node_with_caption
        extent.from.page = page_number unless extent.from.page == page_number # sanity check
        float do
          extent.each_page do |first_page, last_page|
            advance_page unless first_page
            chunk_height = start_cursor = cursor
            chunk_height -= last_page.cursor if last_page
            bounding_box [bounds.left, start_cursor], width: bounds.width, height: chunk_height do
              theme_fill_and_stroke_bounds category, background_color: bg_color
              unless first_page
                indent b_radius, b_radius do
                  # dashed line indicates continuation from previous page; swell line slightly to cover background
                  stroke_horizontal_rule b_gap_color, line_width: b_width * 1.2, line_style: :dashed, at: b_shift
                end
              end
              unless last_page
                move_down chunk_height
                indent b_radius, b_radius do
                  # dashed line indicates continuation from previous page; swell line slightly to cover background
                  stroke_horizontal_rule b_gap_color, line_width: b_width * 1.2, line_style: :dashed, at: -b_shift
                end
              end
            end
          end
        end
        nil
      end

      def theme_fill_and_stroke_bounds category, opts = {}
        fill_and_stroke_bounds opts[:background_color], @theme[%(#{category}_border_color)] || @theme.base_border_color,
          line_width: @theme[%(#{category}_border_width)],
          line_style: (@theme[%(#{category}_border_style)]&.to_sym || :solid),
          radius: @theme[%(#{category}_border_radius)]
      end

      def theme_font category, opts = {}
        # TODO: inheriting from generic category should be an option
        if opts.key? :level
          hlevel_category = %(#{category}_h#{opts[:level]})
          family = @theme[%(#{hlevel_category}_font_family)] || @theme[%(#{category}_font_family)] || @theme.base_font_family || font_family
          if (size = @theme[%(#{hlevel_category}_font_size)] || @theme[%(#{category}_font_size)])
            scale = @font_scale unless ::String === size
          else
            scale = @font_scale
            size = @root_font_size
          end
          style = @theme[%(#{hlevel_category}_font_style)] || @theme[%(#{category}_font_style)]
          color = @theme[%(#{hlevel_category}_font_color)] || @theme[%(#{category}_font_color)]
          kerning = resolve_font_kerning @theme[%(#{hlevel_category}_font_kerning)] || @theme[%(#{category}_font_kerning)]
          line_height = @theme[%(#{hlevel_category}_line_height)] || @theme[%(#{category}_line_height)]
          # NOTE: global text_transform is not currently supported
          transform = @theme[%(#{hlevel_category}_text_transform)] || @theme[%(#{category}_text_transform)]
        else
          inherited_font = font_info
          family = @theme[%(#{category}_font_family)] || inherited_font[:family]
          if (size = @theme[%(#{category}_font_size)])
            scale = @font_scale unless ::String === size
          else
            size = inherited_font[:size]
          end
          style = @theme[%(#{category}_font_style)] || inherited_font[:style]
          color = @theme[%(#{category}_font_color)]
          kerning = resolve_font_kerning @theme[%(#{category}_font_kerning)]
          line_height = @theme[%(#{category}_line_height)]
          # NOTE: global text_transform is not currently supported
          transform = @theme[%(#{category}_text_transform)]
        end

        prev_color, @font_color = @font_color, color if color
        prev_kerning, self.default_kerning = default_kerning?, kerning unless kerning.nil?
        prev_line_height, @base_line_height = @base_line_height, line_height if line_height
        prev_transform, @text_transform = @text_transform, (transform == 'none' ? nil : transform) if transform

        result = nil
        font family, size: size, style: style&.to_sym do
          @font_size *= scale if scale
          result = yield
        ensure
          @font_color = prev_color if color
          default_kerning prev_kerning unless kerning.nil?
          @base_line_height = prev_line_height if line_height
          @text_transform = prev_transform if transform
        end
        result
      end

      def theme_font_cascade categories, &block
        if ::Array === (category = (categories = categories.uniq).shift)
          category, opts = category
        else
          opts = {}
        end
        if categories.empty?
          theme_font category, opts, &block
        else
          theme_font category, opts do
            theme_font_cascade categories, &block
          end
        end
      end

      # Lookup margin for theme element and side, then delegate to margin method.
      # If margin value is not found, assume 0.
      def theme_margin category, side, node = true
        if node
          category = :block if node != true && node.context == :section
          margin (@theme[%(#{category}_margin_#{side})] || 0), side
        else
          0
        end
      end

      # TODO: document me, esp the first line formatting functionality
      # NOTE: single_line option should only be used if height option is specified
      def typeset_text string, line_metrics, opts = {}
        opts = { leading: line_metrics.leading, final_gap: line_metrics.final_gap }.merge opts
        string = string.gsub CjkLineBreakRx, ZeroWidthSpace if @cjk_line_breaks
        return text_box string, opts if opts[:height]
        opts[:initial_gap] = line_metrics.padding_top
        if (hanging_indent = (opts.delete :hanging_indent) || 0) > 0
          indent hanging_indent do
            text string, (opts.merge indent_paragraphs: -hanging_indent)
          end
        elsif (first_line_opts = opts.delete :first_line_options)
          # TODO: good candidate for Prawn enhancement!
          text_with_formatted_first_line string, first_line_opts, opts
        else
          text string, opts
        end
        move_down line_metrics.padding_bottom
      end

      # QUESTION: combine with typeset_text?
      def typeset_formatted_text fragments, line_metrics, opts = {}
        opts = { leading: line_metrics.leading, initial_gap: line_metrics.padding_top, final_gap: line_metrics.final_gap }.merge opts
        fragments = consolidate_fragments fragments if opts.delete :consolidate
        if (hanging_indent = (opts.delete :hanging_indent) || 0) > 0
          indent hanging_indent do
            formatted_text fragments, (opts.merge indent_paragraphs: -hanging_indent)
          end
        else
          formatted_text fragments, opts
        end
        move_down line_metrics.padding_bottom
      end

      def write pdf_doc, target
        if target.respond_to? :write
          target = ::QuantifiableStdout.new $stdout if target == $stdout
          pdf_doc.render target
        else
          pdf_doc.render_file target
          # QUESTION: restore attributes first?
          @pdfmark&.generate_file target
          if (optimize = @optimize)
            (@optimize[:optimizer].new optimize[:quality], pdf_doc.min_version, optimize[:compliance]).optimize_file target
          end
          to_file = true
        end
        if !ENV['KEEP_ARTIFACTS']
          remove_tmp_files
        elsif to_file
          scratch_target = (target.slice 0, target.length - (target_ext = ::File.extname target).length) + '-scratch' + target_ext
          scratch.render_file scratch_target
        end
        clear_scratch
        nil
      end

      # Deprecated method names
      alias layout_footnotes ink_footnotes
      alias layout_title_page ink_title_page
      alias layout_cover_page ink_cover_page
      alias layout_chapter_title ink_chapter_title
      alias layout_part_title ink_part_title
      alias layout_general_heading ink_general_heading
      alias layout_heading ink_heading
      alias layout_prose ink_prose
      alias layout_caption ink_caption
      alias layout_table_caption ink_table_caption
      alias layout_toc ink_toc
      alias layout_toc_level ink_toc_level
      alias layout_running_content ink_running_content

      # intercepts "class CustomPDFConverter < (Asciidoctor::Converter.for 'pdf')"
      def self.method_added method_sym
        if (method_name = method_sym.to_s).start_with? 'layout_'
          alias_method %(ink_#{method_name.slice 7, method_name.length}).to_sym, method_sym
        elsif method_name == 'convert_listing_or_literal' || method_name == 'convert_code'
          alias_method :convert_listing, method_sym
          alias_method :convert_literal, method_sym
        end
      end

      # intercepts "(Asciidoctor::Converter.for 'pdf').prepend CustomConverterExtensions"
      def self.prepend *mods
        super
        mods.each {|mod| (mod.instance_methods false).each {|method| method_added method } }
        self
      end

      private

      def add_dest_for_top doc
        unless (top_page = doc.attr 'pdf-page-start') > page_count
          float do
            go_to_page top_page
            move_cursor_to bounds.top + page_margin_top
            add_dest_for_block doc, id: (doc.attr 'pdf-anchor')
          end
        end
        nil
      end

      def add_link_to_image uri, image_info, image_opts
        image_width = image_info[:width]
        image_height = image_info[:height]

        case image_opts[:position]
        when :center
          image_x = bounds.left_side + (bounds.width - image_width) * 0.5
        when :right
          image_x = bounds.right_side - image_width
        else # :left, nil
          image_x = bounds.left_side
        end

        case image_opts[:vposition]
        when :top
          image_y = bounds.absolute_top
        when :center
          image_y = bounds.absolute_top - (bounds.height - image_height) * 0.5
        when :bottom
          image_y = bounds.absolute_bottom + image_height
        else
          image_y = y - image_opts[:vposition]
        end unless (image_y = image_opts[:y])

        link_annotation [image_x, (image_y - image_height), (image_x + image_width), image_y], Border: [0, 0, 0], A: { Type: :Action, S: :URI, URI: uri.as_pdf }
      end

      def admonition_icon_data key
        if (icon_data = @theme[%(admonition_icon_#{key})])
          icon_data = (AdmonitionIcons[key]&.merge icon_data) || icon_data
          if (icon_name = icon_data[:name])
            unless icon_name.start_with?(*IconSetPrefixes)
              log(:info) { %(#{key} admonition in theme uses icon from deprecated fa icon set; use fas, far, or fab instead) }
              icon_data[:name] = %(fa-#{icon_name}) unless icon_name.start_with? 'fa-'
            end
          else
            icon_data[:name] = AdmonitionIcons[:note][:name]
          end
        else
          (icon_data = AdmonitionIcons[key] || {})[:name] ||= AdmonitionIcons[:note][:name]
        end
        icon_data
      end

      def allocate_space_for_list_item line_metrics
        advance_page if !at_page_top? && cursor < line_metrics.height + line_metrics.leading + line_metrics.padding_top
      end

      def apply_text_decoration styles, category, level = nil
        if (text_decoration_style = TextDecorationStyleTable[level && @theme[%(#{category}_h#{level}_text_decoration)] || @theme[%(#{category}_text_decoration)]])
          {
            styles: (styles << text_decoration_style),
            text_decoration_color: level && @theme[%(#{category}_h#{level}_text_decoration_color)] || @theme[%(#{category}_text_decoration_color)],
            text_decoration_width: level && @theme[%(#{category}_h#{level}_text_decoration_width)] || @theme[%(#{category}_text_decoration_width)],
          }.compact
        else
          styles.empty? ? {} : { styles: styles }
        end
      end

      # Arrange fragments by line in an arranger and return an unfinalized arranger.
      #
      # Finalizing the arranger is deferred since it must be done in the context of
      # the global font settings you want applied to each fragment.
      def arrange_fragments_by_line fragments, _opts = {}
        arranger = ::Prawn::Text::Formatted::Arranger.new self
        by_line = arranger.consumed = []
        fragments.each do |fragment|
          if (text = fragment[:text]) == LF || !(text.include? LF)
            by_line << fragment
          else
            text.scan LineScanRx do |line|
              by_line << (line == LF ? { text: LF } : (fragment.merge text: line))
            end
          end
        end
        arranger
      end

      # NOTE: assume URL is escaped (i.e., contains character references such as &amp;)
      def breakable_uri uri
        scheme, address = uri.split UriSchemeBoundaryRx, 2
        address, scheme = scheme, address unless address
        unless address.nil_or_empty?
          address = address.gsub UriBreakCharsRx, UriBreakCharRepl
          # NOTE: require at least two characters after a break
          address.slice!(-2) if address[-2] == ZeroWidthSpace
        end
        %(#{scheme}#{address})
      end

      # Calculate the font size (down to the minimum font size) that would allow
      # all the specified fragments to fit in the available width without wrapping lines.
      #
      # Return the calculated font size if an adjustment is necessary or nil if no
      # font size adjustment is necessary.
      def compute_autofit_font_size fragments, category
        arranger = arrange_fragments_by_line fragments
        # NOTE: finalizing the line here generates fragments & calculates their widths using the current font settings
        # NOTE: it also removes zero-width spaces
        arranger.finalize_line
        actual_width = width_of_fragments arranger.fragments
        padding = expand_padding_value @theme[%(#{category}_padding)]
        if actual_width > (available_width = bounds.width - padding[3].to_f - padding[1].to_f)
          adjusted_font_size = ((available_width * font_size).to_f / actual_width).truncate 4
          if (min = @theme[%(#{category}_font_size_min)] || @theme.base_font_size_min) && adjusted_font_size < (min = resolve_font_size min)
            min
          else
            adjusted_font_size
          end
        end
      end

      def resolve_font_size value
        return value unless ::String === value
        if value.end_with? 'rem'
          @root_font_size * value.to_f
        elsif value.end_with? 'em'
          font_size * value.to_f
        elsif value.end_with? '%'
          font_size * (value.to_f / 100)
        else
          value.to_f
        end
      end

      def consolidate_ranges nums
        if nums.size > 1
          prev = nil
          accum = []
          nums.each do |num|
            if prev && (prev.to_i + 1) == num.to_i
              accum[-1][1] = num
            else
              accum << [num]
            end
            prev = num
          end
          accum.map {|range| range.join '-' }
        else
          nums
        end
      end

      def consolidate_fragments fragments
        return fragments unless fragments.size > 1
        accum = []
        prev_fragment = nil
        fragments.each do |fragment|
          if prev_fragment && fragment == (prev_fragment.merge text: (fragment_text = fragment[:text]))
            prev_fragment[:text] += fragment_text
          else
            accum << (prev_fragment = fragment)
          end
        end
        accum
      end

      def conum_glyph number
        @conum_glyphs[number - 1]
      end

      # Derive a PDF-safe, ASCII-only anchor name from the given value.
      # Encodes value into hex if it contains characters outside the ASCII range.
      # If value is nil, derive an anchor name from the default_value, if given.
      def derive_anchor_from_id value, default_value = nil
        if value
          value.ascii_only? ? value : %(0x#{::PDF::Core.string_to_hex value})
        else
          %(__anchor-#{default_value})
        end
      end

      def draw_image_border top, w, h, alignment
        if (Array @theme.image_border_width).any? {|it| it&.> 0 } && (@theme.image_border_color || @theme.base_border_color)
          if (@theme.image_border_fit || 'content') == 'auto'
            bb_width = bounds.width
          elsif alignment == :center
            bb_x = (bounds.width - w) * 0.5
          elsif alignment == :right
            bb_x = bounds.width - w
          end
          bounding_box [(bb_x || 0), top], width: (bb_width || w), height: h, position: alignment do
            theme_fill_and_stroke_bounds :image
          end
          true
        end
      end

      # Reduce icon height to fit inside bounds.height. Icons will not render
      # properly if they are larger than the current bounds.height.
      def fit_icon_to_bounds preferred_size
        (max_height = bounds.height) < preferred_size ? max_height : preferred_size
      end

      def fit_trim_box page_ = page
        page_.dictionary.data[:TrimBox].tap do |trim_box|
          trim_box[0] += 1e-4
          trim_box[1] += 1e-4
          trim_box[2] -= 1e-4
          trim_box[3] -= 1e-4
        end
      end

      def font_path font_file, fonts_dir
        # resolve relative to built-in font dir unless path is absolute
        ::File.absolute_path font_file, fonts_dir
      end

      def generate_manname_section node
        title = node.attr 'manname-title', 'Name'
        if (next_section_title = node.sections[0]&.title) && next_section_title.upcase == next_section_title
          title = title.upcase
        end
        sect = Section.new node, 1
        sect.sectname = 'section'
        sect.id = node.attr 'manname-id'
        sect.title = title
        sect << (Block.new sect, :paragraph, source: %(#{node.attr 'manname'} - #{node.attr 'manpurpose'}), subs: :normal)
        sect
      end

      def get_char code
        (code.start_with? '\u') ? ([((code.slice 2, code.length).to_i 16)].pack 'U1') : code
      end

      def get_page_bg_image doc, theme_, layout, side
        (@page_bg_image[layout] ||= begin
          if (bg_image = resolve_background_image doc, theme_, 'page-background-image')&.first
            val = { verso: bg_image, recto: bg_image }
          else
            val = { verso: nil, recto: nil }
          end
          if (bg_image = resolve_background_image doc, theme_, 'page-background-image-verso')
            val[:verso] = bg_image[0] && bg_image
          end
          if (bg_image = resolve_background_image doc, theme_, 'page-background-image-recto')
            val[:recto] = bg_image[0] && bg_image
          end
          val
        end)[side]
      end

      def get_icon_image_path node, type, resolve = true
        doc = node.document
        doc.remove_attr 'data-uri' if (data_uri_enabled = doc.attr? 'data-uri')
        # NOTE: icon_uri will consider icon attribute on node first, then type
        icon_path, icon_format = ::Asciidoctor::Image.target_and_format node.icon_uri type
        doc.set_attr 'data-uri', '' if data_uri_enabled
        resolve ? (resolve_image_path node, icon_path, icon_format, nil) : icon_path
      end

      def init_float_box _node, block_width, block_height, float_to
        gap = ::Array === (gap = @theme.image_float_gap) ? (gap.drop 0) : [gap, gap]
        float_w = block_width + (gap[0] ||= 12)
        float_h = block_height + (gap[1] ||= 6)
        box_l = bounds.left + (float_to == 'right' ? 0 : float_w)
        box_t = cursor + block_height
        box_w = bounds.width - float_w
        box_r = box_l + box_w
        box_h = [box_t, float_h].min
        box_b = box_t - box_h
        move_cursor_to box_t
        @float_box = { page: page_number, top: box_t, right: box_r, bottom: box_b, left: box_l, width: box_w, height: box_h, gap: gap }
      end

      # NOTE: init_page is not called for imported pages, cover pages, image pages, and pages in the scratch document
      def init_page doc, _self
        next_page_side = page_side nil, @folio_placement[:inverted]
        if @media == 'prepress' && (next_page_margin = page_number == 1 ? @page_margin[:cover] : @page_margin[page.layout][next_page_side]) != page_margin
          set_page_margin next_page_margin
        end
        unless @page_bg_color == 'FFFFFF'
          fill_absolute_bounds @page_bg_color
          tare = true
        end
        if (bg_image_path, bg_image_opts = get_page_bg_image doc, @theme, (layout = page.layout), next_page_side)
          begin
            if bg_image_opts[:format] == 'pdf'
              # NOTE: pages that use PDF for the background do not support a background color or running content
              # IMPORTANT: the background PDF must have the same dimensions as the current PDF
              import_page bg_image_path, (bg_image_opts.merge replace: true, advance: false, advance_if_missing: false)
            else
              canvas { image bg_image_path, ({ position: :center, vposition: :center }.merge bg_image_opts) }
            end
            tare = true
          rescue
            facing_page_side = PageSides[(PageSides.index next_page_side) - 1]
            bg_image_by_side = @page_bg_image[layout]
            bg_image_by_side[facing_page_side] = nil if bg_image_by_side[facing_page_side] == bg_image_by_side[next_page_side]
            bg_image_by_side[next_page_side] = nil
            log :warn, %(could not embed page background image: #{bg_image_path}; #{$!.message})
          end
        end
        page.tare_content_stream if tare
      end

      def ink_paragraph_in_float_box node, float_box, prose_opts, role_keys, block_next, insert_margin_bottom
        @float_box = para_font_descender = para_font_size = end_cursor = nil
        if role_keys
          line_metrics = theme_font_cascade role_keys do
            para_font_descender = font.descender
            para_font_size = font_size
            calc_line_metrics @base_line_height
          end
        else
          para_font_descender = font.descender
          para_font_size = font_size
          line_metrics = calc_line_metrics @base_line_height
        end
        # allocate the space of at least one empty line below block
        line_height_length = line_metrics.height + line_metrics.leading + line_metrics.padding_top
        start_page_number = float_box[:page]
        start_cursor = cursor
        block_bottom = (float_box_bottom = float_box[:bottom]) + float_box[:gap][1]
        # use :at to incorporate padding top from line metrics since text_box method does not apply it
        # use :final_gap to incorporate padding bottom from line metrics
        # use :draw_text_callback to track end cursor (requires applying :final_gap to result manually)
        prose_opts.update \
          at: [float_box[:left], start_cursor - line_metrics.padding_top],
          width: float_box[:width],
          height: [cursor, float_box[:height] - (float_box[:top] - start_cursor) + line_height_length].min,
          final_gap: para_font_descender + line_metrics.padding_bottom,
          draw_text_callback: (proc do |text, opts|
            draw_text! text, opts
            end_cursor = opts[:at][1] # does not include :final_gap value
          end)
        overflow_text = role_keys ?
          theme_font_cascade(role_keys) { ink_prose node.content, prose_opts } :
          (ink_prose node.content, prose_opts)
        move_cursor_to end_cursor -= prose_opts[:final_gap] if end_cursor # ink_prose with :height does not move cursor
        if overflow_text.empty?
          if block_next && (supports_float_wrapping? block_next)
            insert_margin_bottom.call
            @float_box = float_box if page_number == start_page_number && cursor > start_cursor - prose_opts[:height]
          elsif end_cursor > block_bottom
            move_cursor_to block_bottom
            theme_margin :block, :bottom, block_next
          else
            insert_margin_bottom.call
          end
        else
          overflow_prose_opts = { align: prose_opts[:align] || @base_text_align.to_sym }
          unless end_cursor
            overflow_prose_opts[:indent_paragraphs] = prose_opts[:indent_paragraphs]
            move_cursor_to float_box_bottom if start_cursor > float_box_bottom
          end
          role_keys ?
            theme_font_cascade(role_keys) { typeset_formatted_text overflow_text, line_metrics, overflow_prose_opts } :
            (typeset_formatted_text overflow_text, line_metrics, overflow_prose_opts)
          insert_margin_bottom.call
        end
      end

      def insert_toc_section doc, toc_title, toc_page_nums
        if (doc.attr? 'toc-placement', 'macro') && (toc_node = (doc.find_by context: :toc)[0])
          if (parent_section = toc_node.parent).context == :section
            grandparent_section = parent_section.parent
            toc_level = parent_section.level
            insert_idx = (grandparent_section.blocks.index parent_section) + 1
          else
            grandparent_section = doc
            toc_level = doc.sections[0].level
            insert_idx = 0
          end
          toc_dest = toc_node.attr 'pdf-destination'
        else
          grandparent_section = doc
          toc_level = doc.sections[0].level
          insert_idx = 0
          toc_dest = dest_top toc_page_nums.first
        end
        toc_section = Section.new grandparent_section, toc_level, false, attributes: { 'pdf-destination' => toc_dest }
        toc_section.title = toc_title
        grandparent_section.blocks.insert insert_idx, toc_section
        toc_section
      end

      def load_open_uri
        if @cache_uri && !(defined? ::OpenURI::Cache) && (Helpers.require_library 'open-uri/cached', 'open-uri-cached', :warn).nil?
          # disable URI caching if library fails to load
          @cache_uri = false
        end
        ::OpenURI
      end

      def on_image_error _reason, node, target, opts
        log :warn, opts[:message] if opts.key? :message
        alt_text_vars = { alt: (node.attr 'alt'), target: target }
        alt_text_template = @theme.image_alt_content || '%{link}[%{alt}]%{/link} | <em>%{target}</em>' # rubocop:disable Style/FormatStringToken
        return if alt_text_template.empty?
        if (link = node.attr 'link')
          alt_text_vars[:link] = %(<a href="#{link}">)
          alt_text_vars[:'/link'] = '</a>'
        else
          alt_text_vars[:link] = ''
          alt_text_vars[:'/link'] = ''
        end
        theme_font :image_alt do
          ink_prose alt_text_template % alt_text_vars, align: opts[:align], margin: 0, normalize: false
        end
        ink_caption node, category: :image, end: :bottom if node.title?
        theme_margin :block, :bottom, (next_enclosed_block node) unless opts[:pinned]
        nil
      end

      def page_color_space
        page.graphic_state.color_space
      end

      def remove_tmp_files
        @tmp_files.reject! {|_, path| path ? (unlink_tmp_file path) : true }
      end

      def resolve_background_position value, default_value = {}
        if value.include? ' '
          result = {}
          center = nil
          (value.split ' ', 2).each do |keyword|
            case keyword
            when 'left', 'right'
              result[:position] = keyword.to_sym
            when 'top', 'bottom'
              result[:vposition] = keyword.to_sym
            when 'center'
              center = true
            end
          end
          if center
            result[:position] ||= :center
            result[:vposition] ||= :center
            result
          elsif (result.key? :position) && (result.key? :vposition)
            result
          else
            default_value
          end
        elsif value == 'left' || value == 'right' || value == 'center'
          { position: value.to_sym, vposition: :center }
        elsif value == 'top' || value == 'bottom'
          { position: :center, vposition: value.to_sym }
        else
          default_value
        end
      end

      def resolve_font_kerning keyword
        FontKerningTable[keyword]
      end

      def resolve_pagenums val
        pgnums = []
        ((val.include? ',') ? (val.split ',') : (val.split ';')).each do |entry|
          if entry.include? '..'
            from, _, to = entry.partition '..'
            pgnums += ([from.to_i, 1].max..[to.to_i, 1].max).to_a
          else
            pgnums << entry.to_i
          end
        end

        pgnums
      end

      def resolve_top val
        if ::Numeric === val
          @y - val
        elsif val.end_with? 'vh'
          page_height * (1 - (val.to_f / 100))
        elsif val.end_with? '%'
          @y - effective_page_height * (val.to_f / 100)
        else
          @y - (str_to_pt val)
        end
      end

      def resolve_text_transform key, use_fallback = true
        if (transform = ::Hash === key ? (key.delete :text_transform) : @theme[key])
          transform == 'none' ? nil : transform
        elsif use_fallback
          @text_transform
        end
      end

      # QUESTION: should we pass a category as an argument?
      # QUESTION: should we make this a method on the theme ostruct? (e.g., @theme.resolve_color key, fallback)
      def resolve_theme_color key, fallback_color = nil, transparent_color = fallback_color
        if (color = @theme[key] || fallback_color)
          color == 'transparent' ? transparent_color : color
        end
      end

      def unlink_tmp_file path
        ::File.unlink path if ::File.exist? path
        true
      rescue
        log :warn, %(could not delete temporary file: #{path}; #{$!.message})
        false
      end

      def url? str
        (str.include? ':/') && (UrlSniffRx.match? str)
      end

      # Calculate the width that is needed to print all the
      # fragments without wrapping any lines.
      #
      # This method assumes endlines are represented as discrete entries in the
      # fragments array.
      def width_of_fragments fragments
        line_widths = [0]
        fragments.each do |fragment|
          if fragment.text == LF
            line_widths << 0
          else
            line_widths[-1] += fragment.width
          end
        end
        line_widths.max
      end

      # Promotes author to primary author attributes around block; restores original attributes after block executes
      def with_author doc, author, primary
        doc.remove_attr 'url' if (original_url = doc.attr 'url')
        if primary
          if (email = doc.attr 'email')
            doc.set_attr 'url', ((email.include? '@') ? %(mailto:#{email}) : email)
          end
          result = yield
        else
          email = nil
          original_attrs = {}.tap do |accum|
            AuthorAttributeNames.each do |prop_name, attr_name|
              accum[attr_name] = doc.attr attr_name
              if (val = author[prop_name])
                doc.set_attr attr_name, val
                # NOTE: email attribute could be a url
                email = val if prop_name == :email
              else
                doc.remove_attr attr_name
              end
            end
          end
          doc.set_attr 'url', ((email.include? '@') ? %(mailto:#{email}) : email) if email
          result = yield
          original_attrs.each {|name, val| val ? (doc.set_attr name, val) : (doc.remove_attr name) }
        end
        if original_url
          doc.set_attr 'url', original_url
        elsif email
          doc.remove_attr 'url'
        end
        result
      end

      def create_scratch_prototype
        @label = :scratch
        @save_state = nil
        @scratch_depth = 0
        # NOTE: pdfmark has a reference to the Asciidoctor::Document, which we don't want to serialize
        saved_pdfmark, @pdfmark = @pdfmark, nil
        # IMPORTANT: don't set font before using marshal as it causes serialization to fail
        result = yield
        @pdfmark = saved_pdfmark
        @label = :primary
        result
      end

      def init_scratch originator
        if @media == 'prepress' && page_margin != (page_margin_recto = @page_margin[page.layout][:recto])
          # NOTE: prepare scratch document to use page margin from recto side (which has same width as verso side)
          set_page_margin page_margin_recto
        end
        @image_info_cache = originator.instance_variable_get :@image_info_cache
        @scratch_prototype = originator.instance_variable_get :@scratch_prototype
        @tmp_files = originator.instance_variable_get :@tmp_files
        text_formatter.scratch = true
        self
      end

      def push_scratch doc
        if (@scratch_depth += 1) == 1
          @save_state = {
            catalog: {}.tap {|accum| doc.catalog.each {|k, v| accum[k] = v.dup } },
            attributes: doc.attributes.merge,
          }
        end
      end

      def pop_scratch doc
        if (@scratch_depth -= 1) == 0
          doc.catalog.replace @save_state[:catalog]
          doc.attributes.replace @save_state[:attributes]
          @save_state = nil
        end
      end

      def clear_scratch
        @scratch_depth = 0
        @save_state = @scratch_prototype = @scratch = nil
      end
    end
  end
end
