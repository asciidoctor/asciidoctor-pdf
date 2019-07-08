# encoding: utf-8
# TODO cleanup imports...decide what belongs in asciidoctor-pdf.rb
require 'prawn'
require_relative 'ttfunk_ext'
begin
  require 'prawn/gmagick'
rescue LoadError
end unless defined? GMagick::Image
require_relative 'prawn-svg_ext'
require_relative 'prawn-table_ext'
require_relative 'prawn-templates_ext'
require_relative 'core_ext'
require_relative 'pdf-core_ext'
require_relative 'temporary_path'
require_relative 'measurements'
require_relative 'sanitizer'
require_relative 'prawn_ext'
require_relative 'formatted_text'
require_relative 'pdfmark'
require_relative 'theme_loader'
require_relative 'roman_numeral'
require_relative 'index_catalog'

autoload :StringIO, 'stringio'
autoload :Tempfile, 'tempfile'

module Asciidoctor
module PDF
class Converter < ::Prawn::Document
  include ::Asciidoctor::Converter
  if defined? ::Asciidoctor::Logging
    include ::Asciidoctor::Logging
  else
    include ::Asciidoctor::LoggingShim
  end
  include ::Asciidoctor::Writer
  include ::Asciidoctor::Prawn::Extensions

  register_for 'pdf'

  # NOTE require_library doesn't support require_relative and we don't modify the load path for this gem
  CodeRayRequirePath = ::File.join((::File.dirname __FILE__), 'prawn_ext/coderay_encoder')
  RougeRequirePath = ::File.join((::File.dirname __FILE__), 'rouge_ext')

  AsciidoctorVersion = ::Gem::Version.create ::Asciidoctor::VERSION
  AdmonitionIcons = {
    caution:   { name: 'fas-fire', stroke_color: 'BF3400', size: 24 },
    important: { name: 'fas-exclamation-circle', stroke_color: 'BF0000', size: 24 },
    note:      { name: 'fas-info-circle', stroke_color: '19407C', size: 24 },
    tip:       { name: 'far-lightbulb', stroke_color: '111111', size: 24 },
    warning:   { name: 'fas-exclamation-triangle', stroke_color: 'BF6900', size: 24 }
  }
  TextAlignmentNames = ['justify', 'left', 'center', 'right']
  TextAlignmentRoles = ['text-justify', 'text-left', 'text-center', 'text-right']
  BlockAlignmentNames = ['left', 'center', 'right']
  AlignmentTable = { '<' => :left, '=' => :center, '>' => :right }
  ColumnPositions = [:left, :center, :right]
  PageLayouts = [:portrait, :landscape]
  PageSides = [:recto, :verso]
  (PDFVersions = { '1.3' => 1.3, '1.4' => 1.4, '1.5' => 1.5, '1.6' => 1.6, '1.7' => 1.7 }).default = 1.4
  LF = %(\n)
  DoubleLF = %(\n\n)
  TAB = %(\t)
  InnerIndent = %(\n )
  # a no-break space is used to replace a leading space to prevent Prawn from trimming indentation
  # a leading zero-width space can't be used as it gets dropped when calculating the line width
  GuardedIndent = %(\u00a0)
  GuardedInnerIndent = %(\n\u00a0)
  TabRx = /\t/
  TabIndentRx = /^\t+/
  NoBreakSpace = %(\u00a0)
  NarrowNoBreakSpace = %(\u202f)
  ZeroWidthSpace = %(\u200b)
  DummyText = %(\u0000)
  DotLeaderTextDefault = '. '
  EmDash = %(\u2014)
  RightPointer = %(\u25ba)
  LowercaseGreekA = %(\u03b1)
  Bullets = {
    disc: %(\u2022),
    circle: %(\u25e6),
    square: %(\u25aa),
    none: ''
  }
  # NOTE Default theme font uses ballot boxes from FontAwesome
  BallotBox = {
    checked: %(\u2611),
    unchecked: %(\u2610)
  }
  SimpleAttributeRefRx = /(?<!\\)\{\w+(?:[\-]\w+)*\}/
  MeasurementRxt = '\\d+(?:\\.\\d+)?(?:in|cm|mm|p[txc])?'
  MeasurementPartsRx = /^(\d+(?:\.\d+)?)(in|mm|cm|p[txc])?$/
  PageSizeRx = /^(?:\[(#{MeasurementRxt}), ?(#{MeasurementRxt})\]|(#{MeasurementRxt})(?: x |x)(#{MeasurementRxt})|\S+)$/
  CalloutExtractRx = /(?:(?:\/\/|#|--|;;) ?)?(\\)?<!?(|--)(\d+|\.)\2> ?(?=(?:\\?<!?\2(?:\d+|\.)\2>)*$)/
  ImageAttributeValueRx = /^image:{1,2}(.*?)\[(.*?)\]$/
  UriBreakCharsRx = /(?:\/|\?|&amp;|#)(?!$)/
  UriBreakCharRepl = %(\\&#{ZeroWidthSpace})
  UriSchemeBoundaryRx = /(?<=:\/\/)/
  LineScanRx = /\n|.+/
  BlankLineRx = /\n{2,}/
  WhitespaceChars = %( \t\n)
  SourceHighlighters = ['coderay', 'pygments', 'rouge'].to_set
  PygmentsBgColorRx = /^\.highlight +{ *background: *#([^;]+);/
  ViewportWidth = ::Module.new

  def initialize backend, opts
    super
    basebackend 'html'
    filetype 'pdf'
    htmlsyntax 'html'
    outfilesuffix '.pdf'
    if (doc = opts[:document])
      # NOTE enabling data-uri forces Asciidoctor Diagram to produce absolute image paths
      doc.attributes['data-uri'] = ((doc.instance_variable_get :@attribute_overrides) || {})['data-uri'] = ''
    end
    @capabilities = {
      expands_tabs: (::Asciidoctor::VERSION.start_with? '1.5.3.') || AsciidoctorVersion >= (::Gem::Version.create '1.5.3'),
      special_sectnums: AsciidoctorVersion >= (::Gem::Version.create '1.5.7'),
      syntax_highlighter: AsciidoctorVersion >= (::Gem::Version.create '2.0.0'),
    }
  end

  def convert node, name = nil, opts = {}
    method_name = %(convert_#{name ||= node.node_name})
    result = nil
    if respond_to? method_name
      # NOTE we prepend the prefix "convert_" to avoid conflict with Prawn methods
      result = send method_name, node
    else
      # TODO delegate to convert_method_missing
      logger.warn %(conversion missing in backend #{@backend} for #{name})
    end
    # NOTE inline nodes generate pseudo-HTML strings; the remainder write directly to PDF object
    ::Asciidoctor::Inline === node ? result : self
  end

  def convert_content_for_block node, opts = {}
    if self != (prev_converter = node.document.converter)
      node.document.instance_variable_set :@converter, self
    else
      prev_converter = nil
    end
    if node.blocks?
      node.content
    elsif node.content_model != :compound && (string = node.content)
      # TODO this content could be cached on repeat invocations!
      layout_prose string, opts
    end
    node.document.instance_variable_set :@converter, prev_converter if prev_converter
  end

  def convert_document doc
    init_pdf doc
    # set default value for pagenums if not otherwise set
    unless (doc.attribute_locked? 'pagenums') || ((doc.instance_variable_get :@attributes_modified).include? 'pagenums')
      doc.attributes['pagenums'] = ''
    end
    if (idx_sect = doc.sections.find {|candidate| candidate.sectname == 'index' }) && idx_sect.numbered
      idx_sect.numbered = false
    end unless @capabilities[:special_sectnums]
    #assign_missing_section_ids doc

    # promote anonymous preface (defined using preamble block) to preface section
    # FIXME this should be done in core
    if doc.doctype == 'book' && (blk_0 = doc.blocks[0]) && blk_0.context == :preamble && blk_0.title? &&
        !blk_0.title.nil_or_empty? && blk_0.blocks[0].style != 'abstract' && (blk_1 = doc.blocks[1]) && blk_1.context == :section
      preface = Section.new doc, blk_1.level, false, attributes: { 1 => 'preface', 'style' => 'preface' }
      preface.special = true
      preface.sectname = 'preface'
      preface.title = blk_0.instance_variable_get :@title
      # QUESTION should ID be generated from raw or converted title? core is not clear about this
      preface.id = preface.generate_id
      preface.blocks.replace blk_0.blocks.map {|b| b.parent = preface; b }
      doc.blocks[0] = preface
      blk_0 = blk_1 = preface = nil
    end

    # NOTE on_page_create is called within a float context
    # NOTE on_page_create is not called for imported pages, front and back cover pages, and other image pages
    on_page_create do
      # NOTE we assume in prepress that physical page number reflects page side
      if @media == 'prepress' && (next_page_margin = @page_margin_by_side[page_side]) != page_margin
        set_page_margin next_page_margin
      end
      # TODO implement as a watermark (on top)
      if (bg_image = @page_bg_image[page_side])
        canvas { image bg_image[0], ({ position: :center, vposition: :center }.merge bg_image[1]) }
      elsif @page_bg_color && @page_bg_color != 'FFFFFF'
        fill_absolute_bounds @page_bg_color
      end
    end if respond_to? :on_page_create

    layout_cover_page doc, :front
    if (insert_title_page = doc.doctype == 'book' || (doc.attr? 'title-page'))
      layout_title_page doc
      # NOTE a new page will already be started if the cover image is a PDF
      start_new_page unless page_is_empty?
    else
      # NOTE a new page will already be started if the cover image is a PDF
      start_new_page unless page_is_empty?
      body_start_page_number = page_number
      if doc.header? && !doc.notitle
        theme_font :heading, level: 1 do
          layout_heading doc.doctitle, align: (@theme.heading_h1_align || :center).to_sym, level: 1
        end
        toc_start = @y
      end
    end

    # NOTE font must be set before toc dry run to ensure dry run size is accurate
    font @theme.base_font_family, size: @theme.base_font_size, style: @theme.base_font_style.to_sym

    num_toc_levels = (doc.attr 'toclevels', 2).to_i
    if (insert_toc = (doc.attr? 'toc') && doc.sections?)
      start_new_page if @ppbook && verso_page?
      toc_page_nums = page_number
      toc_end = nil
      dry_run do
        toc_page_nums = layout_toc doc, num_toc_levels, toc_page_nums, 0, toc_start
        move_down @theme.block_margin_bottom unless insert_title_page
        toc_end = @y
      end
      # NOTE reserve pages for the toc; leaves cursor on page after last page in toc
      if insert_title_page
        toc_page_nums.each { start_new_page }
      else
        (toc_page_nums.first...toc_page_nums.last).each { start_new_page }
        @y = toc_end
      end
    end

    # FIXME only apply to book doctype once title and toc are moved to start page when using article doctype
    #start_new_page if @ppbook && verso_page?
    start_new_page if @media == 'prepress' && verso_page?

    if insert_title_page
      body_offset = (body_start_page_number = page_number) - 1
      front_matter_sig = [@theme.running_content_start_at || 'body', @theme.page_numbering_start_at || 'body', insert_toc]
      # NOTE start running content from title or toc, if specified (default: body)
      num_front_matter_pages = {
        ['title', 'title', true] => [0, 0],
        ['title', 'title', false] => [0, 0],
        ['title', 'toc', true] => [0, 1],
        ['title', 'toc', false] => [0, 1],
        ['title', 'body', true] => [0, body_offset],
        ['title', 'body', false] => [0, 1],
        ['toc', 'title', true] => [1, 0],
        ['toc', 'title', false] => [1, 0],
        ['toc', 'toc', true] => [1, 1],
        ['toc', 'toc', false] => [1, 1],
        ['toc', 'body', true] => [1, body_offset],
        ['body', 'title', true] => [body_offset, 0],
        ['body', 'title', false] => [1, 0],
        ['body', 'toc', true] => [body_offset, 1],
      }[front_matter_sig] || [body_offset, body_offset]
    else
      # Q: what if there's only a toc page, but not title?
      num_front_matter_pages = [body_start_page_number - 1] * 2
    end

    @index.start_page_number = num_front_matter_pages[1] + 1
    doc.set_attr 'pdf-anchor', (doc_anchor = derive_anchor_from_id doc.id, 'top')
    add_dest_for_block doc, doc_anchor

    convert_section generate_manname_section doc if doc.doctype == 'manpage' && (doc.attr? 'manpurpose')

    convert_content_for_block doc

    # NOTE for a book, these are leftover footnotes; for an article this is everything
    layout_footnotes doc

    # NOTE delete orphaned page (a page was created but there was no additional content)
    # QUESTION should we delete page if document is empty? (leaving no pages?)
    delete_page if page_is_empty? && page_count > 1

    toc_page_nums = insert_toc ? (layout_toc doc, num_toc_levels, toc_page_nums.first, num_front_matter_pages[1], toc_start) : []

    unless page_count < body_start_page_number
      unless doc.noheader || @theme.header_height.to_f.zero?
        layout_running_content :header, doc, skip: num_front_matter_pages, body_start_page_number: body_start_page_number
      end
      unless doc.nofooter || @theme.footer_height.to_f.zero?
        layout_running_content :footer, doc, skip: num_front_matter_pages, body_start_page_number: body_start_page_number
      end
    end

    add_outline doc, (doc.attr 'outlinelevels', num_toc_levels).to_i, toc_page_nums, num_front_matter_pages[1]
    # TODO allow document (or theme) to override initial view magnification
    # NOTE add 1 to page height to force initial scroll to 0; a nil value also seems to work
    catalog.data[:OpenAction] = dest_fit_horizontally((page_height + 1), state.pages[0]) if state.pages.size > 0
    catalog.data[:ViewerPreferences] = { DisplayDocTitle: true }

    layout_cover_page doc, :back
    nil
  end

  # NOTE embedded only makes sense if perhaps we are building
  # on an existing Prawn::Document instance; for now, just treat
  # it the same as a full document.
  alias convert_embedded convert_document

  # TODO only allow method to be called once (or we need a reset)
  def init_pdf doc
    @allow_uri_read = doc.attr? 'allow-uri-read'
    pdf_opts = build_pdf_options doc, (theme = load_theme doc)
    # QUESTION should page options be preserved? (otherwise, not readily available)
    #@page_opts = { size: pdf_opts[:page_size], layout: pdf_opts[:page_layout] }
    ::Prawn::Document.instance_method(:initialize).bind(self).call pdf_opts
    renderer.min_version PDFVersions[doc.attr 'pdf-version']
    @page_margin_by_side = { recto: page_margin, verso: page_margin }
    if (@media = doc.attr 'media', 'screen') == 'prepress'
      @ppbook = doc.doctype == 'book'
      page_margin_recto = @page_margin_by_side[:recto]
      if (page_margin_outer = theme.page_margin_outer)
        page_margin_recto[1] = @page_margin_by_side[:verso][3] = page_margin_outer
      end
      if (page_margin_inner = theme.page_margin_inner)
        page_margin_recto[3] = @page_margin_by_side[:verso][1] = page_margin_inner
      end
      # NOTE prepare scratch document to use page margin from recto side (which has same width as verso side)
      set_page_margin page_margin_recto unless page_margin_recto == page_margin
    else
      @ppbook = false
    end
    # QUESTION should ThemeLoader register fonts?
    register_fonts theme.font_catalog, (doc.attr 'scripts', 'latin'), (doc.attr 'pdf-fontsdir', ThemeLoader::FontsDir)
    if (bg_image = resolve_background_image doc, theme, 'page-background-image') && bg_image[0]
      @page_bg_image = { verso: bg_image, recto: bg_image }
    else
      @page_bg_image = { verso: nil, recto: nil }
    end
    if (bg_image = resolve_background_image doc, theme, 'page-background-image-verso')
      @page_bg_image[:verso] = bg_image[0] ? bg_image : nil
    end
    if (bg_image = resolve_background_image doc, theme, 'page-background-image-recto') && bg_image[0]
      @page_bg_image[:recto] = bg_image[0] ? bg_image : nil
    end
    @page_bg_color = resolve_theme_color :page_background_color, 'FFFFFF'
    @fallback_fonts = [*theme.font_fallbacks]
    @font_color = theme.base_font_color
    @base_align = (align = doc.attr 'text-align') && (TextAlignmentNames.include? align) ? align : theme.base_align
    @text_transform = nil
    @list_numerals = []
    @list_bullets = []
    @footnotes = []
    @index = IndexCatalog.new
    # NOTE we have to init Pdfmark class here while we have reference to the doc
    @pdfmark = (doc.attr? 'pdfmark') ? (Pdfmark.new doc) : nil
    init_scratch_prototype
    self
  end

  def load_theme doc
    @theme ||= begin
      if (theme = doc.options[:pdf_theme])
        @themesdir = theme.__dir__ || (doc.attr 'pdf-themesdir') || (doc.attr 'pdf-stylesdir')
      else
        theme_name = (doc.attr 'pdf-theme') || (doc.attr 'pdf-style')
        theme = ThemeLoader.load_theme theme_name, ((doc.attr 'pdf-themesdir') || (doc.attr 'pdf-stylesdir'))
        @themesdir = theme.__dir__
      end
      theme
    end
  end

  def build_pdf_options doc, theme
    case (page_margin = (doc.attr 'pdf-page-margin') || theme.page_margin)
    when ::Array
      page_margin = page_margin[0..3] if page_margin.length > 4
      page_margin = page_margin.map {|v| ::Numeric === v ? v : (str_to_pt v.to_s) }
    when ::Numeric
      page_margin = [page_margin]
    when ::String
      if page_margin.empty?
        page_margin = nil
      elsif (page_margin.start_with? '[') && (page_margin.end_with? ']')
        if (page_margin = page_margin[1...-1].rstrip).empty?
          page_margin = [0]
        else
          if (page_margin = page_margin.split ',', -1).length > 4
            page_margin = page_margin[0..3]
          end
          page_margin = page_margin.map {|v| str_to_pt v.rstrip }
        end
      else
        page_margin = [(str_to_pt page_margin)]
      end
    else
      page_margin = nil
    end

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

    page_size = case page_size
    when ::String
      # TODO extract helper method to check for named page size
      if ::PDF::Core::PageGeometry::SIZES.key?(page_size = page_size.upcase)
        page_size
      end
    when ::Array
      unless page_size.size == 2
        page_size = page_size[0..1].fill(0..1) {|i| page_size[i] || 0}
      end
      page_size.map do |dim|
        if ::Numeric === dim
          # dimension cannot be less than 0
          dim > 0 ? dim : break
        elsif ::String === dim && MeasurementPartsRx =~ dim
          # NOTE truncate to max precision retained by PDF::Core
          (to_pt $1.to_f, $2).truncate 4
        else
          break
        end
      end
    end

    if (page_layout = (doc.attr 'pdf-page-layout') || theme.page_layout).nil_or_empty? ||
        !(PageLayouts.include?(page_layout = page_layout.to_sym))
      page_layout = nil
    end

    {
      #compress: true,
      #optimize_objects: true,
      margin: (page_margin || 36),
      page_size: (page_size || 'A4'),
      page_layout: (page_layout || :portrait),
      info: (build_pdf_info doc),
      skip_page_creation: true,
      text_formatter: (FormattedText::Formatter.new theme: theme)
    }
  end

  # FIXME Pdfmark should use the PDF info result
  def build_pdf_info doc
    info = {}
    # FIXME use sanitize: :plain_text once available
    info[:Title] = sanitize(doc.doctitle use_fallback: true).as_pdf
    if doc.attr? 'authors'
      info[:Author] = (doc.attr 'authors').as_pdf
    end
    if doc.attr? 'subject'
      info[:Subject] = (doc.attr 'subject').as_pdf
    end
    if doc.attr? 'keywords'
      info[:Keywords] = (doc.attr 'keywords').as_pdf
    end
    if (doc.attr? 'publisher')
      info[:Producer] = (doc.attr 'publisher').as_pdf
    end
    info[:Creator] = %(Asciidoctor PDF #{::Asciidoctor::PDF::VERSION}, based on Prawn #{::Prawn::VERSION}).as_pdf
    info[:Producer] ||= (info[:Author] || info[:Creator])
    unless doc.attr? 'reproducible'
      # NOTE since we don't track the creation date of the input file, we map the ModDate header to the last modified
      # date of the input document and the CreationDate header to the date the PDF was produced by the converter.
      info[:ModDate] = ::Time.parse(doc.attr 'docdatetime') rescue (now ||= ::Time.now)
      info[:CreationDate] = ::Time.parse(doc.attr 'localdatetime') rescue (now ||= ::Time.now)
    end
    info
  end

  def convert_section sect, opts = {}
    if sect.sectname == 'abstract'
      # HACK cheat a bit to hide this section from TOC; TOC should filter these sections
      sect.context = :open
      return convert_abstract sect
    end

    type = nil
    theme_font :heading, level: (hlevel = sect.level + 1) do
      title = sect.numbered_title formal: true
      align = (@theme[%(heading_h#{hlevel}_align)] || @theme.heading_align || @base_align).to_sym
      if sect.part_or_chapter?
        if sect.chapter?
          type = :chapter
          start_new_chapter sect
        else
          type = :part
          start_new_part sect
        end
      else
        # FIXME smarter calculation here!!
        start_new_page unless at_page_top? || cursor > (height_of title) + @theme.heading_margin_top + @theme.heading_margin_bottom + (@theme.base_line_height_length * 1.5)
      end
      # QUESTION should we store pdf-page-start, pdf-anchor & pdf-destination in internal map?
      sect.set_attr 'pdf-page-start', (start_pgnum = page_number)
      # QUESTION should we just assign the section this generated id?
      # NOTE section must have pdf-anchor in order to be listed in the TOC
      sect.set_attr 'pdf-anchor', (sect_anchor = derive_anchor_from_id sect.id, %(#{start_pgnum}-#{y.ceil}))
      add_dest_for_block sect, sect_anchor
      if type == :part
        layout_part_title sect, title, align: align, level: hlevel
      elsif type == :chapter
        layout_chapter_title sect, title, align: align, level: hlevel
      else
        layout_heading title, align: align, level: hlevel
      end
    end

    sect.sectname == 'index' ? (convert_index_section sect) : (convert_content_for_block sect)
    layout_footnotes sect if type == :chapter
    sect.set_attr 'pdf-page-end', page_number
  end

  # QUESTION if a footnote ref appears in a separate chapter, should the footnote def be duplicated?
  def layout_footnotes node
    return if (fns = (doc = node.document).footnotes - @footnotes).empty?
    theme_margin :footnotes, :top
    theme_font :footnotes do
      # FIXME layout_caption resets the theme font for footnotes
      (title = doc.attr 'footnotes-title') && (layout_caption title)
      item_spacing = @theme.footnotes_item_spacing || 0
      fns.each do |fn|
        layout_prose %(<a name="_footnotedef_#{index = fn.index}">#{DummyText}</a>[<a anchor="_footnoteref_#{index}">#{index}</a>] #{fn.text}), margin_bottom: item_spacing
      end
      @footnotes += fns
    end
    nil
  end

  def convert_floating_title node
    add_dest_for_block node if node.id
    # QUESTION should we decouple styles from section titles?
    theme_font :heading, level: (hlevel = node.level + 1) do
      layout_heading node.title, align: (@theme[%(heading_h#{hlevel}_align)] || @theme.heading_align || @base_align).to_sym, level: hlevel
    end
  end

  def convert_abstract node
    add_dest_for_block node if node.id
    pad_box @theme.abstract_padding do
      if node.title?
        theme_font :abstract_title do
          layout_heading node.title, align: (@theme.abstract_title_align || @base_align).to_sym
        end
      end
      theme_font :abstract do
        prose_opts = { line_height: @theme.abstract_line_height, align: (@theme.abstract_align || @base_align).to_sym }
        if (text_indent = @theme.prose_text_indent)
          prose_opts[:indent_paragraphs] = text_indent
        end
        # FIXME control more first_line_options using theme
        if (line1_font_style = @theme.abstract_first_line_font_style) && line1_font_style.to_sym != font_style
          prose_opts[:first_line_options] = { styles: [font_style, line1_font_style.to_sym] }
        end
        # FIXME make this cleaner!!
        if node.blocks?
          node.blocks.each do |child|
            # FIXME is playback necessary here?
            child.document.playback_attributes child.attributes
            if child.context == :paragraph
              layout_prose child.content, prose_opts
              prose_opts.delete :first_line_options
            else
              # FIXME this could do strange things if the wrong kind of content shows up
              convert_content_for_block child
            end
          end
        elsif node.content_model != :compound && (string = node.content)
          layout_prose string, prose_opts
        end
      end
    end
    # QUESTION should we be adding margin below the abstract??
    #theme_margin :block, :bottom
  end

  def convert_preamble node
    # TODO find_by needs to support a depth argument
    # FIXME core should not be promoting paragraph to preamble if there are no sections
    if (first_p = (node.find_by context: :paragraph)[0]) && first_p.parent == node && node.document.sections?
      first_p.add_role 'lead'
    end
    convert_content_for_block node
  end

  def convert_paragraph node
    add_dest_for_block node if node.id
    prose_opts = { margin_bottom: 0 }
    lead = (roles = node.roles).include? 'lead'
    if (align = resolve_alignment_from_role roles)
      prose_opts[:align] = align
    end

    if (text_indent = @theme.prose_text_indent)
      prose_opts[:indent_paragraphs] = text_indent
    end

    # TODO check if we're within one line of the bottom of the page
    # and advance to the next page if so (similar to logic for section titles)
    layout_caption node.title if node.title?

    if lead
      theme_font :lead do
        layout_prose node.content, prose_opts
      end
    else
      layout_prose node.content, prose_opts
    end

    if (margin_inner_val = @theme.prose_margin_inner) &&
        (next_block = (siblings = node.parent.blocks)[(siblings.index node) + 1]) && next_block.context == :paragraph
      margin_bottom_val = margin_inner_val
    else
      margin_bottom_val = @theme.prose_margin_bottom
    end
    margin_bottom margin_bottom_val
  end

  def convert_admonition node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    type = node.attr 'name'
    label_align = (@theme.admonition_label_align || :center).to_sym
    # TODO allow vertical_align to be a number
    if (label_valign = (@theme.admonition_label_vertical_align || :middle).to_sym) == :middle
      label_valign = :center
    end
    if (label_min_width = @theme.admonition_label_min_width)
      label_min_width = label_min_width.to_f
    end
    icons = ((doc = node.document).attr? 'icons') ? (doc.attr 'icons') : false
    if (data_uri_enabled = doc.attr? 'data-uri')
      doc.remove_attr 'data-uri'
    end
    if icons == 'font' && !(node.attr? 'icon', nil, false)
      icon_data = admonition_icon_data(label_text = type.to_sym)
      label_width = label_min_width ? label_min_width : (icon_data[:size] * 1.5)
    # NOTE icon_uri will consider icon attribute on node first, then type
    elsif icons && ::File.readable?(icon_path = (node.icon_uri type))
      icons = true
      # TODO introduce @theme.admonition_image_width? or use size key from admonition_icon_<name>?
      label_width = label_min_width ? label_min_width : 36.0
    else
      if icons
        icons = false
        logger.warn %(admonition icon image not found or not readable: #{icon_path}) unless scratch?
      end
      label_text = node.caption
      theme_font :admonition_label do
        theme_font %(admonition_label_#{type}) do
          if (transform = @text_transform)
            label_text = transform_text label_text, transform
          end
          label_width = rendered_width_of_string label_text
          label_width = label_min_width if label_min_width && label_min_width > label_width
        end
      end
    end
    doc.set_attr 'data-uri', '' if data_uri_enabled
    unless ::Array === (cpad = @theme.admonition_padding)
      cpad = ::Array.new 4, cpad
    end
    unless ::Array === (lpad = @theme.admonition_label_padding || cpad)
      lpad = ::Array.new 4, lpad
    end
    # FIXME this shift stuff is a real hack until we have proper margin collapsing
    shift_base = @theme.prose_margin_bottom
    shift_top = shift_base / 3.0
    shift_bottom = (shift_base * 2) / 3.0
    keep_together do |box_height = nil|
      push_scratch doc if scratch?
      pad_box [0, cpad[1], 0, lpad[3]] do
        if box_height
          if (rule_color = @theme.admonition_column_rule_color) &&
              (rule_width = @theme.admonition_column_rule_width || @theme.base_border_width) && rule_width > 0
            float do
              bounding_box [0, cursor], width: label_width + lpad[1], height: box_height do
                stroke_vertical_rule rule_color,
                    at: bounds.right,
                    line_style: (@theme.admonition_column_rule_style || :solid).to_sym,
                    line_width: rule_width
              end
            end
          end
          float do
            bounding_box [0, cursor], width: label_width, height: box_height do
              if icons == 'font'
                # FIXME we're assume icon is a square
                icon_size = fit_icon_to_bounds icon_data[:size]
                # NOTE Prawn's vertical center is not reliable, so calculate it manually
                if label_valign == :center
                  label_valign = :top
                  if (vcenter_pos = (box_height - icon_size) * 0.5) > 0
                    move_down vcenter_pos
                  end
                end
                icon icon_data[:name],
                    valign: label_valign,
                    align: label_align,
                    color: icon_data[:stroke_color],
                    size: icon_size
              elsif icons
                if (::Asciidoctor::Image.format icon_path) == 'svg'
                  begin
                    svg_obj = ::Prawn::SVG::Interface.new ::File.read(icon_path), self,
	                      position: label_align,
                        vposition: label_valign,
                        width: label_width,
                        height: box_height,
                        fallback_font_name: default_svg_font,
                        enable_web_requests: allow_uri_read,
                        enable_file_requests_with_root: (::File.dirname icon_path)
                    if (icon_height = (svg_size = svg_obj.document.sizing).output_height) > box_height
                      icon_width = (svg_obj.resize height: (icon_height = box_height)).output_width
                    else
                      icon_width = svg_size.output_width
                    end
                    svg_obj.draw
                  rescue
                    logger.warn %(could not embed admonition icon image: #{icon_path}; #{$!.message})
                  end
                else
                  begin
                    image_obj, image_info = build_image_object icon_path
                    icon_aspect_ratio = image_info.width.fdiv image_info.height
                    # NOTE don't scale image up if smaller than label_width
                    icon_width = [(to_pt image_info.width, :px), label_width].min
                    if (icon_height = icon_width * (1 / icon_aspect_ratio)) > box_height
                      icon_width *= box_height / icon_height
                      icon_height = box_height
                    end
                    embed_image image_obj, image_info, width: icon_width, position: label_align, vposition: label_valign
                  rescue
                    # QUESTION should we show the label in this case?
                    logger.warn %(could not embed admonition icon image: #{icon_path}; #{$!.message})
                  end
                end
              else
                # IMPORTANT the label must fit in the alotted space or it shows up on another page!
                # QUESTION anyway to prevent text overflow in the case it doesn't fit?
                theme_font :admonition_label do
                  theme_font %(admonition_label_#{type}) do
                    # NOTE Prawn's vertical center is not reliable, so calculate it manually
                    if label_valign == :center
                      label_valign = :top
                      if (vcenter_pos = (box_height - (height_of_typeset_text label_text, line_height: 1)) * 0.5) > 0
                        move_down vcenter_pos
                      end
                    end
                    @text_transform = nil # already applied to label
                    layout_prose label_text,
                        align: label_align,
                        valign: label_valign,
                        line_height: 1,
                        margin: 0,
                        inline_format: false
                  end
                end
              end
            end
          end
        end
        pad_box [cpad[0], 0, cpad[2], label_width + lpad[1] + cpad[3]] do
          move_down shift_top
          layout_caption node.title if node.title?
          theme_font :admonition do
            convert_content_for_block node
          end
          # FIXME HACK compensate for margin bottom of admonition content
          move_up shift_bottom unless at_page_top?
        end
      end
      pop_scratch doc if scratch?
    end
    theme_margin :block, :bottom
  end

  def convert_example node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    keep_together do |box_height = nil|
      push_scratch node.document if scratch?
      caption_height = node.title? ? (layout_caption node) : 0
      if box_height
        float do
          bounding_box [0, cursor], width: bounds.width, height: box_height - caption_height do
            theme_fill_and_stroke_bounds :example
          end
        end
      end
      pad_box @theme.example_padding do
        theme_font :example do
          convert_content_for_block node
        end
      end
      pop_scratch node.document if scratch?
    end
    theme_margin :block, :bottom
  end

  def convert_open node
    if node.style == 'abstract'
      convert_abstract node
    elsif node.style == 'partintro' && node.blocks.size == 1 && node.blocks[0].style == 'abstract'
      # TODO process block title and id
      # TODO process abstract child even when partintro has multiple blocks
      convert_abstract node.blocks[0]
    else
      add_dest_for_block node if node.id
      layout_caption node.title if node.title?
      convert_content_for_block node
    end
  end

  def convert_quote_or_verse node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    b_width = @theme.blockquote_border_width
    b_color = @theme.blockquote_border_color
    keep_together do |box_height = nil|
      push_scratch node.document if scratch?
      start_page_number = page_number
      start_cursor = cursor
      caption_height = node.title? ? (layout_caption node) : 0
      pad_box @theme.blockquote_padding do
        theme_font :blockquote do
          if node.context == :quote
            convert_content_for_block node
          else # verse
            content = preserve_indentation node.content, (node.attr 'tabsize')
            layout_prose content, normalize: false, align: :left
          end
        end
        if node.attr? 'attribution', nil, false
          theme_font :blockquote_cite do
            layout_prose %(#{EmDash} #{[(node.attr 'attribution'), (node.attr 'citetitle', nil, false)].compact * ', '}), align: :left, normalize: false
          end
        end
      end
      # FIXME we want to draw graphics before content, but box_height is not reliable when spanning pages
      # FIXME border extends to bottom of content area if block terminates at bottom of page
      if box_height && b_width > 0
        page_spread = page_number - start_page_number + 1
        end_cursor = cursor
        go_to_page start_page_number
        move_cursor_to start_cursor
        page_spread.times do |i|
          if i == 0
            y_draw = cursor
            b_height = page_spread > 1 ? y_draw : (y_draw - end_cursor)
          else
            bounds.move_past_bottom
            y_draw = cursor
            b_height = page_spread - 1 == i ? (y_draw - end_cursor) : y_draw
          end
          # NOTE skip past caption if present
          if caption_height > 0
            if caption_height > cursor
              caption_height -= cursor
              next # keep skipping, caption is on next page
            end
            y_draw -= caption_height
            b_height -= caption_height
            caption_height = 0
          end
          # NOTE b_height is 0 when block terminates at bottom of page
          bounding_box [0, y_draw], width: bounds.width, height: b_height do
            stroke_vertical_rule b_color, line_width: b_width, at: b_width / 2.0
          end unless b_height == 0
        end
      end
      pop_scratch node.document if scratch?
    end
    theme_margin :block, :bottom
  end

  alias convert_quote convert_quote_or_verse
  alias convert_verse convert_quote_or_verse

  def convert_sidebar node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    keep_together do |box_height = nil|
      push_scratch node.document if scratch?
      if box_height
        # FIXME due to the calculation error logged in #789, we must advance page even when content is split across pages
        advance_page if box_height > cursor && !at_page_top?
        float do
          # TODO move the multi-page logic to theme_fill_and_stroke_bounds
          if (b_width = @theme.sidebar_border_width || 0) > 0 && (b_color = @theme.sidebar_border_color)
            if b_color == @page_bg_color # let page background cut into sidebar background
              b_gap_color, b_shift = @page_bg_color, b_width
            elsif (b_gap_color = @theme.sidebar_background_color) && b_gap_color != b_color
              b_shift = 0
            else # let page background cut into border
              b_gap_color, b_shift = @page_bg_color, 0
            end
          else # let page background cut into sidebar background
            b_width = 0.5 if b_width == 0
            b_shift, b_gap_color = b_width * 0.5, @page_bg_color
          end
          b_radius = (@theme.sidebar_border_radius || 0) + b_width
          initial_page, remaining_height = true, box_height
          while remaining_height > 0
            advance_page unless initial_page
            fragment_height = [(available_height = cursor), remaining_height].min
            bounding_box [0, available_height], width: bounds.width, height: fragment_height do
              theme_fill_and_stroke_bounds :sidebar
              unless b_width == 0
                indent b_radius, b_radius do
                  move_down b_shift
                  # dashed line to indicate continuation from previous page; swell line to cover background
                  stroke_horizontal_rule b_gap_color, line_width: b_width * 1.2, line_style: :dashed
                  move_up b_shift
                end unless initial_page
                if remaining_height > fragment_height
                  move_down fragment_height - b_shift
                  indent b_radius, b_radius do
                    # dashed line to indicate continuation to next page; swell line to cover background
                    stroke_horizontal_rule b_gap_color, line_width: b_width * 1.2, line_style: :dashed
                  end
                end
              end
            end
            remaining_height -= fragment_height
            initial_page = false
          end
        end
      end
      pad_box @theme.sidebar_padding do
        if node.title?
          theme_font :sidebar_title do
            # QUESTION should we allow margins of sidebar title to be customized?
            layout_heading node.title, align: (@theme.sidebar_title_align || @base_align).to_sym, margin_top: 0
          end
        end
        theme_font :sidebar do
          convert_content_for_block node
        end
      end
      pop_scratch node.document if scratch?
    end
    theme_margin :block, :bottom
  end

  def convert_colist node
    # HACK undo the margin below previous listing or literal block
    # TODO allow this to be set using colist_margin_top
    unless at_page_top?
      # NOTE this logic won't work for a colist nested inside a list item until Asciidoctor 1.5.3
      if (self_idx = node.parent.blocks.index node) && self_idx > 0 &&
          [:listing, :literal].include?(node.parent.blocks[self_idx - 1].context)
        move_up @theme.block_margin_bottom / 2.0
        # or we could do...
        #move_up @theme.block_margin_bottom
        #move_down @theme.caption_margin_inside * 2
      end
    end
    add_dest_for_block node if node.id
    @list_numerals ||= []
    # FIXME move \u2460 to constant (or theme setting)
    # \u2460 = circled one, \u24f5 = double circled one, \u278b = negative circled one
    @list_numerals << %(\u2460)
    #stroke_horizontal_rule @theme.caption_border_bottom_color
    line_metrics = calc_line_metrics @theme.base_line_height
    node.items.each_with_index do |item, idx|
      # FIXME extract to an ensure_space (or similar) method; simplify
      advance_page if cursor < (line_metrics.height + line_metrics.leading + line_metrics.padding_top) + 1
      convert_colist_item item
    end
    @list_numerals.pop
    # correct bottom margin of last item
    list_margin_bottom = @theme.prose_margin_bottom
    margin_bottom list_margin_bottom - @theme.outline_list_item_spacing
  end

  def convert_colist_item node
    marker_width = nil
    theme_font :conum do
      marker_width = rendered_width_of_string %(#{conum_glyph 1}x)
      float do
        bounding_box [0, cursor], width: marker_width do
          @list_numerals << (index = @list_numerals.pop).next
          theme_font :conum do
            layout_prose index, align: :center, line_height: @theme.conum_line_height, inline_format: false, margin: 0
          end
        end
      end
    end

    indent marker_width do
      convert_content_for_list_item node, :colist, margin_bottom: @theme.outline_list_item_spacing
    end
  end

  def convert_dlist node
    add_dest_for_block node if node.id

    case node.style
    when 'qanda'
      (@list_numerals ||= []) << '1'
      convert_outline_list node
      @list_numerals.pop
    else
      # TODO check if we're within one line of the bottom of the page
      # and advance to the next page if so (similar to logic for section titles)
      layout_caption node.title if node.title?

      node.items.each do |terms, desc|
        terms = [*terms]
        # NOTE don't orphan the terms, allow for at least one line of content
        # FIXME extract ensure_space (or similar) method
        advance_page if cursor < @theme.base_line_height_length * (terms.size + 1)
        terms.each do |term|
          # FIXME layout_prose should pass style downward when parsing formatted text
          #layout_prose term.text, style: @theme.description_list_term_font_style.to_sym, margin_top: 0, margin_bottom: @theme.description_list_term_spacing, align: :left
          term_text = term.text
          case @theme.description_list_term_font_style.to_sym
          when :bold
            term_text = %(<strong>#{term_text}</strong>)
          when :italic
            term_text = %(<em>#{term_text}</em>)
          when :bold_italic
            term_text = %(<strong><em>#{term_text}</em></strong>)
          end
          layout_prose term_text, margin_top: 0, margin_bottom: @theme.description_list_term_spacing, align: :left
        end
        if desc
          indent @theme.description_list_description_indent do
            convert_content_for_list_item desc, :dlist_desc
          end
        end
      end
    end
  end

  def convert_olist node
    add_dest_for_block node if node.id
    @list_numerals ||= []
    # TODO move list_numeral resolve to a method
    list_numeral = case node.style
    when 'arabic'
      1
    when 'decimal'
      '01'
    when 'loweralpha'
      'a'
    when 'upperalpha'
      'A'
    when 'lowerroman'
      RomanNumeral.new 'i'
    when 'upperroman'
      RomanNumeral.new 'I'
    when 'lowergreek'
      LowercaseGreekA
    when 'unstyled', 'unnumbered', 'no-bullet'
      nil
    when 'none'
      ''
    else
      1
    end
    if list_numeral && list_numeral != '' &&
        (start = (node.attr 'start', nil, false) || ((node.option? 'reversed') ? node.items.size : nil))
      if (start = start.to_i) > 1
        (start - 1).times { list_numeral = list_numeral.next }
      elsif start < 1 && !(::String === list_numeral)
        (start - 1).abs.times { list_numeral = list_numeral.pred }
      end
    end
    @list_numerals << list_numeral
    convert_outline_list node
    @list_numerals.pop
  end

  def convert_ulist node
    add_dest_for_block node if node.id
    # TODO move bullet_type to method on List (or helper method)
    if node.option? 'checklist'
      @list_bullets << :checkbox
    else
      bullet_type = if (style = node.style)
        case style
        when 'bibliography'
          :square
        when 'unstyled', 'no-bullet'
          nil
        else
          if Bullets.key?(candidate = style.to_sym)
            candidate
          else
            logger.warn %(unknown unordered list style: #{candidate})
            :disc
          end
        end
      else
        case node.outline_level
        when 1
          :disc
        when 2
          :circle
        else
          :square
        end
      end
      @list_bullets << bullet_type
    end
    convert_outline_list node
    @list_bullets.pop
  end

  def convert_outline_list node
    # TODO check if we're within one line of the bottom of the page
    # and advance to the next page if so (similar to logic for section titles)
    layout_caption node.title if node.title?

    opts = {}
    if (align = resolve_alignment_from_role node.roles)
      opts[:align] = align
    elsif node.style == 'bibliography'
      opts[:align] = :left
    elsif (align = @theme.outline_list_text_align)
      # NOTE theme setting only affects alignment of list text (not nested blocks)
      opts[:align] = align.to_sym
    end

    line_metrics = calc_line_metrics @theme.base_line_height
    complex = false
    # ...or if we want to give all items in the list the same treatment
    #complex = node.items.find(&:complex?) ? true : false
    if (node.context == :ulist && !@list_bullets[-1]) || (node.context == :olist && !@list_numerals[-1])
      if node.style == 'unstyled'
        # unstyled takes away all indentation
        list_indent = 0
      elsif (list_indent = @theme.outline_list_indent) > 0
        # no-bullet aligns text with left-hand side of bullet position (as though there's no bullet)
        list_indent = [list_indent - (rendered_width_of_string %(#{node.context == :ulist ? "\u2022" : '1.'}x)), 0].max
      end
    else
      list_indent = @theme.outline_list_indent
    end
    indent list_indent do
      node.items.each do |item|
        # FIXME extract to an ensure_space (or similar) method; simplify
        advance_page if cursor < (line_metrics.height + line_metrics.leading + line_metrics.padding_top)
        convert_outline_list_item item, node, opts
      end
    end
    # NOTE Children will provide the necessary bottom margin if last item is complex.
    # However, don't leave gap at the bottom if list is nested in an outline list
    unless complex || (node.nested? && node.parent.parent.outline?)
      # correct bottom margin of last item
      list_margin_bottom = @theme.prose_margin_bottom
      margin_bottom list_margin_bottom - @theme.outline_list_item_spacing
    end
  end

  def convert_outline_list_item node, list, opts = {}
    # TODO move this to a draw_bullet (or draw_marker) method
    marker_style = {}
    marker_style[:font_color] = @theme.outline_list_marker_font_color || @font_color
    marker_style[:font_family] = font_family
    marker_style[:font_size] = font_size
    marker_style[:line_height] = @theme.base_line_height
    case (list_type = list.context)
    when :ulist
      complex = node.complex?
      if (marker_type = @list_bullets[-1])
        if marker_type == :checkbox
          # QUESTION should we remove marker indent if not a checkbox?
          if node.attr? 'checkbox', nil, false
            marker_type = (node.attr? 'checked', nil, false) ? :checked : :unchecked
            marker = @theme[%(ulist_marker_#{marker_type}_content)] || BallotBox[marker_type]
          end
        else
          marker = @theme[%(ulist_marker_#{marker_type}_content)] || Bullets[marker_type]
        end
        [:font_color, :font_family, :font_size, :line_height].each do |prop|
          marker_style[prop] = @theme[%(ulist_marker_#{marker_type}_#{prop})] || @theme[%(ulist_marker_#{prop})] || marker_style[prop]
        end if marker
      end
    when :olist
      complex = node.complex?
      if (index = @list_numerals.pop)
        if index == ''
          marker = ''
        else
          marker = %(#{index}.)
          dir = (node.parent.option? 'reversed') ? :pred : :next
          @list_numerals << (index = index.public_send dir)
        end
      end
    when :dlist
      # NOTE list.style is 'qanda'
      complex = node[1] && node[1].complex?
      @list_numerals << (index = @list_numerals.pop).next
      marker = %(#{index}.)
    else
      complex = node.complex?
      logger.warn %(unknown list type #{list_type.inspect})
      marker = @theme.ulist_marker_disc_content || Bullets[:disc]
    end

    if marker
      if marker_style[:font_family] == 'fa'
        logger.info { 'deprecated fa icon set found in theme; use fas, far, or fab instead' }
        marker_style[:font_family] = FontAwesomeIconSets.find {|candidate| (icon_font_data candidate).yaml[candidate].value? marker } || 'fas'
      end
      marker_gap = rendered_width_of_char 'x'
      font marker_style[:font_family], size: marker_style[:font_size] do
        marker_width = rendered_width_of_string marker
        start_position = -marker_width + -marker_gap
        float do
          flow_bounding_box start_position, width: marker_width do
            layout_prose marker,
              align: :right,
              character_spacing: -0.5,
              color: marker_style[:font_color],
              inline_format: false,
              line_height: marker_style[:line_height],
              margin: 0,
              normalize: false,
              single_line: true
          end
        end
      end
    end

    if complex
      convert_content_for_list_item node, list_type, opts
    else
      convert_content_for_list_item node, list_type, (opts.merge margin_bottom: @theme.outline_list_item_spacing)
    end
  end

  def convert_content_for_list_item node, list_type, opts = {}
    if list_type == :dlist # qanda
      terms, desc = node
      [*terms].each {|term| layout_prose %(<em>#{term.text}</em>), opts }
      if desc
        layout_prose desc.text, opts if desc.text?
        convert_content_for_block desc
      end
    else
      layout_prose node.text, opts if node.text?
      convert_content_for_block node
    end
  end

  def convert_image node, opts = {}
    node.extend ::Asciidoctor::Image unless ::Asciidoctor::Image === node
    target, image_format = node.target_and_format

    if image_format == 'gif' && !(defined? ::GMagick::Image)
      logger.warn %(GIF image format not supported. Install the prawn-gmagick gem or convert #{target} to PNG.) unless scratch?
      image_path = nil
    elsif ::Base64 === target
      image_path = target
    elsif (image_path = resolve_image_path node, target, (opts.fetch :relative_to_imagesdir, true), image_format)
      if ::File.readable? image_path
        # NOTE import_page automatically advances to next page afterwards
        # QUESTION should we add destination to top of imported page?
        return import_page image_path, replace: page_is_empty? if image_format == 'pdf'
      elsif image_format == 'pdf'
        logger.warn %(pdf to insert not found or not readable: #{image_path}) unless scratch?
        # QUESTION should we use alt text in this case?
        return
      else
        logger.warn %(image to embed not found or not readable: #{image_path}) unless scratch?
        image_path = nil
      end
    elsif image_format == 'pdf'
      # QUESTION should we use alt text in this case?
      return
    end

    theme_margin :block, :top unless (pinned = opts[:pinned])

    return on_image_error :missing, node, target, opts unless image_path

    # TODO move this calculation into a method, such as layout_caption node, side: :bottom, dry_run: true
    caption_h = 0
    dry_run do
      move_down 0.0001 # hack to force top margin to be applied
      # NOTE we assume caption fits on a single page, which seems reasonable
      caption_h = layout_caption node, side: :bottom
    end if node.title?

    # TODO support cover (aka canvas) image layout using "canvas" (or "cover") role
    width = resolve_explicit_width node.attributes, (available_w = bounds.width), support_vw: true, use_fallback: true, constrain_to_bounds: true
    # TODO add `to_pt page_width` method to ViewportWidth type
    width = (width.to_f / 100) * page_width if ViewportWidth === width

    alignment = ((node.attr 'align', nil, false) || @theme.image_align).to_sym
    align_to_page = node.option? 'align-to-page'

    begin
      span_page_width_if align_to_page do
        if image_format == 'svg'
          if ::Base64 === image_path
            svg_data = ::Base64.decode64 image_path
            file_request_root = false
          else
            svg_data = ::File.read image_path
            file_request_root = ::File.dirname image_path
          end
          svg_obj = ::Prawn::SVG::Interface.new svg_data, self,
              position: alignment,
              width: width,
              fallback_font_name: default_svg_font,
              enable_web_requests: allow_uri_read,
              enable_file_requests_with_root: file_request_root
          rendered_w = (svg_size = svg_obj.document.sizing).output_width
          if !width && (svg_obj.document.root.attributes.key? 'width')
            # NOTE scale native width & height from px to pt and restrict width to available width
            if (adjusted_w = [available_w, (to_pt rendered_w, :px)].min) != rendered_w
              svg_size = svg_obj.resize width: (rendered_w = adjusted_w)
            end
          end
          # NOTE shrink image so it fits within available space; group image & caption
          if (rendered_h = svg_size.output_height) > (available_h = cursor - caption_h)
            unless pinned || at_page_top?
              advance_page
              available_h = cursor - caption_h
            end
            if rendered_h > available_h
              rendered_w = (svg_size = svg_obj.resize height: (rendered_h = available_h)).output_width
            end
          end
          add_dest_for_block node if node.id
          # NOTE workaround to fix Prawn not adding fill and stroke commands on page that only has an image;
          # breakage occurs when running content (stamps) are added to page
          update_colors if graphic_state.color_space.empty?
          # NOTE prawn-svg 0.24.0, 0.25.0, & 0.25.1 didn't restore font after call to draw (see mogest/prawn-svg#80)
          # NOTE cursor advanced automatically
          svg_obj.draw
          if (link = node.attr 'link', nil, false)
            link_box = [(abs_left = svg_obj.position[0] + bounds.absolute_left), y, (abs_left + rendered_w), (y + rendered_h)]
            link_annotation link_box, Border: [0, 0, 0], A: { Type: :Action, S: :URI, URI: link.as_pdf }
          end
        else
          # FIXME this code really needs to be better organized!
          # NOTE use low-level API to access intrinsic dimensions; build_image_object caches image data previously loaded
          image_obj, image_info = ::Base64 === image_path ?
              ::StringIO.open((::Base64.decode64 image_path), 'rb') {|fd| build_image_object fd } :
              ::File.open(image_path, 'rb') {|fd| build_image_object fd }
          # NOTE if width is not specified, scale native width & height from px to pt and restrict width to available width
          rendered_w, rendered_h = image_info.calc_image_dimensions width: (width || [available_w, (to_pt image_info.width, :px)].min)
          # NOTE shrink image so it fits within available space; group image & caption
          if rendered_h > (available_h = cursor - caption_h)
            unless pinned || at_page_top?
              advance_page
              available_h = cursor - caption_h
            end
            if rendered_h > available_h
              rendered_w, rendered_h = image_info.calc_image_dimensions height: (rendered_h = available_h)
            end
          end
          # NOTE must calculate link position before embedding to get proper boundaries
          if (link = node.attr 'link', nil, false)
            img_x, img_y = image_position rendered_w, rendered_h, position: alignment
            link_box = [img_x, (img_y - rendered_h), (img_x + rendered_w), img_y]
          end
          image_top = cursor
          add_dest_for_block node if node.id
          # NOTE workaround to fix Prawn not adding fill and stroke commands on page that only has an image;
          # breakage occurs when running content (stamps) are added to page
          update_colors if graphic_state.color_space.empty?
          # NOTE specify both width and height to avoid recalculation
          embed_image image_obj, image_info, width: rendered_w, height: rendered_h, position: alignment
          link_annotation link_box, Border: [0, 0, 0], A: { Type: :Action, S: :URI, URI: link.as_pdf } if link
          # NOTE Asciidoctor disables automatic advancement of cursor for raster images, so move cursor manually
          move_down rendered_h if cursor == image_top
        end
      end
      layout_caption node, side: :bottom if node.title?
      theme_margin :block, :bottom unless pinned
    rescue
      on_image_error :exception, node, target, (opts.merge message: %(could not embed image: #{image_path}; #{$!.message}))
    end
  ensure
    unlink_tmp_file image_path if image_path
  end

  def on_image_error reason, node, target, opts = {}
    logger.warn opts[:message] if opts.key? :message
    alt_text = (link = node.attr 'link', nil, false) ?
        %(<a href="#{link}">[#{node.attr 'alt'}]</a> | <em>#{target}</em>) :
        %([#{node.attr 'alt'}] | <em>#{target}</em>)
    layout_prose alt_text,
        align: ((node.attr 'align', nil, false) || @theme.image_align).to_sym,
        margin: 0,
        normalize: false,
        single_line: true
    layout_caption node, side: :bottom if node.title?
    theme_margin :block, :bottom unless opts[:pinned]
    nil
  end

  def convert_audio node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    audio_path = node.media_uri(node.attr 'target')
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    layout_prose %(#{play_symbol}#{NoBreakSpace}<a href="#{audio_path}">#{audio_path}</a> <em>(audio)</em>), normalize: false, margin: 0, single_line: true
    layout_caption node, side: :bottom if node.title?
    theme_margin :block, :bottom
  end

  def convert_video node
    case (poster = node.attr 'poster', nil, false)
    when 'youtube'
      video_path = %(https://www.youtube.com/watch?v=#{video_id = node.attr 'target'})
      # see http://stackoverflow.com/questions/2068344/how-do-i-get-a-youtube-video-thumbnail-from-the-youtube-api
      poster = allow_uri_read ? %(https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg) : nil
      type = 'YouTube video'
    when 'vimeo'
      video_path = %(https://vimeo.com/#{video_id = node.attr 'target'})
      if allow_uri_read
        if node.document.attr? 'cache-uri'
          Helpers.require_library 'open-uri/cached', 'open-uri-cached' unless defined? ::OpenURI::Cache
        else
          ::OpenURI
        end
        poster = open(%(http://vimeo.com/api/v2/video/#{video_id}.xml), 'r') do |f|
          /<thumbnail_large>(.*?)<\/thumbnail_large>/ =~ f.read && $1
        end
      end
      type = 'Vimeo video'
    else
      video_path = node.media_uri(node.attr 'target')
      type = 'video'
    end

    if poster.nil_or_empty?
      add_dest_for_block node if node.id
      theme_margin :block, :top
      play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
      layout_prose %(#{play_symbol}#{NoBreakSpace}<a href="#{video_path}">#{video_path}</a> <em>(#{type})</em>), normalize: false, margin: 0, single_line: true
      layout_caption node, side: :bottom if node.title?
      theme_margin :block, :bottom
    else
      original_attributes = node.attributes.dup
      begin
        node.update_attributes 'target' => poster, 'link' => video_path
        #node.set_attr 'pdfwidth', '100%' unless (node.attr? 'width') || (node.attr? 'pdfwidth')
        convert_image node
      ensure
        node.attributes.replace original_attributes
      end
    end
  end

  # QUESTION can we avoid arranging fragments multiple times (conums & autofit) by eagerly preparing arranger?
  def convert_listing_or_literal node
    add_dest_for_block node if node.id

    # HACK disable built-in syntax highlighter; must be done before calling node.content!
    if node.style == 'source' && node.attributes['language'] &&
        (highlighter = node.document.attributes['source-highlighter']) && (SourceHighlighters.include? highlighter) &&
        (@capabilities[:syntax_highlighter] ? node.document.syntax_highlighter.highlight? : true)
      case highlighter
      when 'coderay'
        unless defined? ::Asciidoctor::Prawn::CodeRayEncoder
          highlighter = nil if (Helpers.require_library CodeRayRequirePath, 'coderay', :warn).nil?
        end
      when 'pygments'
        unless defined? ::Pygments
          highlighter = nil if (Helpers.require_library 'pygments', 'pygments.rb', :warn).nil?
        end
      when 'rouge'
        unless defined? ::Rouge::Formatters::Prawn
          highlighter = nil if (Helpers.require_library RougeRequirePath, 'rouge', :warn).nil?
        end
      end
      prev_subs = (subs = node.subs).dup
      # NOTE the highlight sub is only set for coderay, rouge, and pygments atm
      highlight_idx = subs.index :highlight
      # NOTE scratch? here only applies if listing block is nested inside another block
      if !highlighter || scratch?
        highlighter = nil
        if highlight_idx
          # switch the :highlight sub back to :specialcharacters
          subs[highlight_idx] = :specialcharacters
        else
          prev_subs = nil
        end
        source_string = preserve_indentation node.content, (node.attr 'tabsize')
      else
        # NOTE the source highlighter logic below handles the callouts and highlight subs
        if highlight_idx
          subs.delete_all :highlight, :callouts
        else
          subs.delete_all :specialcharacters, :callouts
        end
        # the indent guard will be added by the source highlighter logic
        source_string = preserve_indentation node.content, (node.attr 'tabsize'), false
      end
    else
      highlighter = nil
      prev_subs = nil
      source_string = preserve_indentation node.content, (node.attr 'tabsize')
    end

    bg_color_override = nil

    source_chunks = case highlighter
    when 'coderay'
      source_string, conum_mapping = extract_conums source_string
      srclang = node.attr 'language', 'text', false
      begin
        ::CodeRay::Scanners[(srclang = (srclang.start_with? 'html+') ? srclang[5..-1].to_sym : srclang.to_sym)]
      rescue ::ArgumentError
        srclang = :text
      end
      fragments = (::CodeRay.scan source_string, srclang).to_prawn
      conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
    when 'pygments'
      lexer = ::Pygments::Lexer.find_by_alias(node.attr 'language', 'text', false) || ::Pygments::Lexer.find_by_mimetype('text/plain')
      lexer_opts = {
        nowrap: true,
        noclasses: true,
        stripnl: false,
        style: (style = (node.document.attr 'pygments-style') || 'pastie')
      }
      lexer_opts[:startinline] = !(node.option? 'mixed') if lexer.name == 'PHP'
      # TODO enable once we support background color on spans
      #if node.attr? 'highlight', nil, false
      #  unless (hl_lines = node.resolve_lines_to_highlight(node.attr 'highlight', nil, false)).empty?
      #    pygments_config[:hl_lines] = hl_lines * ' '
      #  end
      #end
      # QUESTION should we treat white background as inherit?
      # QUESTION allow border color to be set by theme for highlighted block?
      if (node.document.attr? 'pygments-bgcolor')
        bg_color_override = node.document.attr 'pygments-bgcolor'
      elsif style == 'pastie'
        node.document.set_attr 'pygments-bgcolor', (bg_color_override = nil)
      else
        node.document.set_attr 'pygments-bgcolor',
            (bg_color_override = PygmentsBgColorRx =~ (::Pygments.css '.highlight', style: style) ? $1 : nil)
      end
      source_string, conum_mapping = extract_conums source_string
      # NOTE pygments.rb strips trailing whitespace; preserve it in case there are conums on last line
      num_trailing_spaces = source_string.length - (source_string = source_string.rstrip).length if conum_mapping
      # NOTE highlight can return nil if something goes wrong; fallback to encoded source string if this happens
      result = (lexer.highlight source_string, options: lexer_opts) || (node.apply_subs source_string, [:specialcharacters])
      if (linenums = node.attr? 'linenums')
        linenums = (node.attr 'start', 1, false).to_i
        @theme.code_linenum_font_color ||= '999999'
        conum_mapping ||= {}
      end
      fragments = text_formatter.format result
      fragments = restore_conums fragments, conum_mapping, num_trailing_spaces, linenums if conum_mapping
      fragments = guard_indentation fragments
    when 'rouge'
      if (srclang = node.attr 'language', nil, false)
        if srclang.include? '?'
          if (lexer = ::Rouge::Lexer.find_fancy srclang)
            unless lexer.tag != 'php' || (node.option? 'mixed') || ((lexer_opts = lexer.options).key? 'start_inline')
              lexer = lexer.class.new lexer_opts.merge 'start_inline' => true
            end
          end
        elsif (lexer = ::Rouge::Lexer.find srclang)
          lexer = lexer.new start_inline: true if lexer.tag == 'php' && !(node.option? 'mixed')
        end
      end
      lexer ||= ::Rouge::Lexers::PlainText
      formatter = (@rouge_formatter ||= ::Rouge::Formatters::Prawn.new theme: (node.document.attr 'rouge-style'), line_gap: @theme.code_line_gap)
      formatter_opts = (node.attr? 'linenums') ? { line_numbers: true, start_line: (node.attr 'start', 1, false).to_i } : {}
      # QUESTION allow border color to be set by theme for highlighted block?
      bg_color_override = formatter.background_color
      source_string, conum_mapping = extract_conums source_string
      fragments = formatter.format((lexer.lex source_string), formatter_opts)
      # NOTE cleanup trailing endline (handled in rouge_ext/formatters/prawn instead)
      #fragments[-1][:text] == LF ? fragments.pop : fragments[-1][:text].chop!
      conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
    else
      # NOTE only format if we detect a need (callouts or inline formatting)
      (XMLMarkupRx.match? source_string) ? (text_formatter.format source_string) : [{ text: source_string }]
    end

    node.subs.replace prev_subs if prev_subs

    adjusted_font_size = ((node.option? 'autofit') || (node.document.attr? 'autofit-option')) ?
        (theme_font_size_autofit source_chunks, :code) : nil

    theme_margin :block, :top

    keep_together do |box_height = nil|
      caption_height = node.title? ? (layout_caption node) : 0
      theme_font :code do
        if box_height
          float do
            # TODO move the multi-page logic to theme_fill_and_stroke_bounds
            unless (b_width = @theme.code_border_width || 0) == 0
              b_radius = (@theme.code_border_radius || 0) + b_width
              b_gap_color = bg_color_override || @theme.code_background_color || @page_bg_color
            end
            remaining_height = box_height - caption_height
            i = 0
            while remaining_height > 0
              advance_page if (started_new_page = i > 0)
              fill_height = [remaining_height, cursor].min
              bounding_box [0, cursor], width: bounds.width, height: fill_height do
                theme_fill_and_stroke_bounds :code, background_color: bg_color_override
                unless b_width == 0
                  indent b_radius, b_radius do
                    # dashed line to indicate continuation from previous page
                    stroke_horizontal_rule b_gap_color, line_width: b_width, line_style: :dashed
                  end if started_new_page
                  if remaining_height > fill_height
                    move_down fill_height
                    indent b_radius, b_radius do
                      # dashed line to indicate continuation on next page
                      stroke_horizontal_rule b_gap_color, line_width: b_width, line_style: :dashed
                    end
                  end
                end
              end
              remaining_height -= fill_height
              i += 1
            end
          end
        end

        pad_box @theme.code_padding do
          typeset_formatted_text source_chunks, (calc_line_metrics @theme.code_line_height),
              # QUESTION should we require the code_font_color to be set?
              color: (@theme.code_font_color || @font_color),
              size: adjusted_font_size
        end
      end
    end
    stroke_horizontal_rule @theme.caption_border_bottom_color if node.title? && @theme.caption_border_bottom_color

    theme_margin :block, :bottom
  end

  alias convert_listing convert_listing_or_literal
  alias convert_literal convert_listing_or_literal

  # Extract callout marks from string, indexed by 0-based line number
  # Return an Array with the processed string as the first argument
  # and the mapping of lines to conums as the second.
  def extract_conums string
    conum_mapping = {}
    auto_num = 0
    string = string.split(LF).map.with_index {|line, line_num|
      # FIXME we get extra spaces before numbers if more than one on a line
      if line.include? '<'
        line.gsub(CalloutExtractRx) {
          # honor the escape
          if $1 == ?\\
            $&.sub $1, ''
          else
            (conum_mapping[line_num] ||= []) << ($3 == '.' ? (auto_num += 1) : $3.to_i)
            ''
          end
        }
      else
        line
      end
    } * LF
    conum_mapping = nil if conum_mapping.empty?
    [string, conum_mapping]
  end

  # Restore the conums into the Array of formatted text fragments
  #--
  # QUESTION can this be done more efficiently?
  # QUESTION can we reuse arrange_fragments_by_line?
  def restore_conums fragments, conum_mapping, num_trailing_spaces = 0, linenums = nil
    lines = []
    line_num = 0
    # reorganize the fragments into an array of lines
    fragments.each do |fragment|
      line = (lines[line_num] ||= [])
      if (text = fragment[:text]) == LF
        line_num += 1
      elsif text.include? LF
        text.split(LF, -1).each_with_index do |line_in_fragment, idx|
          line = (lines[line_num += 1] ||= []) unless idx == 0
          line << (fragment.merge text: line_in_fragment) unless line_in_fragment.empty?
        end
      else
        line << fragment
      end
    end
    conum_color = @theme.conum_font_color
    last_line_num = lines.size - 1
    if linenums
      pad_size = (last_line_num + 1).to_s.length
      linenum_color = @theme.code_linenum_font_color
    end
    # append conums to appropriate lines, then flatten to an array of fragments
    lines.flat_map.with_index do |line, cur_line_num|
      last_line = cur_line_num == last_line_num
      line.unshift text: %(#{(cur_line_num + linenums).to_s.rjust pad_size} ), color: linenum_color if linenums
      if (conums = conum_mapping.delete cur_line_num)
        line << { text: ' ' * num_trailing_spaces } if last_line && num_trailing_spaces > 0
        conum_text = conums.map {|num| conum_glyph num } * ' '
        line << (conum_color ? { text: conum_text, color: conum_color } : { text: conum_text })
      end
      line << { text: LF } unless last_line
      line
    end
  end

  def conum_glyph number
    # FIXME make starting glyph a constant and/or theme setting
    # FIXME use lookup table for glyphs instead of relying on counting
    # \u2460 = circled one, \u24f5 = double circled one, \u278b = negative circled one
    glyph = %(\u2460)
    (number - 1).times { glyph = glyph.next }
    glyph
  end

  # Adds guards to preserve indentation
  def guard_indentation fragments
    start_of_line = true
    fragments.each do |fragment|
      next if (text = fragment[:text]).empty?
      text[0] = GuardedIndent if start_of_line && (text.start_with? ' ')
      text.gsub! InnerIndent, GuardedInnerIndent if text.include? InnerIndent
      start_of_line = text.end_with? LF
    end
    fragments
  end

  def convert_table node
    add_dest_for_block node if node.id
    # TODO we could skip a lot of the logic below when num_rows == 0
    num_rows = node.attr 'rowcount'
    num_cols = node.columns.size
    table_header = false
    theme = @theme

    tbl_bg_color = resolve_theme_color :table_background_color
    # QUESTION should we fallback to page background color? (which is never transparent)
    #tbl_bg_color = resolve_theme_color :table_background_color, @page_bg_color
    # ...and if so, should we try to be helpful and use @page_bg_color for tables nested in blocks?
    #unless tbl_bg_color
    #  tbl_bg_color = @page_bg_color unless [:section, :document].include? node.parent.context
    #end

    # NOTE emulate table bg color by using it as a fallback value for each element
    head_bg_color = resolve_theme_color :table_head_background_color, tbl_bg_color
    foot_bg_color = resolve_theme_color :table_foot_background_color, tbl_bg_color
    body_bg_color = resolve_theme_color :table_body_background_color,
        # table_odd_row_background_color is deprecated
        (resolve_theme_color :table_odd_row_background_color, tbl_bg_color)
    body_stripe_bg_color = resolve_theme_color :table_body_stripe_background_color,
        # table_even_row_background_color is deprecated
        (resolve_theme_color :table_even_row_background_color, tbl_bg_color)

    table_data = []
    node.rows[:head].each do |row|
      table_header = true
      head_transform = resolve_text_transform :table_head_text_transform, nil
      row_data = []
      row.each do |cell|
        row_data << {
          content: (head_transform ? (transform_text cell.text, head_transform) : cell.text),
          inline_format: [normalize: true],
          background_color: head_bg_color,
          text_color: (theme.table_head_font_color || theme.table_font_color || @font_color),
          size: (theme.table_head_font_size || theme.table_font_size),
          font: (theme.table_head_font_family || theme.table_font_family),
          font_style: (val = theme.table_head_font_style || theme.table_font_style) ? val.to_sym : nil,
          colspan: cell.colspan || 1,
          rowspan: cell.rowspan || 1,
          align: (cell.attr 'halign', nil, false).to_sym,
          valign: (val = cell.attr 'valign', nil, false) == 'middle' ? :center : val.to_sym,
          padding: theme.table_head_cell_padding || theme.table_cell_padding,
        }
      end
      table_data << row_data
    end

    header_cell_data_cache = nil
    (node.rows[:body] + node.rows[:foot]).each do |row|
      row_data = []
      row.each do |cell|
        cell_data = {
          text_color: (theme.table_font_color || @font_color),
          size: theme.table_font_size,
          font: theme.table_font_family,
          colspan: cell.colspan || 1,
          rowspan: cell.rowspan || 1,
          align: (cell.attr 'halign', nil, false).to_sym,
          valign: (val = cell.attr 'valign', nil, false) == 'middle' ? :center : val.to_sym,
          padding: theme.table_cell_padding
        }
        cell_transform = nil
        case cell.style
        when :emphasis
          cell_data[:font_style] = :italic
          cell_line_metrics = calc_line_metrics theme.base_line_height
        when :strong
          cell_data[:font_style] = :bold
          cell_line_metrics = calc_line_metrics theme.base_line_height
        when :header
          unless header_cell_data_cache
            header_cell_data_cache = {}
            [
              #['align', :align, true], # QUESTION should we honor alignment set by col/cell spec? how can we tell?
              ['font_color', :text_color, false],
              ['font_family', :font, false],
              ['font_size', :size, false],
              ['font_style', :font_style, true],
              ['text_transform', :text_transform, true]
            ].each do |(theme_key, data_key, symbol_value)|
              if (val = theme[%(table_header_cell_#{theme_key})] || theme[%(table_head_#{theme_key})])
                header_cell_data_cache[data_key] = symbol_value ? val.to_sym : val
              end
            end
            if (val = resolve_theme_color :table_header_cell_background_color, head_bg_color)
              header_cell_data_cache[:background_color] = val
            end
          end
          header_cell_data = header_cell_data_cache.dup
          cell_transform = resolve_text_transform header_cell_data, nil
          cell_data.update header_cell_data unless header_cell_data.empty?
          cell_line_metrics = calc_line_metrics theme.base_line_height
        when :monospaced
          cell_data[:font] = theme.literal_font_family
          if (val = theme.literal_font_size)
            cell_data[:size] = val
          end
          if (val = theme.literal_font_color)
            cell_data[:text_color] = val
          end
          cell_line_metrics = calc_line_metrics theme.base_line_height
        when :literal
          # FIXME core should not substitute in this case
          cell_data[:content] = preserve_indentation((cell.instance_variable_get :@text), (node.document.attr 'tabsize'))
          # NOTE the absence of the inline_format option implies it's disabled
          # QUESTION should we use literal_font_*, code_font_*, or introduce another category?
          cell_data[:font] = theme.code_font_family
          if (val = theme.code_font_size)
            cell_data[:size] = val
          end
          if (val = theme.code_font_color)
            cell_data[:text_color] = val
          end
          cell_line_metrics = calc_line_metrics theme.code_line_height
        when :verse
          cell_data[:content] = preserve_indentation cell.text, (node.document.attr 'tabsize')
          cell_data[:inline_format] = true
          cell_line_metrics = calc_line_metrics theme.base_line_height
        when :asciidoc
          asciidoc_cell = ::Prawn::Table::Cell::AsciiDoc.new self,
              (cell_data.merge content: cell.inner_document, font_style: (val = theme.table_font_style) ? val.to_sym : nil)
          cell_data = { content: asciidoc_cell }
        else
          cell_data[:font_style] = (val = theme.table_font_style) ? val.to_sym : nil
          cell_line_metrics = calc_line_metrics theme.base_line_height
        end
        if cell_line_metrics
          if ::Array === (cell_padding = cell_data[:padding]) && cell_padding.size == 4
            cell_padding = cell_padding.dup
          else
            cell_padding = cell_data[:padding] = inflate_padding cell_padding
          end
          cell_padding[0] += cell_line_metrics.padding_top
          cell_padding[2] += cell_line_metrics.padding_bottom
          cell_data[:leading] = cell_line_metrics.leading
          # TODO patch prawn-table to pass through final_gap option
          #cell_data[:final_gap] = cell_line_metrics.final_gap
        end
        unless cell_data.key? :content
          if (cell_text = cell_transform ? (transform_text cell.text, cell_transform) : cell.text).include? LF
            # NOTE effectively the same as calling cell.content (should we use that instead?)
            # FIXME hard breaks not quite the same result as separate paragraphs; need custom cell impl here
            cell_data[:content] = (cell_text.split BlankLineRx).map {|l| l.tr_s WhitespaceChars, ' ' }.join DoubleLF
            cell_data[:inline_format] = true
          else
            cell_data[:content] = cell_text
            cell_data[:inline_format] = [normalize: true]
          end
        end
        row_data << cell_data
      end
      table_data << row_data
    end

    # NOTE Prawn aborts if table data is empty, so ensure there's at least one row
    if table_data.empty?
      empty_row = []
      node.columns.each do
        empty_row << { content: '' }
      end
      table_data = [empty_row]
    end

    border_width = {}
    table_border_color = theme.table_border_color || theme.table_grid_color || theme.base_border_color
    table_border_style = (theme.table_border_style || :solid).to_sym
    table_border_width = theme.table_border_width
    if table_header
      head_border_bottom_color = theme.table_head_border_bottom_color || table_border_color
      head_border_bottom_style = (theme.table_head_border_bottom_style || table_border_style).to_sym
      head_border_bottom_width = theme.table_head_border_bottom_width || table_border_width
    end
    [:top, :bottom, :left, :right].each {|edge| border_width[edge] = table_border_width }
    table_grid_color = theme.table_grid_color || table_border_color
    table_grid_style = (theme.table_grid_style || table_border_style).to_sym
    table_grid_width = theme.table_grid_width || theme.table_border_width
    [:cols, :rows].each {|edge| border_width[edge] = table_grid_width }

    case (grid = node.attr 'grid', 'all', 'table-grid')
    when 'all'
      # keep inner borders
    when 'cols'
      border_width[:rows] = 0
    when 'rows'
      border_width[:cols] = 0
    else # none
      border_width[:rows] = border_width[:cols] = 0
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
      table_width = (node.attr? 'width', nil, false) ? bounds.width * ((node.attr 'tablepcwidth') / 100.0) :
          ((node.has_role? 'spread') ? bounds.width : nil)
      column_widths = []
    else
      table_width = bounds.width * ((node.attr 'tablepcwidth') / 100.0)
      column_widths = node.columns.map {|col| ((col.attr 'colpcwidth') * table_width) / 100.0 }
      # NOTE until Asciidoctor 1.5.4, colpcwidth values didn't always add up to 100%; use last column to compensate
      unless column_widths.empty? || (width_delta = table_width - column_widths.reduce(:+)) == 0
        column_widths[-1] += width_delta
      end
    end

    if ((alignment = node.attr 'align', nil, false) && (BlockAlignmentNames.include? alignment)) ||
        (alignment = (node.roles & BlockAlignmentNames)[-1])
      alignment = alignment.to_sym
    else
      alignment = :left
    end

    caption_side = (theme.table_caption_side || :top).to_sym
    caption_max_width = (theme.table_caption_max_width || 'fit-content').to_s

    table_settings = {
      header: table_header,
      position: alignment,
      cell_style: {
        # NOTE the border color and style of the outer frame is set later
        border_color: table_grid_color,
        border_lines: [table_grid_style],
        # NOTE the border width is set later
        border_width: 0
      },
      width: table_width,
      column_widths: column_widths
    }

    # QUESTION should we support nth; should we support sequence of roles?
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

    theme_margin :block, :top

    table table_data, table_settings do
      # NOTE call width to capture resolved table width
      table_width = width
      caption_max_width = caption_max_width == 'fit-content' ? table_width : nil
      @pdf.layout_table_caption node, alignment, caption_max_width if node.title? && caption_side == :top
      if grid == 'none' && frame == 'none'
        if table_header
          rows(0).tap do |r|
            r.border_bottom_color = head_border_bottom_color
            r.border_bottom_line = head_border_bottom_style
            r.border_bottom_width = head_border_bottom_width
          end
        end
      else
        # apply the grid setting first across all cells
        cells.border_width = [border_width[:rows], border_width[:cols], border_width[:rows], border_width[:cols]]

        if table_header
          rows(0).tap do |r|
            r.border_bottom_color = head_border_bottom_color
            r.border_bottom_line = head_border_bottom_style
            r.border_bottom_width = head_border_bottom_width
          end
          rows(1).tap do |r|
            r.border_top_color = head_border_bottom_color
            r.border_top_line = head_border_bottom_style
            r.border_top_width = head_border_bottom_width
          end if num_rows > 1
        end

        # top edge of table
        rows(0).tap do |r|
          r.border_top_color, r.border_top_line, r.border_top_width = table_border_color, table_border_style, border_width[:top]
        end
        # right edge of table
        columns(num_cols - 1).tap do |r|
          r.border_right_color, r.border_right_line, r.border_right_width = table_border_color, table_border_style, border_width[:right]
        end
        # bottom edge of table
        rows(num_rows - 1).tap do |r|
          r.border_bottom_color, r.border_bottom_line, r.border_bottom_width = table_border_color, table_border_style, border_width[:bottom]
        end
        # left edge of table
        columns(0).tap do |r|
          r.border_left_color, r.border_left_line, r.border_left_width = table_border_color, table_border_style, border_width[:left]
        end
      end

      # QUESTION should cell padding be configurable for foot row cells?
      unless node.rows[:foot].empty?
        foot_row = row(num_rows - 1)
        foot_row.background_color = foot_bg_color
        # FIXME find a way to do this when defining the cells
        foot_row.text_color = theme.table_foot_font_color if theme.table_foot_font_color
        foot_row.size = theme.table_foot_font_size if theme.table_foot_font_size
        foot_row.font = theme.table_foot_font_family if theme.table_foot_font_family
        foot_row.font_style = theme.table_foot_font_style.to_sym if theme.table_foot_font_style
        # HACK we should do this transformation when creating the cell
        #if (foot_transform = resolve_text_transform :table_foot_text_transform, nil)
        #  foot_row.each {|c| c.content = (transform_text c.content, foot_transform) if c.content }
        #end
      end
    end
    layout_table_caption node, alignment, caption_max_width, caption_side if node.title? && caption_side == :bottom
    theme_margin :block, :bottom
  end

  def convert_thematic_break node
    theme_margin :thematic_break, :top
    stroke_horizontal_rule @theme.thematic_break_border_color, line_width: @theme.thematic_break_border_width, line_style: @theme.thematic_break_border_style.to_sym
    theme_margin :thematic_break, :bottom
  end

  # deprecated
  alias convert_horizontal_rule convert_thematic_break

  # NOTE manual placement not yet possible, so return nil
  def convert_toc node
    nil
  end

  # NOTE to insert sequential page breaks, you must put {nbsp} between page breaks
  def convert_page_break node
    if (page_layout = node.attr 'page-layout').nil_or_empty?
      unless node.role? && (page_layout = (node.roles.map(&:to_sym) & PageLayouts)[-1])
        page_layout = nil
      end
    elsif !PageLayouts.include?(page_layout = page_layout.to_sym)
      page_layout = nil
    end

    if at_page_top?
      if page_layout && page_layout != page.layout && page_is_empty?
        delete_page
        advance_page layout: page_layout
      end
    elsif page_layout
      advance_page layout: page_layout
    else
      advance_page
    end
  end

  def convert_index_section node
    unless @index.empty?
      space_needed_for_category = @theme.description_list_term_spacing + (2 * (height_of_typeset_text 'A'))
      column_box [0, cursor], columns: 2, width: bounds.width, reflow_margins: true do
        @index.categories.each do |category|
          # NOTE cursor method always returns 0 inside column_box; breaks reference_bounds.move_past_bottom
          bounds.move_past_bottom if space_needed_for_category > y - reference_bounds.absolute_bottom
          layout_prose category.name,
            align: :left,
            inline_format: false,
            margin_top: 0,
            margin_bottom: @theme.description_list_term_spacing,
            style: @theme.description_list_term_font_style.to_sym
          category.terms.each do |term|
            convert_index_list_item term
          end
          if @theme.prose_margin_bottom > y - reference_bounds.absolute_bottom
            bounds.move_past_bottom
          else
            move_down @theme.prose_margin_bottom
          end
        end
      end
    end
    nil
  end

  def convert_index_list_item term
    text = escape_xml term.name
    unless term.container?
      if @media == 'screen'
        pagenums = term.dests.map {|dest| %(<a anchor="#{dest[:anchor]}">#{dest[:page]}</a>) }
      else
        pagenums = consolidate_ranges term.dests.uniq {|dest| dest[:page] }.map {|dest| dest[:page].to_s }
      end
      text = %(#{text}, #{pagenums * ', '})
    end
    layout_prose text, align: :left, margin: 0

    term.subterms.each do |subterm|
      indent @theme.description_list_description_indent do
        convert_index_list_item subterm
      end
    end unless term.leaf?
  end

  def convert_inline_anchor node
    case node.type
    when :link
      attrs = []
      #attrs << %( id="#{node.id}") if node.id
      if (role = node.role)
        attrs << %( class="#{role}")
      end
      #attrs << %( title="#{node.attr 'title'}") if node.attr? 'title'
      attrs << %( target="#{node.attr 'window'}") if node.attr? 'window', nil, false
      if (role = node.attr 'role', nil, false) && (role == 'bare' || ((role.split ' ').include? 'bare'))
        # QUESTION should we insert breakable chars into URI when building fragment instead?
        %(<a href="#{node.target}"#{attrs.join}>#{breakable_uri node.text}</a>)
      # NOTE @media may not be initialized if method is called before convert phase
      elsif (@media ||= node.document.attr 'media', 'screen') != 'screen' || (node.document.attr? 'show-link-uri')
        # QUESTION should we insert breakable chars into URI when building fragment instead?
        # TODO allow style of printed link to be controlled by theme
        %(<a href="#{target = node.target}"#{attrs.join}>#{node.text}</a> [<font size="0.85em">#{breakable_uri target}</font>&#93;)
      else
        %(<a href="#{node.target}"#{attrs.join}>#{node.text}</a>)
      end
    when :xref
      # NOTE non-nil path indicates this is an inter-document xref that's not included in current document
      if (path = node.attributes['path'])
        # NOTE we don't use local as that doesn't work on the web
        # NOTE for the fragment to work in most viewers, it must be #page=<N> <= document this!
        %(<a href="#{node.target}">#{node.text || path}</a>)
      elsif (refid = node.attributes['refid'])
        unless (text = node.text)
          if (refs = node.document.catalog[:refs])
            if ::Asciidoctor::AbstractNode === (ref = refs[refid])
              text = ref.xreftext((@xrefstyle ||= (node.document.attr 'xrefstyle')))
            end
          else
            # Asciidoctor < 1.5.6
            text = node.document.catalog[:ids][refid]
          end
        end
        %(<a anchor="#{derive_anchor_from_id refid}">#{text || "[#{refid}]"}</a>).gsub ']', '&#93;'
      else
        %(<a anchor="#{node.document.attr 'pdf-anchor'}">#{node.text || '[^top&#93;'}</a>)
      end
    when :ref
      # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
      # NOTE id is used instead of target starting in Asciidoctor 2.0.0
      %(<a name="#{node.target || node.id}">#{DummyText}</a>)
    when :bibref
      # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
      # NOTE technically node.text should be node.reftext, but subs have already been applied to text
      # NOTE reftext is no longer enclosed in [] starting in Asciidoctor 2.0.0
      # NOTE id is used instead of target starting in Asciidoctor 2.0.0
      if (reftext = node.reftext)
        reftext = %([#{reftext}]) unless reftext.start_with? '['
      else
        reftext = %([#{node.target || node.id}])
      end
      %(<a name="#{node.target || node.id}">#{DummyText}</a>#{reftext})
    else
      logger.warn %(unknown anchor type: #{node.type.inspect})
    end
  end

  def convert_inline_break node
    %(#{node.text}<br>)
  end

  def convert_inline_button node
    %(<button>#{(@theme.button_content || '%s').sub '%s', node.text}</button>)
  end

  def convert_inline_callout node
    if (conum_color = @theme.conum_font_color)
      # NOTE CMYK value gets flattened here, but is restored by formatted text parser
      %(<color rgb="#{conum_color}">#{conum_glyph node.text.to_i}</color>)
    else
      conum_glyph node.text.to_i
    end
  end

  def convert_inline_footnote node
    if (index = node.attr 'index') && (node.document.footnotes.find {|fn| fn.index == index })
      anchor = node.type == :xref ? '' : %(<a name="_footnoteref_#{index}">#{DummyText}</a>)
      %(#{anchor}<sup>[<a anchor="_footnotedef_#{index}">#{index}</a>]</sup>)
    elsif node.type == :xref
      # NOTE footnote reference not found
      %( <color rgb="FF0000">[#{node.text}]</color>)
    end
  end

  def convert_inline_icon node
    if node.document.attr? 'icons', 'font'
      if (icon_name = node.target).include? '@'
        icon_name, icon_set = icon_name.split '@', 2
      else
        icon_set = node.attr 'set', (node.document.attr 'icon-set', 'fa'), false
      end
      icon_set = 'fa' unless IconSets.include? icon_set
      if node.attr? 'size', nil, false
        case (size = node.attr 'size')
        when 'lg'
          size_attr = %( size="1.333em")
        when 'fw'
          size_attr = %( width="1em" align="center")
        else
          size_attr = %( size="#{size.sub 'x', 'em'}")
        end
      else
        size_attr = ''
      end
      begin
        if icon_set == 'fa'
          font_data = nil
          resolved_icon_set = FontAwesomeIconSets.find {|candidate| (font_data = icon_font_data candidate).unicode icon_name rescue nil }
          if resolved_icon_set
            icon_set = resolved_icon_set
            logger.info { %(#{icon_name} icon found in deprecated fa icon set; use #{icon_set} icon set instead) }
          else
            raise
          end
        else
          font_data = icon_font_data icon_set
        end
        # TODO support rotate and flip attributes
        %(<font name="#{icon_set}"#{size_attr}>#{font_data.unicode icon_name}</font>)
      rescue
        logger.warn %(#{icon_name} is not a valid icon name in the #{icon_set} icon set)
        %([#{node.attr 'alt'}])
      end
    else
      %([#{node.attr 'alt'}])
    end
  end

  def convert_inline_image node
    if node.type == 'icon'
      convert_inline_icon node
    else
      node.extend ::Asciidoctor::Image unless ::Asciidoctor::Image === node
      target, image_format = node.target_and_format
      if image_format == 'gif' && !(defined? ::GMagick::Image)
        logger.warn %(GIF image format not supported. Install the prawn-gmagick gem or convert #{target} to PNG.) unless scratch?
        img = %([#{node.attr 'alt'}])
      # NOTE an image with a data URI is handled using a temporary file
      elsif (image_path = resolve_image_path node, target, true, image_format)
        if ::File.readable? image_path
          width_attr = (width = preresolve_explicit_width node.attributes) ? %( width="#{width}") : nil
          img = %(<img src="#{image_path}" format="#{image_format}" alt="[#{encode_quotes node.attr 'alt'}]"#{width_attr} tmp="#{TemporaryPath === image_path}">)
        else
          logger.warn %(image to embed not found or not readable: #{image_path}) unless scratch?
          img = %([#{node.attr 'alt'}])
        end
      else
        img = %([#{node.attr 'alt'}])
      end
      (node.attr? 'link', nil, false) ? %(<a href="#{node.attr 'link'}">#{img}</a>) : img
    end
  end

  def convert_inline_indexterm node
    # NOTE indexterms not supported if text gets substituted before PDF is initialized
    return '' unless instance_variable_defined? :@index
    if scratch?
      node.type == :visible ? node.text : ''
    else
      dest = {
        anchor: (anchor_name = @index.next_anchor_name)
        # NOTE page number is added in InlineDestinationMarker
      }
      anchor = %(<a name="#{anchor_name}" type="indexterm">#{DummyText}</a>)
      if node.type == :visible
        @index.store_primary_term(sanitize(visible_term = node.text), dest)
        %(#{anchor}#{visible_term})
      else
        @index.store_term((node.attr 'terms').map {|term| sanitize term }, dest)
        anchor
      end
    end
  end

  def convert_inline_kbd node
    if (keys = node.attr 'keys').size == 1
      %(<code>#{keys[0]}</code>)
    else
      keys.map {|key| %(<code>#{key}</code>+) }.join.chop
    end
  end

  def convert_inline_menu node
    menu = node.attr 'menu'
    caret = (load_theme node.document).menu_caret_content || %( \u203a )
    if !(submenus = node.attr 'submenus').empty?
      %(<strong>#{[menu, *submenus, (node.attr 'menuitem')] * caret}</strong>)
    elsif (menuitem = node.attr 'menuitem')
      %(<strong>#{menu}#{caret}#{menuitem}</strong>)
    else
      %(<strong>#{menu}</strong>)
    end
  end

  def convert_inline_quoted node
    case node.type
    when :emphasis
      open, close, is_tag = ['<em>', '</em>', true]
    when :strong
      open, close, is_tag = ['<strong>', '</strong>', true]
    when :monospaced
      open, close, is_tag = ['<code>', '</code>', true]
    when :superscript
      open, close, is_tag = ['<sup>', '</sup>', true]
    when :subscript
      open, close, is_tag = ['<sub>', '</sub>', true]
    when :double
      open, close, is_tag = ['“', '”', false]
    when :single
      open, close, is_tag = ['‘', '’', false]
    #when :asciimath, :latexmath
    else
      open, close, is_tag = [nil, nil, false]
    end

    if (role = node.role)
      if is_tag
        quoted_text = %(#{open.chop} class="#{role}">#{node.text}#{close})
      else
        quoted_text = %(<span class="#{role}">#{open}#{node.text}#{close}</span>)
      end
    else
      quoted_text = %(#{open}#{node.text}#{close})
    end

    # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
    node.id ? %(<a name="#{node.id}">#{DummyText}</a>#{quoted_text}) : quoted_text
  end

  def layout_title_page doc
    return unless doc.header? && !doc.notitle

    prev_bg_image = @page_bg_image[side = page_side]
    prev_bg_color = @page_bg_color
    @page_bg_image[side] = (bg_image = resolve_background_image doc, @theme, 'title-page-background-image') && bg_image[0] ? bg_image : nil
    if (bg_color = resolve_theme_color :title_page_background_color)
      @page_bg_color = bg_color
    end
    # NOTE a new page will already be started if the cover image is a PDF
    start_new_page unless page_is_empty?
    start_new_page if @ppbook && verso_page?
    @page_bg_image[side] = prev_bg_image if prev_bg_image
    @page_bg_color = prev_bg_color if bg_color

    # IMPORTANT this is the first page created, so we need to set the base font
    font @theme.base_font_family, size: @theme.base_font_size

    # QUESTION allow alignment per element on title page?
    title_align = (@theme.title_page_align || @base_align).to_sym

    # TODO disallow .pdf as image type
    if (logo_image_path = (doc.attr 'title-logo-image', @theme.title_page_logo_image))
      if (logo_image_path.include? ':') && logo_image_path =~ ImageAttributeValueRx
        logo_image_path = $1
        logo_image_attrs = (AttributeList.new $2).parse ['alt', 'width', 'height']
        relative_to_imagesdir = true
      else
        logo_image_attrs = {}
        relative_to_imagesdir = false
      end
      # HACK quick fix to resolve image path relative to theme
      logo_image_path = ThemeLoader.resolve_theme_asset logo_image_path, @themesdir unless doc.attr? 'title-logo-image'
      logo_image_attrs['target'] = logo_image_path
      logo_image_attrs['align'] ||= (@theme.title_page_logo_align || title_align.to_s)
      # QUESTION should we allow theme to turn logo image off?
      logo_image_top = logo_image_attrs['top'] || @theme.title_page_logo_top || '10%'
      # FIXME delegate to method to convert page % to y value
      if logo_image_top.end_with? 'vh'
        logo_image_top = page_height - page_height * logo_image_top.to_f / 100.0
      else
        logo_image_top = bounds.absolute_top - effective_page_height * logo_image_top.to_f / 100.0
      end
      initial_y, @y = @y, logo_image_top
      # FIXME add API to Asciidoctor for creating blocks like this (extract from extensions module?)
      image_block = ::Asciidoctor::Block.new doc, :image, content_model: :empty, attributes: logo_image_attrs
      # NOTE pinned option keeps image on same page
      indent (@theme.title_page_logo_margin_left || 0), (@theme.title_page_logo_margin_right || 0) do
        convert_image image_block, relative_to_imagesdir: relative_to_imagesdir, pinned: true
      end
      @y = initial_y
    end

    # TODO prevent content from spilling to next page
    theme_font :title_page do
      doctitle = doc.doctitle partition: true
      if (title_top = @theme.title_page_title_top)
        if title_top.end_with? 'vh'
          title_top = page_height - page_height * title_top.to_f / 100.0
        else
          title_top = bounds.absolute_top - effective_page_height * title_top.to_f / 100.0
        end
        # FIXME delegate to method to convert page % to y value
        @y = title_top
      end
      move_down(@theme.title_page_title_margin_top || 0)
      indent (@theme.title_page_title_margin_left || 0), (@theme.title_page_title_margin_right || 0) do
        theme_font :title_page_title do
          layout_heading doctitle.main,
            align: title_align,
            margin: 0,
            line_height: @theme.title_page_title_line_height
        end
      end
      move_down(@theme.title_page_title_margin_bottom || 0)
      if doctitle.subtitle
        move_down(@theme.title_page_subtitle_margin_top || 0)
        indent (@theme.title_page_subtitle_margin_left || 0), (@theme.title_page_subtitle_margin_right || 0) do
          theme_font :title_page_subtitle do
            layout_heading doctitle.subtitle,
              align: title_align,
              margin: 0,
              line_height: @theme.title_page_subtitle_line_height
          end
        end
        move_down(@theme.title_page_subtitle_margin_bottom || 0)
      end
      if doc.attr? 'authors'
        move_down(@theme.title_page_authors_margin_top || 0)
        indent (@theme.title_page_authors_margin_left || 0), (@theme.title_page_authors_margin_right || 0) do
          # TODO provide an API in core to get authors as an array
          authors = (1..(doc.attr 'authorcount', 1).to_i).map {|idx|
            doc.attr(idx == 1 ? 'author' : %(author_#{idx}))
          } * (@theme.title_page_authors_delimiter || ', ')
          theme_font :title_page_authors do
            layout_prose authors,
              align: title_align,
              margin: 0,
              normalize: false
          end
        end
        move_down(@theme.title_page_authors_margin_bottom || 0)
      end
      revision_info = [(doc.attr? 'revnumber') ? %(#{doc.attr 'version-label'} #{doc.attr 'revnumber'}) : nil, (doc.attr 'revdate')].compact
      unless revision_info.empty?
        move_down(@theme.title_page_revision_margin_top || 0)
        revision_text = revision_info * (@theme.title_page_revision_delimiter || ', ')
        indent (@theme.title_page_revision_margin_left || 0), (@theme.title_page_revision_margin_right || 0) do
          theme_font :title_page_revision do
            layout_prose revision_text,
              align: title_align,
              margin: 0,
              normalize: false
          end
        end
        move_down(@theme.title_page_revision_margin_bottom || 0)
      end
    end
  end

  def layout_cover_page doc, face
    # TODO turn processing of attribute with inline image a utility function in Asciidoctor
    if (image_path = (doc.attr %(#{face}-cover-image)))
      if (image_path.include? ':') && image_path =~ ImageAttributeValueRx
        image_attrs = (AttributeList.new $2).parse ['alt', 'width']
        image_path = resolve_image_path doc, $1, true, (image_format = image_attrs['format'])
      else
        image_path = resolve_image_path doc, image_path, false
      end

      return unless image_path

      unless ::File.readable? image_path
        logger.warn %(#{face} cover image not found or readable: #{image_path})
        return
      end

      go_to_page page_count if face == :back
      if image_path.downcase.end_with? '.pdf'
        import_page image_path, advance: face != :back
      else
        image_opts = resolve_image_options image_path, image_attrs, background: true, format: image_format
        image_page image_path, (image_opts.merge canvas: true)
      end
    end
  ensure
    unlink_tmp_file image_path if image_path
  end

  def start_new_chapter chapter
    start_new_page unless at_page_top?
    # TODO must call update_colors before advancing to next page if start_new_page is called in layout_chapter_title
    start_new_page if @ppbook && verso_page? && !(chapter.option? 'nonfacing')
  end

  def layout_chapter_title node, title, opts = {}
    layout_heading title, opts
  end

  alias start_new_part start_new_chapter
  alias layout_part_title layout_chapter_title

  # QUESTION why doesn't layout_heading set the font??
  # QUESTION why doesn't layout_heading accept a node?
  def layout_heading string, opts = {}
    top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || @theme[%(heading_h#{opts[:level]}_margin_top)] || @theme.heading_margin_top
    bot_margin = margin || (opts.delete :margin_bottom) || @theme[%(heading_h#{opts[:level]}_margin_bottom)] || @theme.heading_margin_bottom
    if (transform = resolve_text_transform opts)
      string = transform_text string, transform
    end
    margin_top top_margin
    typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme[%(heading_h#{opts[:level]}_line_height)] || @theme.heading_line_height), {
      color: @font_color,
      inline_format: true,
      align: @base_align.to_sym
    }.merge(opts)
    margin_bottom bot_margin
  end

  # NOTE inline_format is true by default
  def layout_prose string, opts = {}
    top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || @theme.prose_margin_top
    bot_margin = margin || (opts.delete :margin_bottom) || @theme.prose_margin_bottom
    if (transform = resolve_text_transform opts)
      string = transform_text string, transform
    end
    # NOTE used by extensions; ensures linked text gets formatted using the link styles
    if (anchor = opts.delete :anchor)
      string = %(<a anchor="#{anchor}">#{string}</a>)
    end
    margin_top top_margin
    typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme.base_line_height), {
      color: @font_color,
      # NOTE normalize makes endlines soft (replaces "\n" with ' ')
      inline_format: [normalize: (opts.delete :normalize) != false],
      align: @base_align.to_sym
    }.merge(opts)
    margin_bottom bot_margin
  end

  def generate_manname_section node
    title = node.attr 'manname-title', 'Name'
    if (next_section = node.sections[0]) && (next_section_title = next_section.title) == next_section_title.upcase
      title = title.upcase
    end
    sect = Section.new node, 1
    sect.sectname = 'section'
    sect.id = node.attr 'manname-id'
    sect.title = title
    sect << (Block.new sect, :paragraph, source: %(#{node.attr 'manname'} - #{node.attr 'manpurpose'}))
    sect
  end

  # Render the caption and return the height of the rendered content
  # TODO allow margin to be zeroed
  def layout_caption subject, opts = {}
    mark = { cursor: cursor, page_number: page_number }
    case subject
    when ::String
      string = subject
    when ::Asciidoctor::AbstractBlock
      if subject.title?
        string = subject.captioned_title
      else
        return 0
      end
    else
      return 0
    end
    theme_font :caption do
      if (side = (opts.delete :side) || :top) == :top
        margin = { top: @theme.caption_margin_outside, bottom: @theme.caption_margin_inside }
      else
        margin = { top: @theme.caption_margin_inside, bottom: @theme.caption_margin_outside }
      end
      layout_prose string, {
        margin_top: margin[:top],
        margin_bottom: margin[:bottom],
        align: (@theme.caption_align || @base_align).to_sym,
        normalize: false
      }.merge(opts)
      if side == :top && @theme.caption_border_bottom_color
        stroke_horizontal_rule @theme.caption_border_bottom_color
        # FIXME HACK move down slightly so line isn't covered by filled area (half width of line)
        move_down 0.25
      end
    end
    # NOTE we assume we don't clear more than one page
    if page_number > mark[:page_number]
      mark[:cursor] + (bounds.top - cursor)
    else
      mark[:cursor] - cursor
    end
  end

  # Render the caption for a table and return the height of the rendered content
  def layout_table_caption node, table_alignment = :left, max_width = nil, side = :top
    if max_width && (remainder = bounds.width - max_width) > 0
      case table_alignment
      when :right
        indent(remainder) { layout_caption node, side: side }
      when :center
        side_margin = remainder * 0.5
        indent(side_margin, side_margin) { layout_caption node, side: side }
      else # :left
        indent(0, remainder) { layout_caption node, side: side }
      end
    else
      layout_caption node, side: side
    end
  end

  # NOTE num_front_matter_pages is not used during a dry run
  def layout_toc doc, num_levels = 2, toc_page_number = 2, num_front_matter_pages = 0, start_at = nil
    go_to_page toc_page_number unless (page_number == toc_page_number) || scratch?
    start_page_number = page_number
    @y = start_at if start_at
    theme_font :heading, level: 2 do
      theme_font :toc_title do
        toc_title_align = (@theme.toc_title_align || @theme.heading_h2_align || @theme.heading_align || @base_align).to_sym
        layout_heading((doc.attr 'toc-title'), align: toc_title_align)
      end
    end
    # QUESTION should we skip this whole method if num_levels < 0?
    unless num_levels < 0
      dot_leader = theme_font :toc do
        # TODO we could simplify by using nested theme_font :toc_dot_leader
        if (dot_leader_font_style = (@theme.toc_dot_leader_font_style || :normal).to_sym) != font_style
          font_style dot_leader_font_style
        end
        {
          font_color: @theme.toc_dot_leader_font_color || @font_color,
          font_style: dot_leader_font_style,
          levels: ((dot_leader_l = @theme.toc_dot_leader_levels) == 'none' ? ::Set.new :
              (dot_leader_l && dot_leader_l != 'all' ? dot_leader_l.to_s.split.map(&:to_i).to_set : (0..num_levels).to_set)),
          text: (dot_leader_text = @theme.toc_dot_leader_content || DotLeaderTextDefault),
          width: dot_leader_text.empty? ? 0 : (rendered_width_of_string dot_leader_text),
          # TODO spacer gives a little bit of room between dots and page number
          spacer: { text: NoBreakSpace, size: (spacer_font_size = @font_size * 0.25) },
          spacer_width: (rendered_width_of_char NoBreakSpace, size: spacer_font_size)
        }
      end
      line_metrics = calc_line_metrics @theme.toc_line_height
      theme_margin :toc, :top
      layout_toc_level doc.sections, num_levels, line_metrics, dot_leader, num_front_matter_pages
    end
    # NOTE range must be calculated relative to toc_page_number; absolute page number in scratch document is arbitrary
    toc_page_numbers = (toc_page_number..(toc_page_number + (page_number - start_page_number)))
    go_to_page page_count - 1 unless scratch?
    toc_page_numbers
  end

  def layout_toc_level sections, num_levels, line_metrics, dot_leader, num_front_matter_pages = 0
    # NOTE font options aren't always reliable, so store size separately
    toc_font_info = theme_font :toc do
      { font: font, size: @font_size }
    end
    sections.each do |sect|
      theme_font :toc, level: (sect.level + 1) do
        sect_title = (transform = @text_transform) ? (transform_text sect.numbered_title, transform) : sect.numbered_title
        # NOTE only write section title (excluding dots and page number) if this is a dry run
        if scratch?
          # FIXME use layout_prose
          # NOTE must wrap title in empty anchor element in case links are styled with different font family / size
          typeset_text %(<a>#{sect_title}</a>), line_metrics, inline_format: true
        else
          pgnum_label = ((sect.attr 'pdf-page-start') - num_front_matter_pages).to_s
          start_page_number = page_number
          start_cursor = cursor
          # NOTE use low-level text formatter to add anchor overlay without styling text as link & force color
          sect_title_format_override = {
            anchor: (sect_anchor = sect.attr 'pdf-anchor'),
            color: @font_color,
            styles: ((@theme[%(toc_h#{sect.level + 1}_text_decoration)] || @theme.toc_text_decoration) == 'underline' ?
                (font_styles << :underline) : font_styles)
          }
          (sect_title_fragments = text_formatter.format sect_title).each do |fragment|
            fragment.update sect_title_format_override do |key, old_val, new_val|
              key == :styles ? (old_val.merge new_val) : new_val
            end
          end
          pgnum_label_width = rendered_width_of_string pgnum_label
          indent 0, pgnum_label_width do
            typeset_formatted_text sect_title_fragments, line_metrics
          end
          end_page_number = page_number
          end_cursor = cursor
          # TODO it would be convenient to have a cursor mark / placement utility that took page number into account
          go_to_page start_page_number if start_page_number != end_page_number
          move_cursor_to start_cursor
          if dot_leader[:width] > 0 && (dot_leader[:levels].include? sect.level)
            pgnum_label_font_settings = { color: @font_color, font: font_family, size: @font_size, styles: font_styles }
            # WARNING width_of is not accurate if string must use characters from fallback font
            sect_title_width = width_of sect_title, inline_format: true
            save_font do
              # NOTE the same font is used for dot leaders throughout toc
              set_font toc_font_info[:font], toc_font_info[:size]
              font_style dot_leader[:font_style]
              num_dots = ((bounds.width - sect_title_width - dot_leader[:spacer_width] - pgnum_label_width) / dot_leader[:width]).floor
              # FIXME dots don't line up in columns if width of page numbers differ
              typeset_formatted_text [
                  { text: (dot_leader[:text] * (num_dots < 0 ? 0 : num_dots)), color: dot_leader[:font_color] },
                  dot_leader[:spacer],
                  { text: pgnum_label, anchor: sect_anchor }.merge(pgnum_label_font_settings)
                ], line_metrics, align: :right
            end
          else
            typeset_formatted_text [{ text: pgnum_label, color: @font_color, anchor: sect_anchor }], line_metrics, align: :right
          end
          go_to_page end_page_number if page_number != end_page_number
          move_cursor_to end_cursor
        end
      end
      indent @theme.toc_indent do
        layout_toc_level sect.sections, num_levels, line_metrics, dot_leader, num_front_matter_pages
      end if sect.level < num_levels
    end
  end

  # Reduce icon height to fit inside bounds.height. Icons will not render
  # properly if they are larger than the current bounds.height.
  def fit_icon_to_bounds preferred_size = 24
    (max_height = bounds.height) < preferred_size ? max_height : preferred_size
  end

  def admonition_icon_data key
    if (icon_data = @theme[%(admonition_icon_#{key})])
      (AdmonitionIcons[key] || {}).merge icon_data
    else
      AdmonitionIcons[key]
    end
  end

  # TODO delegate to layout_page_header and layout_page_footer per page
  def layout_running_content periphery, doc, opts = {}
    skip, skip_pagenums, body_start_page_number = opts[:skip] || [1, 1]
    body_start_page_number = opts[:body_start_page_number] || 1
    # NOTE find and advance to first non-imported content page to use as model page
    return unless (content_start_page = state.pages[skip..-1].index {|p| !p.imported_page? })
    content_start_page += (skip + 1)
    num_pages = page_count - skip
    prev_page_number = page_number
    go_to_page content_start_page

    # FIXME probably need to treat doctypes differently
    is_book = doc.doctype == 'book'
    header = doc.header? ? doc.header : nil
    sectlevels = (@theme[%(#{periphery}_sectlevels)] || 2).to_i
    sections = doc.find_by(context: :section) {|sect| sect.level <= sectlevels && sect != header } || []

    # FIXME we need a proper model for all this page counting
    # FIXME we make a big assumption that part & chapter start on new pages
    # index parts, chapters and sections by the visual page number on which they start
    part_start_pages = {}
    chapter_start_pages = {}
    section_start_pages = {}
    trailing_section_start_pages = {}
    sections.each do |sect|
      page_num = (sect.attr 'pdf-page-start').to_i - skip_pagenums
      if is_book && ((sect_is_part = sect.part?) || sect.chapter?)
        if sect_is_part
          part_start_pages[page_num] ||= (sect.numbered_title formal: true)
        else
          chapter_start_pages[page_num] ||= (sect.numbered_title formal: true)
          if sect.sectname == 'appendix' && !part_start_pages.empty?
            # FIXME need a better way to indicate that part has ended
            part_start_pages[page_num] = ''
          end
        end
      else
        sect_title = trailing_section_start_pages[page_num] = sect.numbered_title formal: true
        section_start_pages[page_num] ||= sect_title
      end
    end

    # index parts, chapters, and sections by the visual page number on which they appear
    parts_by_page = {}
    chapters_by_page = {}
    sections_by_page = {}
    # QUESTION should the default part be the doctitle?
    last_part = nil
    # QUESTION should we enforce that the preamble is a preface?
    last_chap = is_book ? :pre : nil
    last_sect = nil
    sect_search_threshold = 1
    (1..num_pages).each do |num|
      if (part = part_start_pages[num])
        last_part = part
        last_chap = nil
        last_sect = nil
      end
      if (chap = chapter_start_pages[num])
        last_chap = chap
        last_sect = nil
      end
      if (sect = section_start_pages[num])
        last_sect = sect
      elsif part || chap
        sect_search_threshold = num
      # NOTE we didn't find a section on this page; look back to find last section started
      elsif last_sect
        ((sect_search_threshold)..(num - 1)).reverse_each do |prev|
          if (sect = trailing_section_start_pages[prev])
            last_sect = sect
            break
          end
        end
      end
      parts_by_page[num] = last_part
      if last_chap == :pre
        if num == 1
          chapters_by_page[num] = doc.doctitle
        elsif num >= body_start_page_number
          chapters_by_page[num] = is_book ? (doc.attr 'preface-title', 'Preface') : nil
        else
          chapters_by_page[num] = doc.attr 'toc-title'
        end
      else
        chapters_by_page[num] = last_chap
      end
      sections_by_page[num] = last_sect
    end

    doctitle = doc.doctitle partition: true, use_fallback: true
    # NOTE set doctitle again so it's properly escaped
    doc.set_attr 'doctitle', doctitle.combined
    doc.set_attr 'document-title', doctitle.main
    doc.set_attr 'document-subtitle', doctitle.subtitle
    doc.set_attr 'page-count', num_pages

    pagenums_enabled = doc.attr? 'pagenums'
    attribute_missing_doc = doc.attr 'attribute-missing'
    case @media == 'prepress' ? 'physical' : (doc.attr 'pdf-folio-placement')
    when 'physical'
      folio_basis, invert_folio = :physical, false
    when 'physical-inverted'
      folio_basis, invert_folio = :physical, true
    when 'virtual-inverted'
      folio_basis, invert_folio = :virtual, true
    else
      folio_basis, invert_folio = :virtual, false
    end
    periphery_layout_cache = {}
    repeat((content_start_page..page_count), dynamic: true) do
      # NOTE don't write on pages which are imported / inserts (otherwise we can get a corrupt PDF)
      next if page.imported_page?
      pgnum_label = page_number - skip_pagenums
      pgnum_label = (RomanNumeral.new page_number, :lower) if pgnum_label < 1
      side = page_side((folio_basis == :physical ? page_number : pgnum_label), invert_folio)
      # QUESTION should allocation be per side?
      trim_styles, colspec_dict, content_dict, stamp_names = allocate_running_content_layout page, periphery, periphery_layout_cache
      # FIXME we need to have a content setting for chapter pages
      content_by_position, colspec_by_position = content_dict[side], colspec_dict[side]
      # TODO populate chapter-number
      # TODO populate numbered and unnumbered chapter and section titles
      doc.set_attr 'page-number', pgnum_label.to_s if pagenums_enabled
      # QUESTION should the fallback value be nil instead of empty string? or should we remove attribute if no value?
      doc.set_attr 'part-title', (parts_by_page[pgnum_label] || '')
      doc.set_attr 'chapter-title', (chapters_by_page[pgnum_label] || '')
      doc.set_attr 'section-title', (sections_by_page[pgnum_label] || '')
      doc.set_attr 'section-or-chapter-title', (sections_by_page[pgnum_label] || chapters_by_page[pgnum_label] || '')

      stamp stamp_names[side] if stamp_names

      theme_font periphery do
        canvas do
          bounding_box [trim_styles[:content_left][side], trim_styles[:top]], width: trim_styles[:content_width][side], height: trim_styles[:height] do
            if (trim_column_rule_width = trim_styles[:column_rule_width]) > 0
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
              # FIXME we need to have a content setting for chapter pages
              case content
              when ::Array
                # NOTE float ensures cursor position is restored and returns us to current page if we overrun
                float do
                  # NOTE bounding_box is redundant if both vertical padding and border width are 0
                  bounding_box [left, bounds.top - trim_styles[:padding][0] - trim_styles[:content_offset]], width: colwidth, height: trim_styles[:content_height] do
                    # NOTE image vposition respects padding; use negative image_vertical_align value to revert
                    image_opts = content[1].merge position: colspec[:align], vposition: trim_styles[:img_valign]
                    image content[0], image_opts rescue logger.warn %(could not embed image in running content: #{content[0]}; #{$!.message})
                  end
                end
              when ::String
                theme_font %(#{periphery}_#{side}_#{position}) do
                  # NOTE minor optimization
                  if content == '{page-number}'
                    content = pagenums_enabled ? pgnum_label.to_s : nil
                  else
                    # FIXME get apply_subs to handle drop-line w/o a warning
                    doc.set_attr 'attribute-missing', 'skip' unless attribute_missing_doc == 'skip'
                    if (content = doc.apply_subs content).include? '{'
                      # NOTE must use &#123; in place of {, not \{, to escape attribute reference
                      content = content.split(LF).delete_if {|line| SimpleAttributeRefRx.match? line } * LF
                    end
                    doc.set_attr 'attribute-missing', attribute_missing_doc unless attribute_missing_doc == 'skip'
                    if (transform = @text_transform) && transform != 'none'
                      content = transform_text content, @text_transform
                    end
                  end
                  formatted_text_box parse_text(content, color: @font_color, inline_format: [normalize: true]),
                    at: [left, bounds.top - trim_styles[:padding][0] - trim_styles[:content_offset] + (trim_styles[:valign] == :center ? font.descender * 0.5 : 0)],
                    width: colwidth,
                    height: trim_styles[:prose_content_height],
                    align: colspec[:align],
                    valign: trim_styles[:valign],
                    leading: trim_styles[:line_metrics].leading,
                    final_gap: false,
                    overflow: :truncate
                end
              end
              bounding_box [colspec[:x], bounds.top - trim_styles[:padding][0] - trim_styles[:content_offset]], width: colspec[:width], height: trim_styles[:content_height] do
                stroke_vertical_rule trim_styles[:column_rule_color], at: bounds.left, line_style: trim_styles[:column_rule_style], line_width: trim_column_rule_width
              end if trim_column_rule
              prev_position = position
            end
          end
        end
      end
    end

    go_to_page prev_page_number
    nil
  end

  def allocate_running_content_layout page, periphery, cache
    layout = page.layout
    cache[layout] ||= begin
      trim_styles = {
        line_metrics: (trim_line_metrics = calc_line_metrics @theme[%(#{periphery}_line_height)] || @theme.base_line_height),
        # NOTE we've already verified this property is set
        height: (trim_height = @theme[%(#{periphery}_height)]),
        top: periphery == :header ? page_height : trim_height,
        padding: (trim_padding = inflate_padding @theme[%(#{periphery}_padding)] || 0),
        bg_color: (resolve_theme_color %(#{periphery}_background_color).to_sym),
        border_color: (trim_border_color = resolve_theme_color %(#{periphery}_border_color).to_sym),
        border_style: (@theme[%(#{periphery}_border_style)] || :solid).to_sym,
        border_width: (trim_border_width = trim_border_color ? @theme[%(#{periphery}_border_width)] || @theme.base_border_width || 0 : 0),
        column_rule_color: (trim_column_rule_color = resolve_theme_color %(#{periphery}_column_rule_color).to_sym),
        column_rule_style: (@theme[%(#{periphery}_column_rule_style)] || :solid).to_sym,
        column_rule_width: (trim_column_rule_color ? @theme[%(#{periphery}_column_rule_width)] || 0 : 0),
        column_rule_spacing: (trim_column_rule_spacing = @theme[%(#{periphery}_column_rule_spacing)] || 0),
        valign: (val = (@theme[%(#{periphery}_vertical_align)] || :middle).to_sym) == :middle ? :center : val,
        img_valign: @theme[%(#{periphery}_image_vertical_align)],
        left: {
          recto: (trim_left_recto = @page_margin_by_side[:recto][3]),
          verso: (trim_left_verso = @page_margin_by_side[:verso][3]),
        },
        width: {
          recto: (trim_width_recto = page_width - trim_left_recto - @page_margin_by_side[:recto][1]),
          verso: (trim_width_verso = page_width - trim_left_verso - @page_margin_by_side[:verso][1]),
        },
        content_left: {
          recto: trim_left_recto + trim_padding[3],
          verso: trim_left_verso + trim_padding[3],
        },
        content_width: (trim_content_width = {
          recto: trim_width_recto - trim_padding[1] - trim_padding[3],
          verso: trim_width_verso - trim_padding[1] - trim_padding[3],
        }),
        content_height: (content_height = trim_height - trim_padding[0] - trim_padding[2] - (trim_border_width * 0.5)),
        prose_content_height: content_height - trim_line_metrics.padding_top - trim_line_metrics.padding_bottom,
        # NOTE content offset adjusts y position to account for border
        content_offset: (periphery == :footer ? trim_border_width * 0.5 : 0),
      }
      case trim_styles[:img_valign]
      when nil
        trim_styles[:img_valign] = trim_styles[:valign]
      when 'middle'
        trim_styles[:img_valign] = :center
      when 'top', 'center', 'bottom'
        trim_styles[:img_valign] = trim_styles[:img_valign].to_sym
      end

      colspec_dict = PageSides.inject({}) do |acc, side|
        side_trim_content_width = trim_content_width[side]
        if (custom_colspecs = @theme[%(#{periphery}_#{side}_columns)] || @theme[%(#{periphery}_columns)])
          case (colspecs = (custom_colspecs.to_s.tr ',', ' ').split[0..2]).size
          when 3
            colspecs = { left: colspecs[0], center: colspecs[1], right: colspecs[2] }
          when 2
            colspecs = { left: colspecs[0], center: '0', right: colspecs[1] }
          when 0, 1
            colspecs = { left: '0', center: colspecs[0] || '100', right: '0' }
          end
          tot_width = 0
          side_colspecs = colspecs.map {|col, spec|
            if (alignment_char = spec.chr).to_i.to_s != alignment_char
              alignment = AlignmentTable[alignment_char] || :left
              rel_width = spec[1..-1].to_f
            else
              alignment = :left
              rel_width = spec.to_f
            end
            tot_width += rel_width
            [col, { align: alignment, width: rel_width, x: 0 }]
          }.to_h
          # QUESTION should we allow the columns to overlap (capping width at 100%)?
          side_colspecs.each {|_, colspec| colspec[:width] = (colspec[:width] / tot_width) * side_trim_content_width }
          side_colspecs[:right][:x] = (side_colspecs[:center][:x] = side_colspecs[:left][:width]) + side_colspecs[:center][:width]
          acc[side] = side_colspecs
        else
          acc[side] = {
            left: { align: :left, width: side_trim_content_width, x: 0 },
            center: { align: :center, width: side_trim_content_width, x: 0 },
            right: { align: :right, width: side_trim_content_width, x: 0 }
          }
        end
        acc
      end

      content_dict = PageSides.inject({}) do |acc, side|
        side_content = {}
        ColumnPositions.each do |position|
          unless (val = @theme[%(#{periphery}_#{side}_#{position}_content)]).nil_or_empty?
            if (val.include? ':') && val =~ ImageAttributeValueRx
              # TODO support image URL
              if ::File.readable? (image_path = (ThemeLoader.resolve_theme_asset $1, @themesdir))
                image_attrs = (AttributeList.new $2).parse ['alt', 'width']
                image_opts = resolve_image_options image_path, image_attrs, container_size: [colspec_dict[side][position][:width], trim_styles[:content_height]], format: image_attrs['format']
                side_content[position] = [image_path, image_opts]
              else
                # NOTE allows inline image handler to report invalid reference and replace with alt text
                side_content[position] = %(image:#{image_path}[#{$2}])
              end
            else
              side_content[position] = val
            end
          end
        end
        # NOTE set fallbacks if not explicitly disabled
        if side_content.empty? && periphery == :footer && @theme[%(footer_#{side}_content)] != 'none'
          side_content = { side == :recto ? :right : :left => '{page-number}' }
        end

        acc[side] = side_content
        acc
      end

      if trim_styles[:bg_color] || trim_styles[:border_width] > 0
        stamp_names = { recto: %(#{layout}_#{periphery}_recto), verso: %(#{layout}_#{periphery}_verso) }
        PageSides.each do |side|
          create_stamp stamp_names[side] do
            canvas do
              if trim_styles[:bg_color]
                bounding_box [0, trim_styles[:top]], width: bounds.width, height: trim_styles[:height] do
                  fill_bounds trim_styles[:bg_color]
                  if trim_styles[:border_width] > 0
                    # TODO stroke_horizontal_rule should support :at
                    move_down bounds.height if periphery == :header
                    stroke_horizontal_rule trim_styles[:border_color], line_width: trim_styles[:border_width], line_style: trim_styles[:border_style]
                  end
                end
              else
                bounding_box [trim_styles[:left][side], trim_styles[:top]], width: trim_styles[:width][side], height: trim_styles[:height] do
                  # TODO stroke_horizontal_rule should support :at
                  move_down bounds.height if periphery == :header
                  stroke_horizontal_rule trim_styles[:border_color], line_width: trim_styles[:border_width], line_style: trim_styles[:border_style]
                end
              end
            end
          end
        end
      end

      [trim_styles, colspec_dict, content_dict, stamp_names]
    end
  end

  def add_outline doc, num_levels = 2, toc_page_nums = [], num_front_matter_pages = 0
    front_matter_counter = RomanNumeral.new 0, :lower
    pagenum_labels = {}

    num_front_matter_pages.times do |n|
      pagenum_labels[n] = { P: (::PDF::Core::LiteralString.new front_matter_counter.next!.to_s) }
    end

    # add labels for each content page, which is required for reader's page navigator to work correctly
    (num_front_matter_pages..(page_count - 1)).each_with_index do |n, i|
      pagenum_labels[n] = { P: (::PDF::Core::LiteralString.new %(#{i + 1})) }
    end

    outline.define do
      # FIXME use sanitize: :plain_text once available
      if (doctitle = document.sanitize(doc.doctitle use_fallback: true))
        # FIXME link to title page if there's a cover page (skip cover page and ensure blank page)
        page title: doctitle, destination: (document.dest_top 1)
      end
      page title: (doc.attr 'toc-title'), destination: (document.dest_top toc_page_nums.first) unless toc_page_nums.none?
      # QUESTION any way to get add_outline_level to invoke in the context of the outline?
      document.add_outline_level self, doc.sections, num_levels
    end

    catalog.data[:PageLabels] = state.store.ref Nums: pagenum_labels.flatten
    catalog.data[:PageMode] = :UseOutlines
    nil
  end

  # FIXME only nest inside root node if doctype=article
  def add_outline_level outline, sections, num_levels
    sections.each do |sect|
      sect_title = sanitize sect.numbered_title formal: true
      sect_destination = sect.attr 'pdf-destination'
      if (level = sect.level) == num_levels || !sect.sections?
        outline.page title: sect_title, destination: sect_destination
      elsif level <= num_levels
        outline.section sect_title, { destination: sect_destination } do
          add_outline_level outline, sect.sections, num_levels
        end
      end
    end
  end

  def write pdf_doc, target
    if target.respond_to? :write
      require_relative 'core_ext/quantifiable_stdout' unless defined? ::QuantifiableStdout
      target = ::QuantifiableStdout.new STDOUT if target == STDOUT
      pdf_doc.render target
    else
      pdf_doc.render_file target
      # QUESTION restore attributes first?
      @pdfmark.generate_file target if @pdfmark
    end
    # write scratch document if debug is enabled (or perhaps DEBUG_STEPS env)
    #get_scratch_document.render_file 'scratch.pdf'
    nil
  end

  def register_fonts font_catalog, scripts = 'latin', fonts_dir
    (font_catalog || {}).each do |key, styles|
      register_font key => styles.map {|style, path| [style.to_sym, (font_path path, fonts_dir)]}.to_h
    end

    # FIXME read kerning setting from theme!
    default_kerning true
  end

  def font_path font_file, fonts_dir
    # resolve relative to built-in font dir unless path is absolute
    ::File.absolute_path font_file, fonts_dir
  end

  def default_svg_font
    @theme.svg_font_family || @theme.base_font_family
  end

  attr_reader :allow_uri_read

  def resolve_text_transform key, use_fallback = true
    if (transform = ::Hash === key ? (key.delete :text_transform) : @theme[key.to_s])
      transform == 'none' ? nil : transform
    elsif use_fallback
      @text_transform
    end
  end

  # QUESTION should we pass a category as an argument?
  # QUESTION should we make this a method on the theme ostruct? (e.g., @theme.resolve_color key, fallback)
  def resolve_theme_color key, fallback_color = nil
    if (color = @theme[key.to_s]) && color != 'transparent'
      color
    else
      fallback_color
    end
  end

  def theme_fill_and_stroke_bounds category, opts = {}
    background_color = opts[:background_color] || @theme[%(#{category}_background_color)]
    fill_and_stroke_bounds background_color, @theme[%(#{category}_border_color)],
        line_width: @theme[%(#{category}_border_width)],
        radius: @theme[%(#{category}_border_radius)]
  end

  # Insert a top margin space unless cursor is at the top of the page.
  # Start a new page if n value is greater than remaining space on page.
  def margin_top n
    margin n, :top
  end

  # Insert a bottom margin space unless cursor is at the top of the page (not likely).
  # Start a new page if n value is greater than remaining space on page.
  def margin_bottom n
    margin n, :bottom
  end

  # Insert a margin space at the specified side unless cursor is at the top of the page.
  # Start a new page if n value is greater than remaining space on page.
  def margin n, side
    unless n == 0 || at_page_top?
      # NOTE use low-level cursor calculation to workaround cursor bug in column_box context
      if y - reference_bounds.absolute_bottom > n
        move_down n
      else
        # set cursor at top of next page
        reference_bounds.move_past_bottom
      end
    end
  end

  # Lookup margin for theme element and side, then delegate to margin method.
  # If margin value is not found, assume:
  # - 0 when side == :top
  # - @theme.vertical_spacing when side == :bottom
  def theme_margin category, side
    margin((@theme[%(#{category}_margin_#{side})] || (side == :bottom ? @theme.vertical_spacing : 0)), side)
  end

  def theme_font category, opts = {}
    result = nil
    # TODO inheriting from generic category should be an option
    if opts.key? :level
      level = opts[:level]
      family = @theme[%(#{category}_h#{level}_font_family)] || @theme[%(#{category}_font_family)] || @theme.base_font_family
      size = @theme[%(#{category}_h#{level}_font_size)] || @theme[%(#{category}_font_size)] || @theme.base_font_size
      style = @theme[%(#{category}_h#{level}_font_style)] || @theme[%(#{category}_font_style)]
      color = @theme[%(#{category}_h#{level}_font_color)] || @theme[%(#{category}_font_color)]
      # NOTE global text_transform is not currently supported
      transform = @theme[%(#{category}_h#{level}_text_transform)] || @theme[%(#{category}_text_transform)]
    else
      inherited_font = font_info
      family = @theme[%(#{category}_font_family)] || inherited_font[:family]
      size = @theme[%(#{category}_font_size)] || inherited_font[:size]
      style = @theme[%(#{category}_font_style)] || inherited_font[:style]
      color = @theme[%(#{category}_font_color)]
      # NOTE global text_transform is not currently supported
      transform = @theme[%(#{category}_text_transform)]
    end

    prev_color, @font_color = @font_color, color if color
    prev_transform, @text_transform = @text_transform, (transform == 'none' ? nil : transform) if transform

    font family, size: size, style: (style && style.to_sym) do
      result = yield
    end

    @font_color = prev_color if color
    @text_transform = prev_transform if transform
    result
  end

  # Calculate the font size (down to the minimum font size) that would allow
  # all the specified fragments to fit in the available width without wrapping lines.
  #
  # Return the calculated font size if an adjustment is necessary or nil if no
  # font size adjustment is necessary.
  def theme_font_size_autofit fragments, category
    arranger = arrange_fragments_by_line fragments
    theme_font category do
      # NOTE finalizing the line here generates fragments & calculates their widths using the current font settings
      # CAUTION it also removes zero-width spaces
      arranger.finalize_line
      actual_width = width_of_fragments arranger.fragments
      unless ::Array === (padding = @theme[%(#{category}_padding)])
        padding = ::Array.new 4, padding
      end
      available_width = bounds.width - (padding[3] || 0) - (padding[1] || 0)
      if actual_width > available_width
        adjusted_font_size = ((available_width * font_size).to_f / actual_width).truncate 4
        if (min = @theme[%(#{category}_font_size_min)] || @theme.base_font_size_min) && adjusted_font_size < min
          min
        else
          adjusted_font_size
        end
      else
        nil
      end
    end
  end

  # Arrange fragments by line in an arranger and return an unfinalized arranger.
  #
  # Finalizing the arranger is deferred since it must be done in the context of
  # the global font settings you want applied to each fragment.
  def arrange_fragments_by_line fragments, opts = {}
    arranger = ::Prawn::Text::Formatted::Arranger.new self
    by_line = arranger.consumed = []
    fragments.each do |fragment|
      if (txt = fragment[:text]) == LF
        by_line << fragment
      elsif txt.include? LF
        txt.scan(LineScanRx) do |line|
          by_line << (line == LF ? { text: LF } : (fragment.merge text: line))
        end
      else
        by_line << fragment
      end
    end
    arranger
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

  # Compute the rendered width of a string, taking fallback fonts into account
  def rendered_width_of_string str, opts = {}
    if str.length == 1
      rendered_width_of_char str, opts
    elsif (chars = str.each_char).all? {|char| font.glyph_present? char }
      width_of_string str, opts
    else
      char_widths = chars.map {|char| rendered_width_of_char char, opts }
      char_widths.reduce(&:+) + (char_widths.length * character_spacing)
    end
  end

  # Compute the rendered width of a char, taking fallback fonts into account
  def rendered_width_of_char char, opts = {}
    if @fallback_fonts.empty? || (font.glyph_present? char)
      width_of_string char, opts
    else
      @fallback_fonts.each do |fallback_font|
        font fallback_font do
          return width_of_string char, opts if font.glyph_present? char
        end
      end
      width_of_string char, opts
    end
  end

  # TODO document me, esp the first line formatting functionality
  def typeset_text string, line_metrics, opts = {}
    move_down line_metrics.padding_top
    opts = { leading: line_metrics.leading, final_gap: line_metrics.final_gap }.merge opts
    if (first_line_opts = opts.delete :first_line_options)
      # TODO good candidate for Prawn enhancement!
      text_with_formatted_first_line string, first_line_opts, opts
    else
      text string, opts
    end
    move_down line_metrics.padding_bottom
  end

  # QUESTION combine with typeset_text?
  def typeset_formatted_text fragments, line_metrics, opts = {}
    move_down line_metrics.padding_top
    formatted_text fragments, { leading: line_metrics.leading, final_gap: line_metrics.final_gap }.merge(opts)
    move_down line_metrics.padding_bottom
  end

  def height_of_typeset_text string, opts = {}
    line_metrics = (calc_line_metrics opts[:line_height] || @theme.base_line_height)
    (height_of string, leading: line_metrics.leading, final_gap: line_metrics.final_gap) + line_metrics.padding_top + line_metrics.padding_bottom
  end

  def preserve_indentation string, tab_size = nil, guard_indent = true
    return '' unless string
    # expand tabs if they aren't already expanded, even if explicitly disabled
    # NOTE Asciidoctor >= 1.5.3 already replaces tabs if tabsize attribute is positive
    if ((tab_size = tab_size.to_i) < 1 || !@capabilities[:expands_tabs]) && (string.include? TAB)
      # Asciidoctor <= 1.5.2 already does tab replacement in some cases, so be consistent about tab size
      full_tab_space = ' ' * (tab_size = 4)
      result = []
      string.each_line do |line|
        if line.start_with? TAB
          if guard_indent
            # NOTE '+' operator is faster than interpolation
            line.sub!(TabIndentRx) { GuardedIndent + (full_tab_space * $&.length).chop! }
          else
            line.sub!(TabIndentRx) { full_tab_space * $&.length }
          end
          leading_space = false
        # QUESTION should we check for LF first?
        elsif line == LF
          result << line
          next
        else
          leading_space = guard_indent && (line.start_with? ' ')
        end

        if line.include? TAB
          # keep track of how many spaces were added to adjust offset in match data
          spaces_added = 0
          line.gsub!(TabRx) {
            # calculate how many spaces this tab represents, then replace tab with spaces
            if (offset = ($~.begin 0) + spaces_added) % tab_size == 0
              spaces_added += (tab_size - 1)
              full_tab_space
            else
              unless (spaces = tab_size - offset % tab_size) == 1
                spaces_added += (spaces - 1)
              end
              ' ' * spaces
            end
          }
        end

        # NOTE we save time by adding indent guard per line while performing tab expansion
        line[0] = GuardedIndent if leading_space
        result << line
      end
      result.join
    else
      if guard_indent
        string[0] = GuardedIndent if string.start_with? ' '
        string.gsub! InnerIndent, GuardedInnerIndent if string.include? InnerIndent
      end
      string
    end
  end

  # Derive a PDF-safe, ASCII-only anchor name from the given value.
  # Encodes value into hex if it contains characters outside the ASCII range.
  # If value is nil, derive an anchor name from the default_value, if given.
  def derive_anchor_from_id value, default_value = nil
    if value
      value.ascii_only? ? value : %(0x#{::PDF::Core.string_to_hex value})
    elsif default_value
      %(__anchor-#{default_value})
    end
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
  def add_dest_for_block node, id = nil
    if !scratch? && (id ||= node.id)
      dest_x = bounds.absolute_left.truncate 4
      # QUESTION when content is aligned to left margin, should we keep precise x value or just use 0?
      dest_x = 0 if dest_x <= page_margin_left
      dest_y = at_page_top? && (node.context == :section || node.context == :document) ? page_height : y
      # TODO find a way to store only the ref of the destination; look it up when we need it
      node.set_attr 'pdf-destination', (node_dest = (dest_xyz dest_x, dest_y))
      add_dest id, node_dest
    end
    nil
  end

  def resolve_alignment_from_role roles
    if (align_role = roles.reverse.find {|r| TextAlignmentRoles.include? r })
      align_role[5..-1].to_sym
    else
      nil
    end
  end

  # QUESTION is this method still necessary?
  def resolve_imagesdir doc
    if (imagesdir = doc.attr 'imagesdir').nil_or_empty? || (imagesdir = imagesdir.chomp '/') == '.'
      nil
    else
      imagesdir
    end
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
  # When a temporary file is used, the TemporaryPath type is mixed into the path string.
  def resolve_image_path node, image_path = nil, relative_to_imagesdir = true, image_format = nil
    doc = node.document
    imagesdir = relative_to_imagesdir ? (resolve_imagesdir doc) : nil
    image_path ||= node.attr 'target'
    image_format ||= ::Asciidoctor::Image.format image_path, (::Asciidoctor::Image === node ? node.attributes : nil)
    # NOTE currently used for inline images
    if ::Base64 === image_path
      tmp_image = ::Tempfile.create ['image-', image_format && %(.#{image_format})]
      tmp_image.binmode unless image_format == 'svg'
      begin
        tmp_image.write(::Base64.decode64 image_path)
        tmp_image.path.extend TemporaryPath
      rescue
        nil
      ensure
        tmp_image.close
      end
    # handle case when image is a URI
    elsif (node.is_uri? image_path) || (imagesdir && (node.is_uri? imagesdir) &&
        (image_path = (node.normalize_web_path image_path, imagesdir, false)))
      unless allow_uri_read
        logger.warn %(allow-uri-read is not enabled; cannot embed remote image: #{image_path}) unless scratch?
        return
      end
      if doc.attr? 'cache-uri'
        Helpers.require_library 'open-uri/cached', 'open-uri-cached' unless defined? ::OpenURI::Cache
      else
        ::OpenURI
      end
      tmp_image = ::Tempfile.create ['image-', image_format && %(.#{image_format})]
      tmp_image.binmode if (binary = image_format != 'svg')
      begin
        open(image_path, (binary ? 'rb' : 'r')) {|fd| tmp_image.write fd.read }
        tmp_image.path.extend TemporaryPath
      rescue
        nil
      ensure
        tmp_image.close
      end
    # handle case when image is a local file
    else
      ::File.expand_path(node.normalize_system_path image_path, imagesdir, nil, target_name: 'image')
    end
  end

  # Resolve the path and sizing of the background image either from a document attribute or theme key.
  #
  # Returns the argument list for the image method if the document attribute or theme key is found. Otherwise,
  # nothing. The first argument in the argument list is the image path. If that value is nil, the background
  # image is disabled. The second argument is the options hash to specify the dimensions, such as width and fit.
  def resolve_background_image doc, theme, key
    if (image_path = (doc.attr key) || (from_theme = theme[(key.tr '-', '_').to_sym]))
      if image_path == 'none'
        return []
      elsif (image_path.include? ':') && image_path =~ ImageAttributeValueRx
        image_attrs = (AttributeList.new $2).parse ['alt', 'width']
        # TODO support remote image when loaded from theme
        image_path = from_theme ? (ThemeLoader.resolve_theme_asset $1, @themesdir) : (resolve_image_path doc, $1, true, (image_format = image_attrs['format']))
      else
        image_path = from_theme ? (ThemeLoader.resolve_theme_asset image_path, @themesdir) : (resolve_image_path doc, image_path, false)
      end

      return unless image_path

      unless ::File.readable? image_path
        logger.warn %(#{key.tr '-', ' '} not found or readable: #{image_path})
        return
      end

      [image_path, (resolve_image_options image_path, image_attrs, background: true, format: image_format)]
    end
  end

  def resolve_image_options image_path, image_attrs, opts = {}
    if (image_format = opts[:format] || (::Asciidoctor::Image.format image_path)) == 'svg'
      image_opts = {
        enable_file_requests_with_root: (::File.dirname image_path),
        enable_web_requests: allow_uri_read,
        fallback_font_name: default_svg_font,
        format: 'svg',
      }
    else
      image_opts = {}
    end
    background = opts[:background]
    container_size = opts.fetch :container_size, (background ? [page_width, page_height] : [bounds.width, bounds.height])
    if image_attrs
      if background && (image_pos = image_attrs['position']) && (image_pos = resolve_background_position image_pos, nil)
        image_opts.update image_pos
      end
      if (image_fit = image_attrs['fit'])
        container_width, container_height = container_size
        case image_fit
        when 'none'
          if (image_width = resolve_explicit_width image_attrs, container_width)
            image_opts[:width] = image_width
          end
        when 'scale-down'
          # NOTE if width and height aren't set in SVG, real width and height are computed after stretching viewbox to fit page
          if (image_width = resolve_explicit_width image_attrs, container_width) && image_width > container_width
            image_opts[:fit] = container_size
          elsif (image_size = intrinsic_image_dimensions image_path, image_format) &&
              (image_width ? image_width * (image_size[:height] / image_size[:width]) > container_height : (to_pt image_size[:width], :px) > container_width || (to_pt image_size[:height], :px) > container_height)
            image_opts[:fit] = container_size
          elsif image_width
            image_opts[:width] = image_width
          end
        when 'cover'
          # QUESTION should we take explicit width into account?
          if (image_size = intrinsic_image_dimensions image_path, image_format)
            if container_width * (image_size[:height] / image_size[:width]) < container_height
              image_opts[:height] = container_height
            else
              image_opts[:width] = container_width
            end
          end
        else # contain
          image_opts[:fit] = container_size
        end
      elsif (image_width = resolve_explicit_width image_attrs, container_size[0])
        image_opts[:width] = image_width
      else # default to fit=contain if sizing is not specified
        image_opts[:fit] = container_size
      end
    else
      image_opts[:fit] = container_size
    end
    image_opts
  end

  # Resolves the explicit width as a PDF pt value if the value is specified in
  # absolute units, but defers resolving a percentage value until later.
  #
  # See resolve_explicit_width method for details about which attributes are considered.
  def preresolve_explicit_width attrs
    if attrs.key? 'pdfwidth'
      ((width = attrs['pdfwidth']).end_with? '%') ? width : (str_to_pt width)
    elsif attrs.key? 'scaledwidth'
      # NOTE the parser automatically appends % if value is unitless
      ((width = attrs['scaledwidth']).end_with? '%') ? width : (str_to_pt width)
    elsif attrs.key? 'width'
      # QUESTION should we honor percentage width value?
      to_pt attrs['width'].to_f, :px
    end
  end

  # Resolves the explicit width as a PDF pt value, if specified.
  #
  # Resolves the explicit width, first considering the pdfwidth attribute, then
  # the scaledwidth attribute and finally the width attribute. If the specified
  # value is in pixels, the value is scaled by 75% to perform approximate
  # CSS px to PDF pt conversion. If the resolved width is larger than the
  # max_width, the max_width value is returned.
  #--
  # QUESTION should we enforce positive result?
  def resolve_explicit_width attrs, max_width = bounds.width, opts = {}
    # QUESTION should we restrict width to max_width for pdfwidth?
    if attrs.key? 'pdfwidth'
      if (width = attrs['pdfwidth']).end_with? '%'
        (width.to_f / 100) * max_width
      elsif opts[:support_vw] && (width.end_with? 'vw')
        (width.chomp 'vw').extend ViewportWidth
      else
        str_to_pt width
      end
    elsif attrs.key? 'scaledwidth'
      # NOTE the parser automatically appends % if value is unitless
      if (width = attrs['scaledwidth']).end_with? '%'
        (width.to_f / 100) * max_width
      else
        str_to_pt width
      end
    elsif opts[:use_fallback] && (width = @theme.image_width)
      if width.end_with? '%'
        (width.to_f / 100) * max_width
      elsif opts[:support_vw] && (width.end_with? 'vw')
        (width.chomp 'vw').extend ViewportWidth
      else
        str_to_pt width
      end
    elsif attrs.key? 'width'
      # QUESTION should we honor percentage width value?
      width = to_pt attrs['width'].to_f, :px
      opts[:constrain_to_bounds] ? [max_width, width].min : width
    end
  end

  def resolve_background_position value, default_value = {}
    if value.include? ' '
      result = {}
      center = nil
      (value.split ' ', 2).each do |keyword|
        if keyword == 'left' || keyword == 'right'
          result[:position] = keyword.to_sym
        elsif keyword == 'top' || keyword == 'bottom'
          result[:vposition] = keyword.to_sym
        elsif keyword == 'center'
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

  # QUESTION is there a better way to do this?
  # I suppose we could have @tmp_files as an instance variable on converter instead
  # It might be sufficient to delete temporary files once per conversion
  # NOTE Ruby 1.9 will sometimes delete a tmp file before the process exits
  def unlink_tmp_file path
    path.unlink if TemporaryPath === path && path.exist?
  rescue
    logger.warn %(could not delete temporary image: #{path}; #{$!.message})
  end

  # NOTE assume URL is escaped (i.e., contains character references such as &amp;)
  def breakable_uri uri
    scheme, address = uri.split UriSchemeBoundaryRx, 2
    address, scheme = scheme, address unless address
    unless address.nil_or_empty?
      address = address.gsub UriBreakCharsRx, UriBreakCharRepl
      # NOTE require at least two characters after a break
      address.slice!(-2) if address[-2] == ZeroWidthSpace
    end
    %(#{scheme}#{address})
  end

  def consolidate_ranges nums
    if nums.size > 1
      prev = nil
      nums.inject([]) {|accum, num|
        if prev && (prev.to_i + 1) == num.to_i
          accum[-1][1] = num
        else
          accum << [num]
        end
        prev = num
        accum
      }.map {|range| range.join '-' }
    else
      nums
    end
  end

  # QUESTION move to prawn/extensions.rb?
  def init_scratch_prototype
    @save_state = nil
    @scratch_depth = 0
    # IMPORTANT don't set font before using Marshal, it causes serialization to fail
    @prototype = ::Marshal.load ::Marshal.dump self
    @prototype.state.store.info.data[:Scratch] = true
    # NOTE we're now starting a new page each time, so no need to do it here
    #@prototype.start_new_page if @prototype.page_number == 0
  end

  def push_scratch doc
    if (@scratch_depth += 1) == 1
      @save_state = {
        catalog: {}.tap {|accum| doc.catalog.each {|k, v| accum[k] = v.dup } },
        attributes: doc.attributes.dup,
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

=begin
  # TODO could assign pdf-anchor attributes here too
  def assign_missing_section_ids doc
    unless doc.attr? 'sectids'
      doc.attributes['sectids'] = ''
      doc.find_by(context: :section).each do |sect|
        unless sect.id
          sect.document.register(:ids, [sect.id = sect.generate_id, (sect.attributes['reftext'] || sect.title)])
        end
      end
    end
  end
=end
end
end
Pdf = PDF unless const_defined? :Pdf, false
end
