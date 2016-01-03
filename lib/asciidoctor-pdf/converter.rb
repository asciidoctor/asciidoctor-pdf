# encoding: UTF-8
# TODO cleanup imports...decide what belongs in asciidoctor-pdf.rb
require 'prawn'
require 'prawn-svg'
require 'prawn/table'
require 'prawn/templates'
require_relative 'core_ext'
require_relative 'pdf_core_ext'
require_relative 'temporary_path'
require_relative 'sanitizer'
require_relative 'prawn_ext'
require_relative 'formatted_text'
require_relative 'pdfmarks'
require_relative 'asciidoctor_ext'
require_relative 'theme_loader'
require_relative 'roman_numeral'

autoload :Tempfile, 'tempfile'

module Asciidoctor
module Pdf
class Converter < ::Prawn::Document
  include ::Asciidoctor::Converter
  include ::Asciidoctor::Writer
  include ::Asciidoctor::Prawn::Extensions

  register_for 'pdf'

  # NOTE require_library doesn't support require_relative and we don't modify the load path for this gem
  CodeRayRequirePath = ::File.join (::File.dirname __FILE__), 'prawn_ext/coderay_encoder'
  RougeRequirePath = ::File.join (::File.dirname __FILE__), 'rouge_ext'

  AsciidoctorVersion = ::Gem::Version.create ::Asciidoctor::VERSION
  AdmonitionIcons = {
    caution:   { name: 'fa-fire', stroke_color: 'BF3400', size: 24 },
    important: { name: 'fa-exclamation-circle', stroke_color: 'BF0000', size: 24 },
    note:      { name: 'fa-info-circle', stroke_color: '19407C', size: 24 },
    tip:       { name: 'fa-lightbulb-o', stroke_color: '111111', size: 24 },
    warning:   { name: 'fa-exclamation-triangle', stroke_color: 'BF6900', size: 24 }
  }
  Alignments = [:left, :center, :right]
  AlignmentNames = ['left', 'center', 'right']
  EOL = %(\n)
  TAB = %(\t)
  InnerIndent = %(\n )
  # a no-break space is used to replace a leading space to prevent Prawn from trimming indentation
  # a leading zero-width space can't be used as it gets dropped when calculating the line width
  GuardedIndent = %(\u00a0)
  GuardedInnerIndent = %(\n\u00a0)
  TabRx = /\t/
  TabIndentRx = /^\t+/
  NoBreakSpace = %(\u00a0)
  NarrowSpace = %(\u2009)
  NarrowNoBreakSpace = %(\u202f)
  ZeroWidthSpace = %(\u200b)
  HairSpace = %(\u200a)
  DotLeaderDefault = '. '
  EmDash = %(\u2014)
  LowercaseGreekA = %(\u03b1)
  Bullets = {
    disc: %(\u2022),
    circle: %(\u25e6),
    square: %(\u25aa)
  }
  # NOTE Default theme font uses ballot boxes from FontAwesome
  BallotBox = {
    checked: %(\u2611),
    unchecked: %(\u2610)
  }
  MeasurementRxt = '\\d+(?:\\.\\d+)?(?:in|cm|mm|pt|)'
  MeasurementPartsRx = /^(\d+(?:\.\d+)?)(in|mm|cm|pt|)$/
  PageSizeRx = /^(?:\[(#{MeasurementRxt}), ?(#{MeasurementRxt})\]|(#{MeasurementRxt})(?: x |x)(#{MeasurementRxt})|\S+)$/
  # CalloutExtractRx synced from /lib/asciidoctor.rb of Asciidoctor core
  CalloutExtractRx = /(?:(?:\/\/|#|--|;;) ?)?(\\)?<!?(--|)(\d+)\2>(?=(?: ?\\?<!?\2\d+\2>)*$)/
  ImageAttributeValueRx = /^image:{1,2}(.*?)\[(.*?)\]$/
  LineScanRx = /\n|.+/
  SourceHighlighters = ['coderay', 'pygments', 'rouge'].to_set

  def initialize backend, opts
    super
    basebackend 'html'
    outfilesuffix '.pdf'
    #htmlsyntax 'xml'
    @list_numbers = []
    @list_bullets = []
    @capabilities = {
      expands_tabs: (::Asciidoctor::VERSION.start_with? '1.5.3.') || AsciidoctorVersion >= (::Gem::Version.create '1.5.3')
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
      warn %(asciidoctor: WARNING: conversion missing in backend #{@backend} for #{name})
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
    # data-uri doesn't apply to PDF, so explicitly disable (is there a better place?)
    doc.attributes.delete 'data-uri'
    # set default value for pagenums if not otherwise set
    unless (doc.attribute_locked? 'pagenums') || ((doc.instance_variable_get :@attributes_modified).include? 'pagenums')
      doc.attributes['pagenums'] = ''
    end
    #assign_missing_section_ids doc

    # NOTE the on_page_create callback is called within a float context
    on_page_create do
      # TODO implement as a watermark (on top)
      if @page_bg_image
        # FIXME implement fitting and centering for SVG
        # TODO implement image scaling (numeric value or "fit")
        canvas { image @page_bg_image, position: :center, fit: [bounds.width, bounds.height] }
      elsif @page_bg_color && @page_bg_color != 'FFFFFF'
        fill_absolute_bounds @page_bg_color
      end
    end if respond_to? :on_page_create

    layout_cover_page :front, doc
    layout_title_page doc

    # NOTE a new page will already be started if the cover image is a PDF
    start_new_page unless page_is_empty?

    toc_start_page_num = page_number
    num_toc_levels = (doc.attr 'toclevels', 2).to_i
    if (include_toc = doc.attr? 'toc')
      toc_page_nums = ()
      dry_run do
        toc_page_nums = layout_toc doc, num_toc_levels, 1
      end
      # NOTE reserve pages for the toc
      toc_page_nums.each do
        start_new_page
      end
    end

    num_front_matter_pages = page_number - 1
    font @theme.base_font_family, size: @theme.base_font_size, style: @theme.base_font_style.to_sym
    convert_content_for_block doc

    # NOTE delete orphaned page (a page was created but there was no additional content)
    delete_page if page_is_empty?

    toc_page_nums = if include_toc
      layout_toc doc, num_toc_levels, toc_start_page_num, num_front_matter_pages
    else
      (0..-1)
    end

    if page_count > num_front_matter_pages
      layout_running_content :header, doc, skip: num_front_matter_pages unless doc.noheader
      layout_running_content :footer, doc, skip: num_front_matter_pages unless doc.nofooter
    end

    add_outline doc, num_toc_levels, toc_page_nums, num_front_matter_pages
    # TODO allow document (or theme) to override initial view magnification
    # NOTE add 1 to page height to force initial scroll to 0; a nil value also seems to work
    catalog.data[:OpenAction] = dest_fit_horizontally (page_height + 1), state.pages[0] if state.pages.size > 0
    catalog.data[:ViewerPreferences] = { DisplayDocTitle: true }

    layout_cover_page :back, doc
  end

  # NOTE embedded only makes sense if perhaps we are building
  # on an existing Prawn::Document instance; for now, just treat
  # it the same as a full document.
  alias :convert_embedded :convert_document

  # TODO only allow method to be called once (or we need a reset)
  def init_pdf doc
    theme = ThemeLoader.load_theme doc.attr('pdf-style'), doc.attr('pdf-stylesdir')
    @theme = theme
    pdf_opts = (build_pdf_options doc, theme)
    # QUESTION should we preserve page options (otherwise, not readily available)
    #@page_opts = { size: pdf_opts[:page_size], layout: pdf_opts[:page_layout] }
    ::Prawn::Document.instance_method(:initialize).bind(self).call pdf_opts
    # QUESTION should ThemeLoader register fonts?
    register_fonts theme.font_catalog, (doc.attr 'scripts', 'latin'), (doc.attr 'pdf-fontsdir', ThemeLoader::FontsDir)
    @page_bg_image = nil
    if (bg_image = resolve_background_image doc, theme, 'page-background-image')
      @page_bg_image = (bg_image == 'none' ? nil : bg_image)
    end
    @page_bg_color = resolve_theme_color :page_background_color, 'FFFFFF'
    @fallback_fonts = [*theme.font_fallbacks]
    @font_color = theme.base_font_color
    @text_transform = nil
    @stamps = {}
    # NOTE we have to init pdfmarks here while we have a reference to the doc
    @pdfmarks = (doc.attr? 'pdfmarks') ? (Pdfmarks.new doc) : nil
    init_scratch_prototype
    self
  end

  def build_pdf_options doc, theme
    pdf_opts = {
      #compress: true,
      #optimize_objects: true,
      info: (build_pdf_info doc),
      margin: theme.page_margin,
      page_layout: theme.page_layout.to_sym,
      skip_page_creation: true,
    }

    page_size = if (doc.attr? 'pdf-page-size') && (m = PageSizeRx.match(doc.attr 'pdf-page-size'))
      # e.g, [8.5in, 11in]
      if m[1]
        [m[1], m[2]]
      # e.g, 8.5in x 11in
      elsif m[3]
        [m[3], m[4]]
      # e.g, A4
      else
        m[0]
      end
    else
      theme.page_size
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
        elsif ::String === dim && (m = (MeasurementPartsRx.match dim))
          val = to_pt m[1].to_f, m[2]
          # NOTE 4 is the max practical precision in PDFs
          # QUESTION should we make rounding a feature of the to_pt method?
          if (val = val.round 4) == (i_val = val.to_i)
            val = i_val
          end
          val
        else
          break
        end
      end
    end

    pdf_opts[:page_size] = (page_size || 'A4')

    pdf_opts[:text_formatter] ||= FormattedText::Formatter.new theme: theme
    pdf_opts
  end

  # FIXME PdfMarks should use the PDF info result
  def build_pdf_info doc
    info = {}
    # FIXME use sanitize: :plain_text once available
    info[:Title] = str2pdfval sanitize(doc.doctitle use_fallback: true)
    if doc.attr? 'authors'
      info[:Author] = str2pdfval(doc.attr 'authors')
    end
    if doc.attr? 'subject'
      info[:Subject] = str2pdfval(doc.attr 'subject')
    end
    if doc.attr? 'keywords'
      info[:Keywords] = str2pdfval(doc.attr 'keywords')
    end
    if (doc.attr? 'publisher')
      info[:Producer] = str2pdfval(doc.attr 'publisher')
    end
    info[:Creator] = str2pdfval %(Asciidoctor PDF #{::Asciidoctor::Pdf::VERSION}, based on Prawn #{::Prawn::VERSION})
    info[:Producer] ||= (info[:Author] || info[:Creator])
    # FIXME use docdate attribute
    info[:ModDate] = info[:CreationDate] = ::Time.now unless doc.attr? 'reproducible'
    info
  end

  def convert_section sect, opts = {}
    heading_level = sect.level + 1
    theme_font :heading, level: heading_level do
      title = sect.numbered_title formal: true
      unless at_page_top?
        if sect.chapter?
          start_new_chapter sect
        # FIXME smarter calculation here!!
        elsif cursor < (height_of title) + @theme.heading_margin_top + @theme.heading_margin_bottom + @theme.base_line_height_length * 1.5
          start_new_page
        end
      end
      # QUESTION should we store page_start & destination in internal map?
      # TODO ideally, this attribute should be pdf-page-start
      sect.set_attr 'page_start', page_number
      # NOTE auto-generate an anchor if one doesn't exist so TOC works
      # QUESTION should we just assign the section this generated id?
      sect.set_attr 'anchor', (sect_anchor = sect.id || %(section-#{page_number}-#{dest_y.ceil}))
      add_dest_for_block sect, sect_anchor
      sect.chapter? ? (layout_chapter_title sect, title) : (layout_heading title)
    end

    convert_content_for_block sect
    # TODO ideally, this attribute should be pdf-page-end
    sect.set_attr 'page_end', page_number
  end

  def convert_floating_title node
    add_dest_for_block node if node.id
    theme_font :heading, level: (node.level + 1) do
      layout_heading node.title
    end
  end

  def convert_abstract node
    add_dest_for_block node if node.id
    pad_box @theme.abstract_padding do
      theme_font :abstract do
        prose_opts = { line_height: @theme.abstract_line_height }
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
    # FIXME should only use lead for first paragraph
    # add lead role to first paragraph then delegate to convert_content_for_block
    theme_font :lead do
      convert_content_for_block node
    end
  end

  # TODO add prose around image logic (use role to add special logic for headshot)
  def convert_paragraph node
    add_dest_for_block node if node.id
    is_lead = false
    prose_opts = {}
    node.roles.each do |role|
      case role
      when 'text-left'
        prose_opts[:align] = :left
      when 'text-right'
        prose_opts[:align] = :right
      when 'text-justify'
        prose_opts[:align] = :justify
      when 'text-center'
        prose_opts[:align] = :center
      when 'lead'
        is_lead = true
      #when 'signature'
      #  prose_opts[:size] = @theme.base_font_size_small
      end
    end

    # TODO check if we're within one line of the bottom of the page
    # and advance to the next page if so (similar to logic for section titles)
    layout_caption node.title if node.title?

    if is_lead
      theme_font :lead do
        layout_prose node.content, prose_opts
      end
    else
      layout_prose node.content, prose_opts
    end
  end

  # FIXME alignment of content is off
  def convert_admonition node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    icons = node.document.attr? 'icons', 'font'
    label = icons ? (node.attr 'name').to_sym : node.caption.upcase
    # FIXME this shift stuff is a real hack until we have proper margin collapsing
    shift_base = @theme.prose_margin_bottom
    #shift_top = icons ? (shift_base / 3.0) : 0
    #shift_bottom = icons ? ((shift_base * 2) / 3.0) : shift_base
    shift_top = shift_base / 3.0
    shift_bottom = (shift_base * 2) / 3.0
    keep_together do |box_height = nil|
      #theme_font :admonition do
        # FIXME this is a fudge calculation for the icon width
        label_width = icons ? (bounds.width / 12.0) : (width_of label)
        abs_left = bounds.absolute_left
        abs_right = bounds.absolute_right
        pad_box @theme.admonition_padding do
          left_padding = bounds.absolute_left - abs_left
          right_padding = abs_right - bounds.absolute_right
          if box_height
            float do
              bounding_box [0, cursor], width: label_width + right_padding, height: box_height do
                # IMPORTANT the label must fit in the alotted space or it shows up on another page!
                # QUESTION anyway to prevent text overflow in the case it doesn't fit?
                stroke_vertical_rule @theme.admonition_border_color, at: bounds.width
                # FIXME HACK make title in this location look right
                label_margin_top = node.title? ? @theme.caption_margin_inside : 0
                if icons
                  icon_data = admonition_icon_data label
                  icon icon_data[:name], {
                    valign: :center,
                    align: :center,
                    color: icon_data[:stroke_color],
                    size: (fit_icon_size node, icon_data[:size])
                  }
                else
                  layout_prose label, valign: :center, style: :bold, line_height: 1, margin_top: label_margin_top, margin_bottom: 0
                end
              end
            end
          end
          indent label_width + left_padding + right_padding do
            move_down shift_top
            layout_caption node.title if node.title?
            convert_content_for_block node
            # FIXME HACK compensate for margin bottom of admonition content
            move_up shift_bottom
          end
        end
      #end
    end
    theme_margin :block, :bottom
  end

  def convert_example node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    keep_together do |box_height = nil|
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
    end
    theme_margin :block, :bottom
  end

  def convert_open node
    case node.style
    when 'abstract'
      convert_abstract node
    when 'partintro'
      # FIXME cuts off any content beyond first paragraph!!
      if node.blocks.size == 1 && node.blocks.first.style == 'abstract'
        convert_abstract node.blocks.first
      else
        add_dest_for_block node if node.id
        convert_content_for_block node
      end
    else
      add_dest_for_block node if node.id
      convert_content_for_block node
    end
  end

  def convert_quote_or_verse node
    add_dest_for_block node if node.id
    border_width = @theme.blockquote_border_width
    theme_margin :block, :top
    keep_together do |box_height = nil|
      start_cursor = cursor
      pad_box @theme.blockquote_padding do
        theme_font :blockquote do
          if node.context == :quote
            convert_content_for_block node
          else # verse
            content = preserve_indentation node.content, (node.attr 'tabsize')
            layout_prose content, normalize: false, align: :left
          end
        end
        theme_font :blockquote_cite do
          if node.attr? 'attribution'
            layout_prose %(#{EmDash} #{[(node.attr 'attribution'), (node.attr 'citetitle')].compact * ', '}), align: :left, normalize: false
          end
        end
      end
      if box_height
        # QUESTION should we use bounding_box + stroke_vertical_rule instead?
        save_graphics_state do
          stroke_color @theme.blockquote_border_color
          line_width border_width
          stroke_vertical_line cursor, start_cursor, at: border_width / 2.0
        end
      end
    end
    theme_margin :block, :bottom
  end

  alias :convert_quote :convert_quote_or_verse
  alias :convert_verse :convert_quote_or_verse

  def convert_sidebar node
    add_dest_for_block node if node.id
    theme_margin :block, :top
    keep_together do |box_height = nil|
      if box_height
        float do
          bounding_box [0, cursor], width: bounds.width, height: box_height do
            theme_fill_and_stroke_bounds :sidebar
          end
        end
      end
      pad_box @theme.sidebar_padding do
        if node.title?
          theme_font :sidebar_title do
            # QUESTION should we allow margins of sidebar title to be customized?
            layout_heading node.title, align: @theme.sidebar_title_align.to_sym, margin_top: 0
          end
        end
        theme_font :sidebar do
          convert_content_for_block node
        end
      end
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
    @list_numbers ||= []
    # FIXME move \u2460 to constant (or theme setting)
    # \u2460 = circled one, \u24f5 = double circled one, \u278b = negative circled one
    @list_numbers << %(\u2460)
    #stroke_horizontal_rule @theme.caption_border_bottom_color
    line_metrics = calc_line_metrics @theme.base_line_height
    node.items.each_with_index do |item, idx|
      # FIXME extract to an ensure_space (or similar) method; simplify
      start_new_page if cursor < (line_metrics.height + line_metrics.leading + line_metrics.padding_top)
      convert_colist_item item
    end
    @list_numbers.pop
    # correct bottom margin of last item
    list_margin_bottom = @theme.prose_margin_bottom
    margin_bottom list_margin_bottom - @theme.outline_list_item_spacing
  end

  def convert_colist_item node
    marker_width = width_of %(#{conum_glyph 1}x)

    float do
      bounding_box [0, cursor], width: marker_width do
        @list_numbers << (index = @list_numbers.pop).next
        theme_font :conum do
          layout_prose index, align: :center, line_height: @theme.conum_line_height, inline_format: false, margin: 0
        end
      end
    end

    indent marker_width do
      convert_content_for_list_item node,
        margin_bottom: @theme.outline_list_item_spacing
    end
  end

  def convert_dlist node
    add_dest_for_block node if node.id

    # TODO check if we're within one line of the bottom of the page
    # and advance to the next page if so (similar to logic for section titles)
    layout_caption node.title if node.title?

    node.items.each do |terms, desc|
      terms = [*terms]
      # NOTE don't orphan the terms, allow for at least one line of content
      # FIXME extract ensure_space (or similar) method
      start_new_page if cursor < @theme.base_line_height_length * (terms.size + 1)
      terms.each do |term|
        layout_prose term.text, style: @theme.description_list_term_font_style.to_sym, margin_top: 0, margin_bottom: @theme.description_list_term_spacing, align: :left
      end
      if desc
        indent @theme.description_list_description_indent do
          convert_content_for_list_item desc
        end
      end
    end
  end

  def convert_olist node
    add_dest_for_block node if node.id
    @list_numbers ||= []
    list_number = case node.style
    when 'arabic'
      '1'
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
    else
      '1'
    end
    if (skip = (node.attr 'start', 1).to_i - 1) > 0
      skip.times { list_number = list_number.next  }
    end
    @list_numbers << list_number
    convert_outline_list node
    @list_numbers.pop
  end

  def convert_ulist node
    add_dest_for_block node if node.id
    if node.option? 'checklist'
      @list_bullets << :checkbox
    else
      bullet_type = if (style = node.style)
        case style
        when 'bibliography'
          :square
        else
          style.to_sym
        end
      else
        case (node.level % 3)
        when 1
          :disc
        when 2
          :circle
        when 0
          :square
        end
      end
      @list_bullets << Bullets[bullet_type]
    end
    convert_outline_list node
    @list_bullets.pop
  end

  def convert_outline_list node
    # TODO check if we're within one line of the bottom of the page
    # and advance to the next page if so (similar to logic for section titles)
    layout_caption node.title if node.title?

    line_metrics = calc_line_metrics @theme.base_line_height
    complex = false
    # ...or if we want to give all items in the list the same treatment
    #complex = node.items.find(&:complex?) ? true : false
    indent @theme.outline_list_indent do
      node.items.each do |item|
        # FIXME extract to an ensure_space (or similar) method; simplify
        start_new_page if cursor < (line_metrics.height + line_metrics.leading + line_metrics.padding_top)
        convert_outline_list_item item, item.complex?
      end
    end
    # NOTE Children will provide the necessary bottom margin if last item is complex.
    # However, don't leave gap at the bottom of a nested list
    unless complex || (::Asciidoctor::List === node.parent && node.parent.outline?)
      # correct bottom margin of last item
      list_margin_bottom = @theme.prose_margin_bottom
      margin_bottom list_margin_bottom - @theme.outline_list_item_spacing
    end
  end

  def convert_outline_list_item node, complex = false
    # TODO move this to a draw_bullet (or draw_marker) method
    case (list_type = node.parent.context)
    when :ulist
      marker = @list_bullets.last
      if marker == :checkbox
        if node.attr? 'checkbox'
          marker = BallotBox[(node.attr? 'checked') ? :checked : :unchecked]
        else
          # QUESTION should we remove marker indent in this case?
          marker = nil
        end
      end
    when :olist
      @list_numbers << (index = @list_numbers.pop).next
      marker = %(#{index}.)
    else
      warn %(asciidoctor: WARNING: unknown list type #{list_type.inspect})
      marker = Bullets[:disc]
    end

    if marker
      marker_width = width_of marker
      start_position = -marker_width + -(width_of 'x')
      float do
        bounding_box [start_position, cursor], width: marker_width do
          layout_prose marker,
            align: :right,
            color: (@theme.outline_list_marker_font_color || @font_color),
            normalize: false,
            inline_format: false,
            margin: 0,
            character_spacing: -0.5,
            single_line: true
        end
      end
    end

    if complex
      convert_content_for_list_item node
    else
      convert_content_for_list_item node,
        margin_bottom: @theme.outline_list_item_spacing
    end
  end

  def convert_content_for_list_item node, opts = {}
    if node.text?
      opts[:align] = :left if node.parent.style == 'bibliography'
      layout_prose node.text, opts
    end
    convert_content_for_block node
  end

  def convert_image node
    node.extend ::Asciidoctor::Image unless ::Asciidoctor::Image === node
    valid_image = true
    target, image_type = node.target_with_image_type

    if image_type == 'gif'
      valid_image = false
      warn %(asciidoctor: WARNING: GIF image format not supported. Please convert #{target} to PNG.)
    end

    unless (image_path = resolve_image_path node, target) && (::File.readable? image_path)
      valid_image = false
      warn %(asciidoctor: WARNING: image to embed not found or not readable: #{image_path || target})
    end

    # NOTE import_page automatically advances to next page afterwards
    return import_page image_path if image_type == 'pdf'

    # QUESTION if we advance to new page, shouldn't dest point there too?
    add_dest_for_block node if node.id
    position = ((node.attr 'align') || @theme.image_align).to_sym

    unless valid_image
      theme_margin :block, :top
      if (link = node.attr 'link')
        alt_text = %(<a href="#{link}">[#{NoBreakSpace}#{node.attr 'alt'}#{NoBreakSpace}]</a> | <em>#{target}</em>)
      else
        alt_text = %([#{NoBreakSpace}#{node.attr 'alt'}#{NoBreakSpace}] | <em>#{target}</em>)
      end
      layout_prose alt_text, normalize: false, margin: 0, single_line: true, align: position
      layout_caption node, position: :bottom if node.title?
      theme_margin :block, :bottom
      return
    end

    theme_margin :block, :top

    # NOTE image is scaled proportionally based on width (height is ignored)
    # TODO support cover (aka canvas) image layout using "canvas" (or "cover") role
    width = resolve_explicit_width node.attributes, bounds.width

    case image_type
    when 'svg'
      begin
        svg_data = ::IO.read image_path
        svg_obj = ::Prawn::Svg::Interface.new svg_data, self, position: position, width: width, fallback_font_name: default_svg_font
        svg_size = svg_obj.document.sizing
        rendered_w = svg_size.output_width
        if !width && (svg_obj.document.root.attributes.key? 'width')
          # NOTE scale native width & height by 75% to convert px to pt; restrict width to bounds.width
          if (adjusted_w = [bounds.width, rendered_w * 0.75].min) != rendered_w
            # FIXME would be nice to have a resize/recalculate method; instead, just reconstruct
            svg_obj = ::Prawn::Svg::Interface.new svg_data, self, position: position, width: (rendered_w = adjusted_w), fallback_font_name: default_svg_font
            svg_size = svg_obj.document.sizing
          end
        end
        # TODO shrink image to fit on a single page if height exceeds page height
        rendered_h = svg_size.output_height
        # TODO layout SVG without using keep_together (since we know the dimensions already); always render caption
        keep_together do |box_height = nil|
          svg_obj.instance_variable_set :@prawn, self
          svg_obj.draw
          if box_height && (link = node.attr 'link')
            link_annotation [(abs_left = svg_obj.position[0] + bounds.absolute_left), y, (abs_left + rendered_w), (y + rendered_h)],
                Border: [0, 0, 0],
                A: { Type: :Action, S: :URI, URI: (str2pdfval link) }
          end
          layout_caption node, position: :bottom if node.title?
        end
      rescue => e
        warn %(asciidoctor: WARNING: could not embed image: #{image_path}; #{e.message})
      end
    else
      begin
        # FIXME this code really needs to be better organized!
        # FIXME temporary workaround to group caption & image
        # NOTE use low-level API to access intrinsic dimensions; build_image_object caches image data previously loaded
        image_obj, image_info = build_image_object image_path
        if width
          rendered_w, rendered_h = image_info.calc_image_dimensions width: width
        else
          # NOTE scale native width & height by 75% to convert px to pt; restrict width to bounds.width
          rendered_w = [bounds.width, image_info.width * 0.75].min
          rendered_h = (rendered_w * image_info.height) / image_info.width
        end
        # TODO move this calculation into a method
        caption_height = node.title? ?
            (@theme.caption_margin_inside + @theme.caption_margin_outside + @theme.base_line_height_length) : 0
        if rendered_h > (available_height = cursor - caption_height)
          start_new_page unless at_page_top?
          # NOTE shrink image so it fits on a single page if height exceeds page height
          if rendered_h > (available_height = cursor - caption_height)
            rendered_w = (rendered_w * available_height) / rendered_h
            rendered_h = available_height
            # FIXME workaround to fix Prawn not adding fill and stroke commands
            # on page that only has an image; breakage occurs when line numbers are added
            # NOTE this no longer seems to be an issue
            fill_color self.fill_color
            stroke_color self.stroke_color
          end
        end
        # NOTE must calculate link position before embedding to get proper boundaries
        if (link = node.attr 'link')
          img_x, img_y = image_position rendered_w, rendered_h, position: position
          link_box = [img_x, (img_y - rendered_h), (img_x + rendered_w), img_y]
        end
        embed_image image_obj, image_info, width: rendered_w, position: position
        if link
          link_annotation link_box,
            Border: [0, 0, 0],
            A: { Type: :Action, S: :URI, URI: (str2pdfval link) }
        end
      rescue => e
        warn %(asciidoctor: WARNING: could not embed image: #{image_path}; #{e.message})
      end
      layout_caption node, position: :bottom if node.title?
    end
    theme_margin :block, :bottom
  ensure
    unlink_tmp_file image_path
  end

  # QUESTION can we avoid arranging fragments multiple times (conums & autofit) by eagerly preparing arranger?
  def convert_listing_or_literal node
    add_dest_for_block node if node.id

    # HACK disable built-in syntax highlighter; must be done before calling node.content!
    if node.style == 'source' && node.attributes['language'] &&
        (highlighter = node.document.attributes['source-highlighter']) &&
        (SourceHighlighters.include? highlighter)
      prev_subs = (subs = node.subs).dup
      # NOTE the highlight sub is only set for coderay and pygments atm
      highlight_idx = subs.index :highlight
      # NOTE scratch? here only applies if listing block is nested inside another block
      if scratch?
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

    source_chunks = case highlighter
    when 'coderay'
      Helpers.require_library CodeRayRequirePath, 'coderay' unless defined? ::Asciidoctor::Prawn::CodeRayEncoder
      source_string, conum_mapping = extract_conums source_string
      fragments = (::CodeRay.scan source_string, (node.attr 'language', 'text', false).to_sym).to_prawn
      conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
    when 'pygments'
      Helpers.require_library 'pygments', 'pygments.rb' unless defined? ::Pygments
      lexer = ::Pygments::Lexer[node.attr 'language', 'text', false] || ::Pygments::Lexer['text']
      pygments_config = { nowrap: true, noclasses: true, style: (node.document.attr 'pygments-style') || 'pastie' }
      source_string, conum_mapping = extract_conums source_string
      result = lexer.highlight source_string, options: pygments_config
      fragments = guard_indentation text_formatter.format result
      conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
    when 'rouge'
      Helpers.require_library RougeRequirePath, 'rouge' unless defined? ::Rouge::Formatters::Prawn
      lexer = ::Rouge::Lexer.find(node.attr 'language', 'text', false) || ::Rouge::Lexers::PlainText
      formatter = (@rouge_formatter ||= ::Rouge::Formatters::Prawn.new theme: (node.document.attr 'rouge-style'))
      source_string, conum_mapping = extract_conums source_string
      # NOTE trailing endline is added to address https://github.com/jneen/rouge/issues/279
      fragments = formatter.format (lexer.lex %(#{source_string}#{EOL})), line_numbers: (node.attr? 'linenums')
      conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
    else
      # NOTE only format if we detect a need (callouts or inline formatting)
      if source_string =~ BuiltInEntityCharOrTagRx
        text_formatter.format source_string
      else
        [{ text: source_string }]
      end
    end

    node.subs.replace prev_subs if prev_subs

    theme_margin :block, :top

    if (node.option? 'autofit') || (node.document.attr? 'autofit-option')
      adjusted_font_size = theme_font_size_autofit source_chunks, :code
    else
      adjusted_font_size = nil
    end

    keep_together do |box_height = nil|
      caption_height = node.title? ? (layout_caption node) : 0
      theme_font :code do
        if box_height
          float do
            # TODO move the multi-page logic to theme_fill_and_stroke_bounds
            unless (b_width = @theme.code_border_width || 0) == 0
              b_radius = (@theme.code_border_radius || 0) + b_width
              bg_color = @theme.code_background_color || @page_bg_color
            end
            remaining_height = box_height - caption_height
            i = 0
            while remaining_height > 0
              start_new_page if (new_page_started = i > 0)
              fill_height = [remaining_height, cursor].min
              bounding_box [0, cursor], width: bounds.width, height: fill_height do
                theme_fill_and_stroke_bounds :code
                unless b_width == 0
                  if new_page_started
                    indent b_radius, b_radius do
                      # dashed line to indicate continuation from previous page
                      stroke_horizontal_rule bg_color, line_width: b_width, line_style: :dashed
                    end
                  end
                  if remaining_height > fill_height
                    move_down fill_height
                    indent b_radius, b_radius do
                      # dashed line to indicate continuation on next page
                      stroke_horizontal_rule bg_color, line_width: b_width, line_style: :dashed
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

  alias :convert_listing :convert_listing_or_literal
  alias :convert_literal :convert_listing_or_literal

  # Extract callout marks from string, indexed by 0-based line number
  # Return an Array with the processed string as the first argument
  # and the mapping of lines to conums as the second.
  def extract_conums string
    conum_mapping = {}
    string = string.split(EOL).map.with_index {|line, line_num|
      # FIXME we get extra spaces before numbers if more than one on a line
      line.gsub(CalloutExtractRx) {
        # honor the escape
        if $1 == '\\'
          $&.sub '\\', ''
        else
          (conum_mapping[line_num] ||= []) << $3.to_i
          ''
        end
      }
    } * EOL
    conum_mapping = nil if conum_mapping.empty?
    [string, conum_mapping]
  end

  # Restore the conums into the Array of formatted text fragments
  #--
  # QUESTION can this be done more efficiently?
  # QUESTION can we reuse arrange_fragments_by_line?
  def restore_conums fragments, conum_mapping
    lines = []
    line_num = 0
    # reorganize the fragments into an array of lines
    fragments.each do |fragment|
      line = (lines[line_num] ||= [])
      if (text = fragment[:text]) == EOL
        line_num += 1
      elsif text.include? EOL
        text.split(EOL, -1).each_with_index do |line_in_fragment, idx|
          line = (lines[line_num += 1] ||= []) unless idx == 0
          line << (fragment.merge text: line_in_fragment) unless line_in_fragment.empty?
        end
      else
        line << fragment
      end
    end
    conum_color = @theme.conum_font_color
    last_line_num = lines.size - 1
    # append conums to appropriate lines, then flatten to an array of fragments
    lines.flat_map.with_index do |line, cur_line_num|
      if (conums = conum_mapping.delete cur_line_num)
        conums = conums.map {|num| conum_glyph num }
        # ensure there's at least one space between content and conum(s)
        if line.size > 0 && (end_text = line.last[:text]) && !(end_text.end_with? ' ')
          line.last[:text] = %(#{end_text} )
        end
        line << (conum_color ? { text: (conums * ' '), color: conum_color } : { text: (conums * ' ') })
      end
      line << { text: EOL } unless cur_line_num == last_line_num
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
      start_of_line = text.end_with? EOL
    end
    fragments
  end

  def convert_table node
    add_dest_for_block node if node.id
    num_rows = 0
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
    odd_row_bg_color = resolve_theme_color :table_odd_row_background_color, tbl_bg_color
    even_row_bg_color = resolve_theme_color :table_even_row_background_color, tbl_bg_color

    table_data = []
    node.rows[:head].each do |rows|
      table_header = true
      head_transform = theme.table_head_text_transform
      num_rows += 1
      row_data = []
      rows.each do |cell|
        row_data << {
          content: (head_transform ? (transform_text cell.text, head_transform) : cell.text),
          inline_format: [normalize: true],
          background_color: head_bg_color,
          text_color: (theme.table_head_font_color || theme.table_font_color || @font_color),
          size: (theme.table_head_font_size || theme.table_font_size),
          font: (theme.table_head_font_family || theme.table_font_family),
          font_style: theme.table_head_font_style.to_sym,
          colspan: cell.colspan || 1,
          rowspan: cell.rowspan || 1,
          align: (cell.attr 'halign').to_sym,
          valign: (cell.attr 'valign').to_sym
        }
      end
      table_data << row_data
    end

    (node.rows[:body] + node.rows[:foot]).each do |rows|
      num_rows += 1
      row_data = []
      rows.each do |cell|
        cell_data = {
          content: cell.text,
          inline_format: [normalize: true],
          text_color: (theme.table_body_font_color || @font_color),
          size: theme.table_font_size,
          font: theme.table_font_family,
          colspan: cell.colspan || 1,
          rowspan: cell.rowspan || 1,
          align: (cell.attr 'halign').to_sym,
          valign: (cell.attr 'valign').to_sym
        }
        cell_data[:valign] = :center if cell_data[:valign] == :middle
        case cell.style
        when :emphasis
          cell_data[:font_style] = :italic
        when :strong
          cell_data[:font_style] = :bold
        when :header
          unless defined? header_cell_data
            header_cell_data = {}
            {
              'align' => :align,
              'font_color' => :text_color,
              'font_family' => :font,
              'font_size' => :size,
              'font_style' => :font_style
            }.each do |theme_key, key|
              if (val = theme[%(table_header_cell_#{theme_key})])
                header_cell_data[key] = val
              end
            end
            header_cell_data[:font_style] ||= :bold
            if (val = resolve_theme_color :table_header_cell_background_color)
              header_cell_data[:background_color] = val
            end
          end

          cell_data.update header_cell_data unless header_cell_data.empty?
        when :monospaced
          cell_data[:font] = theme.literal_font_family
          if (size = theme.literal_font_size)
            cell_data[:size] = size
          end
          if (color = theme.literal_font_color)
            cell_data[:text_color] = color
          end
        # TODO finish me
        end
        row_data << cell_data
      end
      table_data << row_data
    end

    border = {}
    table_border_width = theme.table_border_width
    [:top, :bottom, :left, :right, :cols, :rows].each {|edge| border[edge] = table_border_width }

    frame = (node.attr 'frame') || 'all'
    grid = (node.attr 'grid') || 'all'

    case grid
    when 'cols'
      border[:rows] = 0
    when 'rows'
      border[:cols] = 0
    when 'none'
      border[:rows] = border[:cols] = 0
    end

    case frame
    when 'topbot'
      border[:left] = border[:right] = 0
    when 'sides'
      border[:top] = border[:bottom] = 0
    when 'none'
      border[:top] = border[:right] = border[:bottom] = border[:left] = 0
    end

    if node.option? 'autowidth'
      column_widths = []
    else
      table_width = bounds.width * ((node.attr 'tablepcwidth') / 100.0)
      even_column_pct = 100.0 / node.columns.size
      column_widths = node.columns.map {|col| ((col.attr 'colpcwidth', even_column_pct) * table_width) / 100.0 }
      # NOTE Asciidoctor core doesn't always add colpcwidth values up to 100%
      unless column_widths.empty? || (width_delta = table_width - column_widths.reduce(:+)).zero?
        column_widths[-1] += width_delta
      end
    end

    if ((position = node.attr 'align') && (AlignmentNames.include? position)) ||
        (position = (node.roles & AlignmentNames).last)
      position = position.to_sym
    else
      position = :left
    end

    table_settings = {
      header: table_header,
      position: position,
      cell_style: {
        padding: theme.table_cell_padding,
        border_width: 0,
        border_color: theme.table_border_color
      },
      column_widths: column_widths,
      row_colors: [odd_row_bg_color, even_row_bg_color]
    }

    theme_margin :block, :top
    layout_caption node if node.title?

    table table_data, table_settings do
      if grid == 'none' && frame == 'none'
        if table_header
          rows(0).border_bottom_width = 1.5
        end
      else
        # apply the grid setting first across all cells
        cells.border_width = [border[:rows], border[:cols], border[:rows], border[:cols]]

        if table_header
          rows(0).border_bottom_width = 1.5
        end

        # top edge of table
        rows(0).border_top_width = border[:top]
        # right edge of table
        columns(num_cols - 1).border_right_width = border[:right]
        # bottom edge of table
        rows(num_rows - 1).border_bottom_width = border[:bottom]
        # left edge of table
        columns(0).border_left_width = border[:left]
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
        #if (foot_transform = theme.table_foot_text_transform)
        #  foot_row.each {|c| c.content = (transform_text c.content, foot_transform) if c.content }
        #end
      end
    end
    theme_margin :block, :bottom
  end

  def convert_thematic_break node
    theme_margin :thematic_break, :top
    stroke_horizontal_rule @theme.thematic_break_border_color, line_width: @theme.thematic_break_border_width, line_style: @theme.thematic_break_border_style.to_sym
    theme_margin :thematic_break, :bottom
  end

  # deprecated
  alias :convert_horizontal_rule :convert_thematic_break

  # NOTE manual placement not yet possible, so return nil
  def convert_toc node
    nil
  end

  # NOTE to insert sequential page breaks, you must put {nbsp} between page breaks
  def convert_page_break node
    start_new_page unless at_page_top?
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
      attrs << %( target="#{node.attr 'window'}") if node.attr? 'window'
      if (node.document.attr? 'showlinks') && !(node.has_role? 'bare')
        # TODO allow style of visible link to be controlled by theme
        %(<a href="#{target = node.target}"#{attrs.join}>#{node.text}</a> <font size="0.9"><em>(#{target})</em></font>)
      else
        %(<a href="#{node.target}"#{attrs.join}>#{node.text}</a>)
      end
    when :xref
      # NOTE the presence of path indicates an inter-document xref
      if (path = node.attributes['path'])
        # NOTE we don't use local as that doesn't work on the web
        # NOTE for the fragment to work in most viewers, it must be #page=<N>
        %(<a href="#{node.target}">#{node.text || path}</a>)
      else
        refid = node.attributes['refid']
        # NOTE reference table is not comprehensive (we don't catalog all inline anchors)
        if (reftext = node.document.references[:ids][refid])
          %(<a anchor="#{refid}">#{node.text || reftext}</a>)
        else
          # NOTE we don't catalog all inline anchors, so we can't warn here (maybe once conversion is complete)
          #source = $VERBOSE ? %( in source:\n#{node.parent.lines * "\n"}) : nil
          #warn %(asciidoctor: WARNING: reference '#{refid}' not found#{source})
          #%[(see #{node.text || %([#{refid}])})]
          %(<a anchor="#{refid}">#{node.text || "[#{refid}]"}</a>)
        end
      end
    when :ref
      # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
      #%(<a name="#{node.target}"></a>)
      %(<a name="#{node.target}">#{ZeroWidthSpace}</a>)
    when :bibref
      # NOTE destination is created inside callback registered by FormattedTextTransform#build_fragment
      #%(<a name="#{target = node.target}"></a>[#{target}])
      %(<a name="#{target = node.target}">#{ZeroWidthSpace}</a>[#{target}])
    else
      warn %(asciidoctor: WARNING: unknown anchor type: #{node.type.inspect})
    end
  end

  def convert_inline_break node
    %(#{node.text}<br>)
  end

  def convert_inline_button node
    %(<strong>[#{NarrowNoBreakSpace}#{node.text}#{NarrowNoBreakSpace}]</strong>)
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
    if (index = node.attr 'index')
      #text = node.document.footnotes.find {|fn| fn.index == index }.text
      %( <color rgb="#999999">[#{index}: #{node.text}]</color>)
    elsif node.type == :xref
      # NOTE footnote reference not found
      %( <color rgb="FF0000">[#{node.text}]</color>)
    end
  end

  def convert_inline_image node
    img = nil
    if node.type == 'icon'
      if node.document.attr? 'icons', 'font'
        if (icon_name = node.target).include? '@'
          icon_name, icon_set = icon_name.split '@', 2
        else
          icon_set = node.attr 'set', (node.document.attr 'icon-set', 'fa')
        end
        icon_set = 'fa' unless IconSets.include? icon_set
        if node.attr? 'size'
          size = (size = (node.attr 'size')) == 'lg' ? '1.3333em' : (size.sub 'x', 'em')
          size_attr = %( size="#{size}")
        else
          size_attr = nil
        end
        begin
          # TODO support rotate and flip attributes; support fw (full-width) size
          img = %(<font name="#{icon_set}"#{size_attr}>#{::Prawn::Icon::FontData.load(self, icon_set).unicode icon_name}</font>)
        rescue
          warn %(asciidoctor: WARNING: #{icon_name} is not a valid icon name in the #{icon_set} icon set)
        end
      end
    else
      node.extend ::Asciidoctor::Image unless ::Asciidoctor::Image === node
      target, image_type = node.target_with_image_type
      valid = true
      if image_type == 'gif'
        warn %(asciidoctor: WARNING: GIF image format not supported. Please convert #{target} to PNG.) unless scratch?
        valid = false
      end
      unless (image_path = resolve_image_path node, target) && (::File.readable? image_path)
        warn %(asciidoctor: WARNING: image to embed not found or not readable: #{image_path || target}) unless scratch?
        valid = false
      end
      if valid
        width_attr = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : nil
        img = %(<img src="#{image_path}" type="#{image_type}" alt="#{node.attr 'alt'}"#{width_attr} tmp="#{TemporaryPath === image_path}">)
      end
    end
    img ||= %([#{node.attr 'alt'}])
    (node.attr? 'link') ? %(<a href="#{node.attr 'link'}">#{img}</a>) : img
  end

  def convert_inline_indexterm node
    node.type == :visible ? node.text : nil
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
    if !(submenus = node.attr 'submenus').empty?
      %(<strong>#{[menu, *submenus, (node.attr 'menuitem')] * ' | '}</strong>)
    elsif (menuitem = node.attr 'menuitem')
      %(<strong>#{menu} | #{menuitem}</strong>)
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

    node.id ? %(<a name="#{node.id}">#{ZeroWidthSpace}</a>#{quoted_text}) : quoted_text
  end

  # FIXME only create title page if doctype=book!
  def layout_title_page doc
    return unless doc.header? && !doc.notitle

    prev_bg_image = @page_bg_image
    prev_bg_color = @page_bg_color

    if (bg_image = resolve_background_image doc, @theme, 'title-page-background-image')
      @page_bg_image = (bg_image == 'none' ? nil : bg_image)
    end
    if (bg_color = resolve_theme_color :title_page_background_color)
      @page_bg_color = bg_color
    end
    # NOTE a new page will already be started if the cover image is a PDF
    start_new_page unless page_is_empty?
    @page_bg_image = prev_bg_image if bg_image
    @page_bg_color = prev_bg_color if bg_color

    # IMPORTANT this is the first page created, so we need to set the base font
    font @theme.base_font_family, size: @theme.base_font_size

    # QUESTION allow aligment per element on title page?
    title_align = @theme.title_page_align.to_sym

    # TODO disallow .pdf as image type
    if (logo_image_path = (doc.attr 'title-logo-image', @theme.title_page_logo_image))
      if (logo_image_path.include? ':') && logo_image_path =~ ImageAttributeValueRx
        logo_image_path = $1
        logo_image_attrs = (AttributeList.new $2).parse ['alt', 'width', 'height']
      else
        logo_image_attrs = {}
      end
      # HACK quick fix to resolve image path relative to theme
      unless doc.attr? 'title-logo-image'
        logo_image_path = ThemeLoader.resolve_theme_asset logo_image_path, (doc.attr 'pdf-stylesdir')
      end
      logo_image_attrs['target'] = logo_image_path
      logo_image_attrs['align'] ||= (@theme.title_page_logo_align || title_align.to_s)
      logo_image_top = (logo_image_attrs['top'] || @theme.title_page_logo_top)
      # FIXME delegate to method to convert page % to y value
      logo_image_top = [(page_height - page_height * (logo_image_top.to_i / 100.0)), bounds.absolute_top].min
      float do
        @y = logo_image_top
        # FIXME add API to Asciidoctor for creating blocks like this (extract from extensions module?)
        image_block = ::Asciidoctor::Block.new doc, :image, content_model: :empty, attributes: logo_image_attrs
        # FIXME prevent image from spilling to next page
        # QUESTION should we shave off margin top/bottom?
        convert_image image_block
      end
    end

    # TODO prevent content from spilling to next page
    theme_font :title_page do
      doctitle = doc.doctitle partition: true
      if (title_top = @theme.title_page_title_top)
        # FIXME delegate to method to convert page % to y value
        @y = [(page_height - page_height * (title_top.to_i / 100.0)), bounds.absolute_top].min
      end
      move_down (@theme.title_page_title_margin_top || 0)
      theme_font :title_page_title do
        layout_heading doctitle.main,
          align: title_align,
          margin: 0,
          line_height: @theme.title_page_title_line_height
      end
      move_down (@theme.title_page_title_margin_bottom || 0)
      if doctitle.subtitle
        move_down (@theme.title_page_subtitle_margin_top || 0)
        theme_font :title_page_subtitle do
          layout_heading doctitle.subtitle,
            align: title_align,
            margin: 0,
            line_height: @theme.title_page_subtitle_line_height
        end
        move_down (@theme.title_page_subtitle_margin_bottom || 0)
      end
      if doc.attr? 'authors'
        move_down (@theme.title_page_authors_margin_top || 0)
        theme_font :title_page_authors do
          # TODO add support for author delimiter
          layout_prose doc.attr('authors'),
            align: title_align,
            margin: 0,
            normalize: false
        end
        move_down (@theme.title_page_authors_margin_bottom || 0)
      end
      revision_info = [(doc.attr? 'revnumber') ? %(#{doc.attr 'version-label'} #{doc.attr 'revnumber'}) : nil, (doc.attr 'revdate')].compact
      unless revision_info.empty?
        move_down (@theme.title_page_revision_margin_top || 0)
        theme_font :title_page_revision do
          revision_text = revision_info * (@theme.title_page_revision_delimiter || ', ')
          layout_prose revision_text,
            align: title_align,
            margin: 0,
            normalize: false
        end
        move_down (@theme.title_page_revision_margin_bottom || 0)
      end
    end
  end

  def layout_cover_page position, doc
    # TODO turn processing of attribute with inline image a utility function in Asciidoctor
    # FIXME verify cover_image exists!
    if (cover_image = (doc.attr %(#{position}-cover-image)))
      if (cover_image.include? ':') && cover_image =~ ImageAttributeValueRx
        cover_image = resolve_image_path doc, $1
      end
      # QUESTION should we go to page 1 when position == :front?
      go_to_page page_count if position == :back
      if cover_image.downcase.end_with? '.pdf'
        # NOTE import_page automatically advances to next page afterwards
        import_page cover_image, advance: position != :back
      else
        image_page cover_image, canvas: true
      end
    end
  ensure
    unlink_tmp_file cover_image
  end

  # NOTE can't alias to start_new_page since methods have different arity
  # NOTE only called if not at page top
  def start_new_chapter section
    start_new_page
  end

  def layout_chapter_title node, title
    layout_heading title
  end

  # QUESTION why doesn't layout_heading set the font??
  def layout_heading string, opts = {}
    top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || @theme.heading_margin_top
    bot_margin = margin || (opts.delete :margin_bottom) || @theme.heading_margin_bottom
    if (transform = (opts.delete :text_transform) || @text_transform)
      string = transform_text string, transform
    end
    margin_top top_margin
    typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme.heading_line_height), {
      color: @font_color,
      inline_format: true,
      align: :left
    }.merge(opts)
    margin_bottom bot_margin
  end

  # NOTE inline_format is true by default
  def layout_prose string, opts = {}
    top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || @theme.prose_margin_top
    bot_margin = margin || (opts.delete :margin_bottom) || @theme.prose_margin_bottom
    if (transform = (opts.delete :text_transform) || @text_transform)
      string = transform_text string, transform
    end
    if (anchor = opts.delete :anchor)
      # FIXME won't work if inline_format is true; should instead pass through as attribute w/ link color set
      if (link_color = opts.delete :link_color)
        # NOTE CMYK value gets flattened here, but is restored by formatted text parser
        string = %(<a anchor="#{anchor}"><color rgb="#{link_color}">#{string}</color></a>)
      else
        string = %(<a anchor="#{anchor}">#{string}</a>)
      end
    end
    margin_top top_margin
    typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme.base_line_height), {
      color: @font_color,
      # NOTE normalize makes endlines soft (replaces "\n" with ' ')
      inline_format: [normalize: (opts.delete :normalize) != false],
      align: @theme.base_align.to_sym
    }.merge(opts)
    margin_bottom bot_margin
  end

  # Render the caption and return the height of the rendered content
  # QUESTION should layout_caption check for title? and return 0 if false?
  # TODO allow margin to be zeroed
  def layout_caption subject, opts = {}
    mark = { cursor: cursor, page_number: page_number }
    case subject
    when ::String
      string = subject
    when ::Asciidoctor::AbstractBlock
      string = subject.title? ? subject.captioned_title : nil
    else
      return 0
    end
    theme_font :caption do
      if (position = (opts.delete :position) || :top) == :top
        margin = { top: @theme.caption_margin_outside, bottom: @theme.caption_margin_inside }
      else
        margin = { top: @theme.caption_margin_inside, bottom: @theme.caption_margin_outside }
      end
      layout_prose string, {
        margin_top: margin[:top],
        margin_bottom: margin[:bottom],
        align: @theme.caption_align.to_sym,
        normalize: false
      }.merge(opts)
      if position == :top && @theme.caption_border_bottom_color
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

  def layout_toc doc, num_levels = 2, toc_page_number = 2, num_front_matter_pages = 0
    go_to_page toc_page_number unless (page_number == toc_page_number) || scratch?
    start_page_number = page_number
    theme_font :heading, level: 2 do
      layout_heading doc.attr('toc-title')
    end
    # QUESTION shouldn't we skip this whole method if num_levels == 0?
    if num_levels > 0
      theme_margin :toc, :top
      line_metrics = calc_line_metrics @theme.toc_line_height
      dot_width = nil
      theme_font :toc do
        dot_width = width_of(@theme.toc_dot_leader_content || DotLeaderDefault)
      end
      layout_toc_level doc.sections, num_levels, line_metrics, dot_width, num_front_matter_pages
    end
    # NOTE range must be calculated relative to toc_page_number; absolute page number in scratch document is arbitrary
    toc_page_numbers = (toc_page_number..(toc_page_number + (page_number - start_page_number)))
    go_to_page page_count - 1 unless scratch?
    toc_page_numbers
  end

  def layout_toc_level sections, num_levels, line_metrics, dot_width, num_front_matter_pages = 0
    toc_dot_color = @theme.toc_dot_leader_font_color || @theme.toc_font_color || @font_color
    sections.each do |sect|
      theme_font :toc, level: (sect.level + 1) do
        sect_title = @text_transform ? (transform_text sect.numbered_title, @text_transform) : sect.numbered_title
        # NOTE we do some cursor hacking here so the dots don't affect vertical alignment
        start_page_number = page_number
        start_cursor = cursor
        # NOTE CMYK value gets flattened here, but is restored by formatted text parser
        # FIXME use layout_prose
        typeset_text %(<a anchor="#{sect_anchor = (sect.attr 'anchor') || sect.id}"><color rgb="#{@font_color}">#{sect_title}</color></a>), line_metrics, inline_format: true
        # we only write the label if this is a dry run
        unless scratch?
          end_page_number = page_number
          end_cursor = cursor
          # TODO it would be convenient to have a cursor mark / placement utility that took page number into account
          go_to_page start_page_number if start_page_number != end_page_number
          move_cursor_to start_cursor
          sect_page_num = (sect.attr 'page_start') - num_front_matter_pages
          spacer_width = (width_of NoBreakSpace) * 0.75
          # FIXME this calculation will be wrong if a style is set per level
          num_dots = ((bounds.width - (width_of %(#{sect_title}#{sect_page_num}), inline_format: true) - spacer_width) / dot_width).floor
          num_dots = 0 if num_dots < 0
          # FIXME dots don't line up if width of page numbers differ
          typeset_formatted_text [
            { text: %(#{(@theme.toc_dot_leader_content || DotLeaderDefault) * num_dots}), color: toc_dot_color },
            # FIXME this spacing doesn't always work out
            { text: NoBreakSpace, size: (@font_size * 0.5) },
            { text: sect_page_num.to_s, anchor: sect_anchor, color: @font_color }], line_metrics, align: :right
          go_to_page end_page_number if start_page_number != end_page_number
          move_cursor_to end_cursor
        end
      end
      if sect.level < num_levels
        indent @theme.toc_indent do
          layout_toc_level sect.sections, num_levels, line_metrics, dot_width, num_front_matter_pages
        end
      end
    end
  end

  # Reduce icon size to fit inside bounds.height. Icons will not render
  # properly if they are larger than the current bounds.height.
  def fit_icon_size node, max_size = 24
    (min_height = bounds.height.floor) < max_size ? min_height : max_size
  end

  def admonition_icon_data key
    if (icon_data = @theme[%(admonition_icon_#{key})])
      (AdmonitionIcons[key] || {}).merge icon_data
    else
      AdmonitionIcons[key]
    end
  end

  # TODO delegate to layout_page_header and layout_page_footer per page
  def layout_running_content position, doc, opts = {}
    # QUESTION should we short-circuit if setting not specified and if so, which setting?
    return unless (position == :header && @theme.header_height) || (position == :footer && @theme.footer_height)
    skip = opts[:skip] || 1
    start = skip + 1
    num_pages = page_count - skip

    # FIXME probably need to treat doctypes differently
    sections = doc.find_by(context: :section) {|sect| sect.level < 3 } || []

    # index chapters and sections by the visual page number on which they start
    chapter_start_pages = {}
    section_start_pages = {}
    sections.each do |sect|
      if sect.chapter?
        chapter_start_pages[(sect.attr 'page_start').to_i - skip] ||= (sect.numbered_title formal: true)
      else
        section_start_pages[(sect.attr 'page_start').to_i - skip] ||= (sect.numbered_title formal: true)
      end
    end

    # index chapters and sections by the visual page number on which they appear
    chapters_by_page = {}
    sections_by_page = {}
    last_chap = (doc.attr 'preface-title') || 'Preface'
    last_sect = nil
    (1..num_pages).each do |num|
      if (chap = chapter_start_pages[num])
        last_chap = chap
      end
      if (sect = section_start_pages[num])
        last_sect = sect
      elsif chap
        last_sect = nil
      end
      chapters_by_page[num] = last_chap
      sections_by_page[num] = last_sect
    end

    doctitle = doc.doctitle partition: true, use_fallback: true
    # NOTE set doctitle again so it's properly escaped
    doc.set_attr 'doctitle', doctitle.combined
    doc.set_attr 'document-title', doctitle.main
    doc.set_attr 'document-subtitle', doctitle.subtitle
    doc.set_attr 'page-count', num_pages

    fallback_footer_content = {
      recto: { right: '{page-number}' },
      verso: { left: '{page-number}' }
    }
    # TODO move this to a method so it can be reused; cache results
    content_dict = [:recto, :verso].inject({}) do |acc, side|
      side_content = {}
      Alignments.each do |align|
        if (val = @theme[%(#{position}_#{side}_content_#{align})])
          # TODO support image URL (using resolve_image_path)
          if (val.include? ':') && val =~ ImageAttributeValueRx &&
              ::File.readable?(path = (ThemeLoader.resolve_theme_asset $1, (doc.attr 'pdf-stylesdir')))
            attrs = (AttributeList.new $2).parse
            width = resolve_explicit_width attrs, bounds.width
            # QUESTION should we lookup and scale intrinsic width if explicit width is not given?
            unless width
              width = [bounds.width, (intrinsic_image_dimensions path)[:width] * 0.75].min
            end
            side_content[align] = { path: path, width: width }
          else
            side_content[align] = val
          end
        end
      end
      # NOTE set fallbacks if not explicitly disabled
      if side_content.empty? && position == :footer && @theme[%(footer_#{side}_content)] != 'none'
        side_content = fallback_footer_content[side]
      end

      acc[side] = side_content
      acc
    end

    if position == :header
      trim_line_metrics = calc_line_metrics(@theme.header_line_height || @theme.base_line_height)
      trim_top = page_height
      # NOTE height is required atm
      trim_height = @theme.header_height || page_margin_top
      trim_padding = @theme.header_padding || [0, 0, 0, 0]
      trim_left = page_margin_left
      trim_width = page_width - trim_left - page_margin_right
      trim_font_color = @theme.header_font_color || @font_color
      trim_bg_color = resolve_theme_color :header_background_color
      trim_border_width = @theme.header_border_width || @theme.base_border_width
      trim_border_style = (@theme.header_border_style || :solid).to_sym
      trim_border_color = resolve_theme_color :header_border_color
      trim_valign = (@theme.header_vertical_align || :middle).to_sym
      trim_img_valign = @theme.header_image_vertical_align
    else
      trim_line_metrics = calc_line_metrics(@theme.footer_line_height || @theme.base_line_height)
      # NOTE height is required atm
      trim_top = trim_height = @theme.footer_height || page_margin_bottom
      trim_padding = @theme.footer_padding || [0, 0, 0, 0]
      trim_left = page_margin_left
      trim_width = page_width - trim_left - page_margin_right
      trim_font_color = @theme.footer_font_color || @font_color
      trim_bg_color = resolve_theme_color :footer_background_color
      trim_border_width = @theme.footer_border_width || @theme.base_border_width
      trim_border_style = (@theme.footer_border_style || :solid).to_sym
      trim_border_color = resolve_theme_color :footer_border_color
      trim_valign = (@theme.footer_vertical_align || :middle).to_sym
      trim_img_valign = @theme.footer_image_vertical_align
    end

    trim_stamp = position.to_s
    trim_content_left = trim_left + trim_padding[3]
    trim_content_height = trim_height - trim_padding[0] - trim_padding[2] - trim_line_metrics.padding_top - trim_line_metrics.padding_bottom
    trim_content_width = trim_width - trim_padding[3] - trim_padding[1]
    trim_border_color = nil if trim_border_width == 0
    trim_valign = :center if trim_valign == :middle
    case trim_img_valign
    when nil
      trim_img_valign = trim_valign
    when 'middle'
      trim_img_valign = :center
    when 'top', 'center', 'bottom'
      trim_img_valign = trim_img_valign.to_sym
    end

    if trim_bg_color || trim_border_color
      # NOTE switch to first content page so stamp will get created properly (can't create on imported page)
      prev_page_number = page_number
      go_to_page start
      create_stamp trim_stamp do
        canvas do
          if trim_bg_color
            bounding_box [0, trim_top], width: bounds.width, height: trim_height do
              fill_bounds trim_bg_color
              if trim_border_color
                # TODO stroke_horizontal_rule should support :at
                move_down bounds.height if position == :header
                stroke_horizontal_rule trim_border_color, line_width: trim_border_width, line_style: trim_border_style
              end
            end
          else
            bounding_box [trim_left, trim_top], width: trim_width, height: trim_height do
              # TODO stroke_horizontal_rule should support :at
              move_down bounds.height if position == :header
              stroke_horizontal_rule trim_border_color, line_width: trim_border_width, line_style: trim_border_style
            end
          end
        end
      end
      @stamps[position] = true
      go_to_page prev_page_number
    end

    pagenums_enabled = doc.attr? 'pagenums'
    repeat (start..page_count), dynamic: true do
      # NOTE don't write on pages which are imported / inserts (otherwise we can get a corrupt PDF)
      next if page.imported_page?
      visual_pgnum = page_number - skip
      # FIXME we need to have a content setting for chapter pages
      content_by_alignment = content_dict[visual_pgnum.odd? ? :recto : :verso]
      # TODO populate chapter-number
      # TODO populate numbered and unnumbered chapter and section titles
      # FIXME leave page-number attribute unset once we filter lines with unresolved attributes (see below)
      doc.set_attr 'page-number', (pagenums_enabled ? visual_pgnum : '')
      doc.set_attr 'chapter-title', (chapters_by_page[visual_pgnum] || '')
      doc.set_attr 'section-title', (sections_by_page[visual_pgnum] || '')
      doc.set_attr 'section-or-chapter-title', (sections_by_page[visual_pgnum] || chapters_by_page[visual_pgnum] || '')

      stamp trim_stamp if @stamps[position]

      theme_font position do
        canvas do
          bounding_box [trim_content_left, trim_top], width: trim_content_width, height: trim_height do
            Alignments.each do |align|
              # FIXME we need to have a content setting for chapter pages
              case (content = content_by_alignment[align])
              when ::Hash
                # NOTE image placement respects padding; use negative image_vertical_align value to revert
                trim_v_padding = trim_padding[0] + trim_padding[2]
                # NOTE bounding_box is redundant if trim_v_padding is 0
                bounding_box [0, cursor - trim_padding[0]], width: bounds.width, height: (bounds.height - trim_v_padding) do
                  # NOTE float ensures cursor position is restored and returns us to current page if we overrun
                  float do
                    #image content[:path], vposition: trim_img_valign, position: align, width: content[:width]
                    # NOTE use :fit to prevent image from overflowing page (at the cost of scaling it)
                    image content[:path], vposition: trim_img_valign, position: align, fit: [content[:width], bounds.height]
                  end
                end
              when ::String
                if content == '{page-number}'
                  content = pagenums_enabled ? visual_pgnum.to_s : nil
                else
                  # FIXME drop lines with unresolved attributes
                  content = doc.apply_subs content
                end
                formatted_text_box parse_text(content, color: trim_font_color, inline_format: [normalize: true]),
                  at: [0, trim_content_height + trim_padding[2] + trim_line_metrics.padding_bottom],
                  height: trim_content_height,
                  align: align,
                  valign: trim_valign,
                  leading: trim_line_metrics.leading,
                  final_gap: false,
                  overflow: :truncate
              end
            end
          end
        end
      end
    end
  end

  # FIXME we are assuming we always have exactly one title page
  def add_outline doc, num_levels = 2, toc_page_nums = (0..-1), num_front_matter_pages = 0
    front_matter_counter = RomanNumeral.new 0, :lower

    page_num_labels = {}

    # FIXME account for cover page
    # cover page (i)
    #front_matter_counter.next!

    # title page (i)
    # TODO same conditional logic as in layout_title_page; consolidate
    if doc.header? && !doc.notitle
      page_num_labels[0] = { P: ::PDF::Core::LiteralString.new(front_matter_counter.next!.to_s) }
    end

    # toc pages (ii..?)
    toc_page_nums.each do
      page_num_labels[front_matter_counter.to_i] = { P: ::PDF::Core::LiteralString.new(front_matter_counter.next!.to_s) }
    end

    # credits page
    #page_num_labels[front_matter_counter.to_i] = { P: ::PDF::Core::LiteralString.new(front_matter_counter.next!.to_s) }

    # number of front matter pages aside from the document title to skip in page number index
    numbering_offset = front_matter_counter.to_i - 1

    outline.define do
      # FIXME use sanitize: :plain_text once available
      if (doctitle = document.sanitize(doc.doctitle use_fallback: true))
        page title: doctitle, destination: (document.dest_top 1)
      end
      if doc.attr? 'toc'
        page title: doc.attr('toc-title'), destination: (document.dest_top toc_page_nums.first)
      end
      #page title: 'Credits', destination: (document.dest_top toc_page_nums.first + 1)
      # QUESTION any way to get add_outline_level to invoke in the context of the outline?
      document.add_outline_level self, doc.sections, num_levels, page_num_labels, numbering_offset, num_front_matter_pages
    end

    catalog.data[:PageLabels] = state.store.ref Nums: page_num_labels.flatten
    catalog.data[:PageMode] = :UseOutlines
    nil
  end

  # TODO only nest inside root node if doctype=article
  def add_outline_level outline, sections, num_levels, page_num_labels, numbering_offset, num_front_matter_pages
    sections.each do |sect|
      sect_title = sanitize sect.numbered_title formal: true
      sect_destination = sect.attr 'pdf-destination'
      sect_page_num = (sect.attr 'page_start') - num_front_matter_pages
      page_num_labels[sect_page_num + numbering_offset] = { P: ::PDF::Core::LiteralString.new(sect_page_num.to_s) }
      if (subsections = sect.sections).empty? || sect.level == num_levels
        outline.page title: sect_title, destination: sect_destination
      elsif sect.level < num_levels + 1
        outline.section sect_title, { destination: sect_destination } do
          add_outline_level outline, subsections, num_levels, page_num_labels, numbering_offset, num_front_matter_pages
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
      @pdfmarks.generate_file target if @pdfmarks
    end
    # write scratch document if debug is enabled (or perhaps DEBUG_STEPS env)
    #get_scratch_document.render_file 'scratch.pdf'
    nil
  end

  def register_fonts font_catalog, scripts = 'latin', fonts_dir
    (font_catalog || {}).each do |key, font_styles|
      register_font key => font_styles.map {|style, path| [style.to_sym, (font_path path, fonts_dir)]}.to_h
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

  # QUESTION should we pass a category as an argument?
  # QUESTION should we make this a method on the theme ostruct? (e.g., @theme.resolve_color key, fallback)
  def resolve_theme_color key, fallback_color = nil
    if (color = @theme[key.to_s]) && color != 'transparent'
      color
    else
      fallback_color
    end
  end

  def theme_fill_and_stroke_bounds category
    fill_and_stroke_bounds @theme[%(#{category}_background_color)], @theme[%(#{category}_border_color)],
      line_width: @theme[%(#{category}_border_width)],
      radius: @theme[%(#{category}_border_radius)]
  end

  # Insert a top margin space unless cursor is at the top of the page.
  # Start a new page if y value is greater than remaining space on page.
  def margin_top y
    margin y, :top
  end

  # Insert a bottom margin space unless cursor is at the top of the page (not likely).
  # Start a new page if y value is greater than remaining space on page.
  def margin_bottom y
    margin y, :bottom
  end

  # Insert a margin space of type position unless cursor is at the top of the page.
  # Start a new page if y value is greater than remaining space on page.
  def margin y, position
    unless y == 0 || at_page_top?
      if cursor > y
        move_down y
      else
        # go to the next page
        # NOTE we don't use `move_down cursor` because we often have to check at_page_top?
        @margin_box.move_past_bottom
      end
    end
  end

  # Lookup margin for theme element and position, then delegate to margin method.
  # If margin value is not found, assume:
  # - 0 when position = :top
  # - @theme.vertical_spacing when position = :bottom
  def theme_margin category, position
    margin (@theme[%(#{category}_margin_#{position})] || (position == :bottom ? @theme.vertical_spacing : 0)), position
  end

  def theme_font category, opts = {}
    if (level = opts[:level])
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

    style = style.to_sym if style

    prev_color, @font_color = @font_color, color if color
    prev_transform, @text_transform = @text_transform, transform if transform

    font family, size: size, style: style do
      yield
    end

    @font_color = prev_color if color
    @text_transform = prev_transform if transform
  end

  # Calculate the font size (down to the minimum font size) that would allow
  # all the specified fragments to fit in the available width without wrapping lines.
  #
  # Return the calculated font size if an adjustment is necessary or nil if no
  # font size adjustment is necessary.
  def theme_font_size_autofit fragments, category
    arranger = arrange_fragments_by_line fragments
    adjusted_font_size = nil
    theme_font category do
      # NOTE finalizing the line here generates fragments & calculates their widths using the current font settings
      # CAUTION it also removes zero-width spaces
      arranger.finalize_line
      actual_width = width_of_fragments arranger.fragments
      unless ::Array === (padding = @theme[%(#{category}_padding)])
        padding = [padding] * 4
      end
      available_width = bounds.width - (padding[3] || 0) - (padding[1] || 0)
      if actual_width > available_width
        adjusted_font_size = ((available_width * font_size).to_f / actual_width).with_precision 4
        if (min = @theme[%(#{category}_font_size_min)] || @theme.base_font_size_min) && adjusted_font_size < min
          adjusted_font_size = min
        end
      end
    end
    adjusted_font_size
  end

  # Arrange fragments by line in an arranger and return an unfinalized arranger.
  #
  # Finalizing the arranger is deferred since it must be done in the context of
  # the global font settings you want applied to each fragment.
  def arrange_fragments_by_line fragments, opts = {}
    arranger = ::Prawn::Text::Formatted::Arranger.new self
    by_line = arranger.consumed = []
    fragments.each do |fragment|
      if (txt = fragment[:text]) == EOL
        by_line << fragment
      elsif txt.include? EOL
        txt.scan(LineScanRx) do |line|
          by_line << (line == EOL ? { text: EOL } : (fragment.merge text: line))
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
      if fragment.text == EOL
        line_widths << 0
      else
        line_widths[-1] += fragment.width
      end
    end
    line_widths.max
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
          # NOTE '+' operator is faster than interpolation in this case
          if guard_indent
            line.sub!(TabIndentRx) {|tabs| GuardedIndent + (full_tab_space * tabs.length).chop! }
          else
            line.sub!(TabIndentRx) {|tabs| full_tab_space * tabs.length }
          end
          leading_space = false
        # QUESTION should we check for EOL first?
        elsif line == EOL
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

  # If an id is provided or the node passed as the first argument has an id,
  # add a named destination to the document equivalent to the node id at the
  # current y position. If the node does not have an id and an id is not
  # specified, do nothing.
  #
  # If the node is a section, and the current y position is the top of the
  # page, set the position equal to the page height to improve the navigation
  # experience.
  def add_dest_for_block node, id = nil
    if !scratch? && (id ||= node.id)
      # QUESTION should we set precise x value of destination or just 0?
      dest_x = bounds.absolute_left.round 2
      dest_x = 0 if dest_x <= page_margin_left
      dest_y = if node.context == :section && at_page_top?
        page_height
      else
        y
      end
      # TODO find a way to store only the ref of the destination; look it up when we need it
      node.set_attr 'pdf-destination', (node_dest = (dest_xyz dest_x, dest_y))
      add_dest id, node_dest
    end
    nil
  end

  # QUESTION is this method still necessary?
  def resolve_imagesdir doc
    if (imagesdir = doc.attr 'imagesdir').nil_or_empty? || (imagesdir = imagesdir.chomp '/') == '.'
      nil
    else
      %(#{imagesdir}/)
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
  def resolve_image_path node, image_path = nil, image_type = nil
    imagesdir = resolve_imagesdir(doc = node.document)
    image_path ||= (node.attr 'target', nil, false)
    image_type ||= ::Asciidoctor::Image.image_type image_path
    # handle case when image is a URI
    if (node.is_uri? image_path) || (imagesdir && (node.is_uri? imagesdir) &&
        (image_path = (node.normalize_web_path image_path, image_base_uri, false)))
      unless doc.attr? 'allow-uri-read'
        unless scratch?
          warn %(asciidoctor: WARNING: allow-uri-read is not enabled; cannot embed remote image: #{image_path})
        end
        return
      end
      if doc.attr? 'cache-uri'
        Helpers.require_library 'open-uri/cached', 'open-uri-cached' unless defined? ::OpenURI::Cache
      end
      tmp_image = ::Tempfile.new ['image-', %(.#{image_type})]
      tmp_image.binmode if (binary = image_type != 'svg')
      begin
        open(image_path, (binary ? 'rb' : 'r')) {|fd| tmp_image.write(fd.read) }
        tmp_image_path = tmp_image.path
        tmp_image_path.extend TemporaryPath
      rescue
        tmp_image_path = nil
      ensure
        tmp_image.close
      end
      tmp_image_path
    # handle case when image is a local file
    else
      ::File.expand_path(node.normalize_system_path image_path, imagesdir, nil, target_name: 'image')
    end
  end

  # Resolve the path to the background image either from a document attribute or theme key.
  #
  # Returns The string "none" if the background image value is none, otherwise the resolved
  # path to the image. If neither the document attribute or theme key are specified, or
  # the image path cannot be resolved, return nil.
  def resolve_background_image doc, theme, key
    if (bg_image = (doc_attr_val = (doc.attr key)) || theme[(key.tr '-', '_').to_sym])
      return bg_image if bg_image == 'none'

      if (bg_image.include? ':') && bg_image =~ ImageAttributeValueRx
        # QUESTION should we support width and height in this case?
        bg_image = $1
      end

      if (bg_image = doc_attr_val ? (resolve_image_path doc, bg_image) :
          (ThemeLoader.resolve_theme_asset bg_image, (doc.attr 'pdf-stylesdir')))
        if ::File.readable? bg_image
          bg_image
        else
          warn %(asciidoctor: WARNING: #{key.tr '-', ' '} #{bg_image} not found or readable)
          nil
        end
      end
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
  def resolve_explicit_width attrs, max_width = bounds.width
    if attrs.key? 'pdfwidth'
      if (pdfwidth = attrs['pdfwidth']).end_with? '%'
        (pdfwidth.to_f / 100) * max_width
      else
        str_to_pt pdfwidth
      end
    elsif attrs.key? 'scaledwidth'
      (attrs['scaledwidth'].to_f / 100) * max_width
    elsif attrs.key? 'width'
      # QUESTION should we honor percentage width value?
      # NOTE scale width down 75% to convert px to pt; restrict width to bounds.width
      [max_width, attrs['width'].to_f * 0.75].min
    end
  end

  # QUESTION is there a better way to do this?
  # I suppose we could have @tmp_files as an instance variable on converter instead
  # It might be sufficient to delete temporary files once per conversion
  # NOTE Ruby 1.9 will sometimes delete a tmp file before the process exits
  def unlink_tmp_file path
    path.unlink if TemporaryPath === path && path.exist?
  end

  # QUESTION move to prawn/extensions.rb?
  def init_scratch_prototype
    # IMPORTANT don't set font before using Marshal, it causes serialization to fail
    @prototype = ::Marshal.load ::Marshal.dump self
    @prototype.state.store.info.data[:Scratch] = true
    # we're now starting a new page each time, so no need to do it here
    #@prototype.start_new_page if @prototype.page_number == 0
  end

=begin
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
end
