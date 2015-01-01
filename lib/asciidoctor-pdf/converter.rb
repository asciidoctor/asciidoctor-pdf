# encoding: UTF-8
# TODO cleanup imports...decide what belongs in asciidoctor-pdf.rb
require_relative 'core_ext/array'
require 'prawn'
require 'prawn-svg'
require 'prawn/table'
require 'prawn/templates'
require_relative 'prawn_ext'
require_relative 'pdfmarks'
require_relative 'asciidoctor_ext'
require_relative 'theme_loader'
require_relative 'roman_numeral'

module Asciidoctor
module Pdf
class Converter < ::Prawn::Document
  include ::Asciidoctor::Converter
  include ::Asciidoctor::Writer
  include ::Asciidoctor::Prawn::Extensions

  register_for 'pdf'

  def self.unicode_char number
    [number].pack 'U*'
  end

  IndentationRx = /^ +/
  TabSpaces = ' ' * 4
  NoBreakSpace = unicode_char 0x00a0
  NarrowNoBreakSpace = unicode_char 0x202f
  HairSpace = unicode_char 0x200a
  DotLeader = %(#{HairSpace}.)
  EmDash = unicode_char 0x2014
  LowercaseGreekA = unicode_char 0x03b1
  AdmonitionIcons = {
    note: (unicode_char 0xf0eb)
  }
  Bullets = {
    disc: (unicode_char 0x2022),
    circle: (unicode_char 0x25e6),
    square: (unicode_char 0x25aa)
  }
  BuiltInEntityChars = {
    '&lt;' => '<',
    '&gt;' => '>',
    '&amp;' => '&'
  }
  BuiltInEntityCharsRx = /(?:#{BuiltInEntityChars.keys * '|'})/
  ImageAttributeValueRx = /^image:{1,2}(.*?)\[(.*?)\]$/

  def initialize backend, opts
    super
    basebackend 'html'
    outfilesuffix '.pdf'
    #htmlsyntax 'xml'
    @list_numbers = []
    @list_bullets = []
  end

  def convert node, name = nil
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
    (node.is_a? ::Asciidoctor::Inline) ? result : self
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
      # TODO this content could be catched on repeat invocations!
      layout_prose string, opts
    end
    node.document.instance_variable_set :@converter, prev_converter if prev_converter
  end

  def convert_document doc
    init_pdf doc
    # data-uri doesn't apply to PDF, so explicitly disable (is there a better place?)
    doc.attributes.delete 'data-uri'

    # TODO implement page_background_image as alternative and/or page_watermark_image
    if (bg_color = @theme.page_background_color) && !(['transparent', 'FFFFFF'].include? bg_color.to_s)
      on_page_create do
        canvas do
          fill_bounds bg_color.to_s
        end
      end
    end

    layout_cover_page :front, doc
    layout_title_page doc

    start_new_page

    toc_start_page_num = page_number
    num_toc_levels = (doc.attr 'toclevels', 2).to_i
    if doc.attr? 'toc'
      toc_page_nums = ()
      dry_run do
        toc_page_nums = layout_toc doc, num_toc_levels, 1
      end
      # reserve pages for the toc
      toc_page_nums.each do
        start_new_page
      end
    end

    num_front_matter_pages = page_number - 1
    font @theme.base_font_family, size: @theme.base_font_size
    convert_content_for_block doc

    toc_page_nums = if doc.attr? 'toc'
      layout_toc doc, num_toc_levels, toc_start_page_num, num_front_matter_pages
    else
      (0..-1)
    end

    # TODO enable pagenums by default (perhaps upstream?)
    stamp_page_numbers skip: num_front_matter_pages if doc.attr 'pagenums'
    add_outline doc, num_toc_levels, toc_page_nums, num_front_matter_pages
    catalog.data[:ViewerPreferences] = [:FitWindow]

    layout_cover_page :back, doc

    # NOTE we have to init pdfmarks here while we have a reference to the doc
    @pdfmarks = Pdfmarks.new doc
  end

  # NOTE embedded only makes sense if perhaps we are building
  # on an existing Prawn::Document instance; for now, just treat
  # it the same as a full document.
  alias :convert_embedded :convert_document

  # TODO only allow method to be called once (or we need a reset)
  def init_pdf doc
    theme = ThemeLoader.load_theme doc.attr('pdf-style'), doc.attr('pdf-stylesdir')
    pdf_opts = (build_pdf_options doc, theme)
    ::Prawn::Document.instance_method(:initialize).bind(self).call pdf_opts
    # QUESTION should ThemeLoader register fonts?
    register_fonts theme.font_catalog, (doc.attr 'scripts', 'latin'), (doc.attr 'pdf-fontsdir', ThemeLoader::FontsDir)
    @theme = theme
    @font_color = theme.base_font_color
    @fallback_fonts = theme.font_fallbacks || []
    init_scratch_prototype
    self
  end

  def build_pdf_options doc, theme
    pdf_opts = {
      #compress: true,
      #optimize_objects: true,
      info: (build_pdf_info doc),
      margin: (theme.page_margin || 36),
      page_layout: (theme.page_layout || :portrait).to_sym,
      page_size: (theme.page_size || 'LETTER').upcase,
      skip_page_creation: true,
    }
    # FIXME fix the namespace for FormattedTextFormatter
    pdf_opts[:text_formatter] ||= ::Asciidoctor::Prawn::FormattedTextFormatter.new theme: theme
    pdf_opts
  end

  def build_pdf_info doc
    info = {}
    # TODO create helper method for creating literal PDF string
    info[:Title] = ::PDF::Core::LiteralString.new(doc.doctitle sanitize: true, use_fallback: true)
    if doc.attr? 'authors'
      info[:Author] = ::PDF::Core::LiteralString.new(doc.attr 'authors')
    end
    if doc.attr? 'subject'
      info[:Subject] = ::PDF::Core::LiteralString.new(doc.attr 'subject')
    end
    if doc.attr? 'keywords'
      info[:Keywords] = ::PDF::Core::LiteralString.new(doc.attr 'keywords')
    end
    if (doc.attr? 'publisher')
      info[:Producer] = ::PDF::Core::LiteralString.new(doc.attr 'publisher')
    end
    info[:Creator] = ::PDF::Core::LiteralString.new %(Asciidoctor PDF #{::Asciidoctor::Pdf::VERSION}, based on Prawn #{::Prawn::VERSION})
    info[:Producer] ||= (info[:Author] || info[:Creator])
    # FIXME use docdate attribute
    info[:ModDate] = info[:CreationDate] = ::Time.now
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
      sect.set_attr 'page_start', page_number
      dest_y = at_page_top? ? page_height : y
      sect.set_attr 'destination', (sect_destination = (dest_xyz 0, dest_y))
      add_dest sect.id, sect_destination
      sect.chapter? ? (layout_chapter_title sect, title) : (layout_heading title)
    end

    convert_content_for_block sect
    sect.set_attr 'page_end', page_number
  end

  def convert_floating_title node
    theme_font :heading, level: (node.level + 1) do
      layout_heading node.title
    end
  end

  def convert_abstract node
    pad_box @theme.abstract_padding do
      theme_font :abstract do
        # FIXME control first_line_options using theme
        prose_opts = { line_height: @theme.abstract_line_height, first_line_options: { styles: [font_style, :bold] } }
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
    #move_down @theme.block_margin_bottom
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
      when 'lead'
        is_lead = true
      #when 'signature'
      #  prose_opts[:size] = @theme.base_font_size_small
      end
    end

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
    #move_down @theme.block_margin_top unless at_page_top?
    theme_margin :block, :top
    keep_together do |box_height = nil|
      #theme_font :admonition do
        label = node.caption.upcase
        label_width = width_of label
        # FIXME use padding from theme
        indent @theme.horizontal_rhythm, @theme.horizontal_rhythm do
          if box_height
            float do
              bounding_box [0, cursor], width: label_width + @theme.horizontal_rhythm, height: box_height do
                # IMPORTANT the label must fit in the alotted space or it shows up on another page!
                # QUESTION anyway to prevent text overflow in the case it doesn't fit?
                stroke_vertical_rule @theme.admonition_border_color, at: bounds.width
                # HACK make title in this location look right
                label_margin_top = node.title? ? @theme.caption_margin_inside : 0
                layout_prose label, valign: :center, style: :bold, line_height: 1, margin_top: label_margin_top, margin_bottom: 0
              end
            end
          end
          indent label_width + @theme.horizontal_rhythm * 2 do
            layout_caption node.title if node.title?
            convert_content_for_block node
            # HACK compensate for margin bottom of admonition content
            move_up(@theme.prose_margin_bottom || @theme.vertical_rhythm)
          end
        end
      #end
    end
    #move_down @theme.block_margin_bottom
    theme_margin :block, :bottom
  end

  def convert_example node
    #move_down @theme.block_margin_top unless at_page_top?
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
      pad_box [@theme.vertical_rhythm, @theme.horizontal_rhythm, 0, @theme.horizontal_rhythm] do
        theme_font :example do
          convert_content_for_block node
        end
      end
    end
    #move_down @theme.block_margin_bottom
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
        convert_content_for_block node
      end
    else
      convert_content_for_block node
    end
  end

  def convert_quote_or_verse node
    border_width = @theme.blockquote_border_width
    #move_down @theme.block_margin_top unless at_page_top?
    theme_margin :block, :top
    keep_together do |box_height = nil|
      start_cursor = cursor
      # FIXME use padding from theme
      pad_box [@theme.vertical_rhythm / 2.0, @theme.horizontal_rhythm, -(@theme.vertical_rhythm / 2.0), @theme.horizontal_rhythm + border_width / 2.0] do
        theme_font :blockquote do
          if node.context == :quote
            convert_content_for_block node
          else # verse
            layout_prose node.content, preserve: true, normalize: false, align: :left
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
    #move_down @theme.block_margin_bottom
    theme_margin :block, :bottom
  end

  alias :convert_quote :convert_quote_or_verse
  alias :convert_verse :convert_quote_or_verse

  def convert_sidebar node
    #move_down @theme.block_margin_top unless at_page_top?
    theme_margin :block, :top
    keep_together do |box_height = nil|
      if box_height
        float do
          bounding_box [0, cursor], width: bounds.width, height: box_height do
            theme_fill_and_stroke_bounds :sidebar
          end
        end
      end
      pad_box @theme.block_padding do
        if node.title?
          theme_font :sidebar_title do
            # QUESTION should we allow margins of sidebar title to be customized?
            layout_heading node.title, align: @theme.sidebar_title_align.to_sym, margin_top: 0
          end
        end
        theme_font :sidebar do
          convert_content_for_block node
        end
        # HACK compensate for margin bottom of sidebar content
        move_up(@theme.prose_margin_bottom || @theme.vertical_rhythm)
      end
    end
    #move_down @theme.block_margin_bottom
    theme_margin :block, :bottom
  end

  def convert_colist node
    # HACK undo the margin below the listing
    move_up ((@theme.block_margin_bottom || @theme.vertical_rhythm) * 0.5)
    @list_numbers ||= []
    # FIXME move \u2460 to constant (or theme setting)
    @list_numbers << %(\u2460)
    #stroke_horizontal_rule @theme.caption_border_bottom_color
    # HACK fudge spacing around colist a bit; each item is shifted up by this amount (see convert_list_item)
    move_down ((@theme.prose_margin_bottom || @theme.vertical_rhythm) * 0.5)
    convert_outline_list node
    @list_numbers.pop
  end

  def convert_dlist node
    node.items.each do |terms, desc|
      terms = [*terms]
      # NOTE don't orphan the terms, allow for at least one line of content
      # FIXME extract ensure_space (or similar) method
      start_new_page if cursor < @theme.base_line_height_length * (terms.size + 1)
      terms.each do |term|
        layout_prose term.text, style: @theme.description_list_term_font_style.to_sym, margin_top: 0, margin_bottom: (@theme.vertical_rhythm / 3.0), align: :left
      end
      if desc
        indent @theme.description_list_description_indent do
          convert_content_for_list_item desc
        end
      end
    end
  end

  def convert_olist node
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

  # TODO implement checklist
  def convert_ulist node
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
    convert_outline_list node
    @list_bullets.pop
  end

  def convert_outline_list node
    indent @theme.outline_list_indent do
      node.items.each do |item|
        convert_list_item item
      end
    end
    # NOTE children will provide the necessary bottom margin
  end

  def convert_list_item node
    # HACK quick hack to tighten items on colist
    if node.parent.context == :colist
      move_up ((@theme.prose_margin_bottom || @theme.vertical_rhythm) * 0.5)
    end

    # NOTE we need at least one line of content, so move down if we don't have it
    # FIXME extract ensure_space (or similar) method
    start_new_page if cursor < @theme.base_line_height_length

    # TODO move this to a draw_bullet method
    float do
      bounding_box [-@theme.outline_list_indent, cursor], width: @theme.outline_list_indent do
        label = case node.parent.context
        when :ulist
          @list_bullets.last
        when :olist
          @list_numbers << (index = @list_numbers.pop).next
          %(#{index}.)
        when :colist
          @list_numbers << (index = @list_numbers.pop).next
          # FIXME cleaner way to do numbers in colist; need more room around number
          theme_font :conum do
            # QUESTION should this be align: :left or :center?
            layout_prose index, align: :left, line_height: @theme.conum_line_height, inline_format: false, margin: 0
          end
          next # short circuit label
        end
        layout_prose label, align: :center, normalize: false, inline_format: false, margin: 0
      end
    end
    convert_content_for_list_item node
  end

  def convert_content_for_list_item node
    if node.text?
      opts = {}
      opts[:align] = :left if node.parent.style == 'bibliography'
      layout_prose node.text, opts
    end
    convert_content_for_block node
  end

  def convert_image node
    #move_down @theme.block_margin_top unless at_page_top?
    theme_margin :block, :top
    target = node.attr 'target'
    #if target.end_with? '.pdf'
    #  import_page target
    #  return
    #end

    # FIXME use normalize_path here!
    image_path = File.join((node.attr 'docdir'), (node.attr 'imagesdir') || '', target)
    # TODO extension should be an attribute on an image node
    image_type = File.extname(image_path)[1..-1]
    width = if node.attr? 'scaledwidth'
      ((node.attr 'scaledwidth').to_f / 100.0) * bounds.width
    elsif image_type == 'svg'
      bounds.width
    elsif node.attr? 'width'
      (node.attr 'width').to_f
    else
      bounds.width * (@theme.image_scaled_width_default || 0.75)
    end
    height = nil
    position = ((node.attr 'align') || @theme.image_align_default || :left).to_sym
    case image_type
    when 'svg'
      keep_together do
        # HACK prawn-svg can't seem to center, so do it manually for now
        left = case position
        when :left
          0
        when :right
          bounds.width - width
        when :center
          ((bounds.width - width) / 2.0).floor
        end
        svg IO.read(image_path), at: [left, cursor], width: width, position: position
        layout_caption node, position: :bottom if node.title?
      end
    else
      begin
        # FIXME temporary workaround to group caption & image
        # Prawn doesn't provide access to rendered width and height before placing the
        # image on the page
        image_obj, image_info = build_image_object node.image_uri image_path
        rendered_w, rendered_h = image_info.calc_image_dimensions width: width
        caption_height = node.title? ?
            (@theme.caption_margin_inside + @theme.caption_margin_outside + @theme.base_line_height_length) : 0
        if cursor < rendered_h + caption_height
          start_new_page
          if cursor < rendered_h + caption_height
            height = (cursor - caption_height).floor
            width = ((rendered_w * height) / rendered_h).floor
            # FIXME workaround to fix Prawn not adding fill and stroke commands
            # on page that only has an image; breakage occurs when line numbers are added
            fill_color self.fill_color
            stroke_color self.stroke_color
          end
        end
        embed_image image_obj, image_info, width: width, height: height, position: position
      rescue => e
        warn %(asciidoctor: WARNING: could not embed image; #{e.message})
        return
      end
      layout_caption node, position: :bottom if node.title?
    end
    #move_down @theme.block_margin_bottom
    theme_margin :block, :bottom
  end

  def convert_listing_or_literal node
    # HACK disable built-in syntax highlighter; must be done before calling node.content!
    if (node.style == 'source')
      node.subs.delete :highlight
    end
    # FIXME highlighter freaks out about the non-breaking space characters
    source_string = prepare_verbatim node.content
    source_chunks = if node.context == :listing && (node.attr? 'language') && (node.attr? 'source-highlighter')
      case node.attr 'source-highlighter'
      when 'coderay'
        # FIXME use autoload here!
        require_relative 'prawn_ext/coderay_encoder' unless defined? ::Asciidoctor::Prawn::CodeRayEncoder
        (::CodeRay.scan source_string, (node.attr 'language', 'text').to_sym).to_prawn
      when 'pygments'
        # FIXME use autoload here!
        require 'pygments.rb' unless defined? ::Pygments
        # FIXME if lexer is nil, we don't escape specialchars!
        if (lexer = ::Pygments::Lexer[(node.attr 'language')])
          pygments_config = { nowrap: true, noclasses: true, style: ((node.document.attr 'pygments-style') || 'pastie') }
          result = lexer.highlight(source_string, options: pygments_config)
          result = result.gsub(/(?<lead>^| )(?:<span style="font-style: italic">(?:\/\/|#) ?&lt;(?<num>\d+)&gt;<\/span>|&lt;(?<num>\d+)&gt;)$/) {
            # FIXME move \u2460 to constant (or theme setting)
            num = %(\u2460)
            (($~[:num]).to_i - 1).times { num = num.next }
            if (conum_color = @theme.conum_font_color)
              %(#{$~[:lead]}<color rgb="#{conum_color}">#{num}</color>)
            end
          }
          text_formatter.format result
        end
      end
    end
    source_chunks ||= [{ text: source_string }]

    #move_down @theme.block_margin_top unless at_page_top?
    theme_margin :block, :top

    keep_together do |box_height = nil|
      caption_height = node.title? ? (layout_caption node) : 0
      theme_font :code do
        if box_height
          float do
            # FIXME don't use border / border radius at page boundaries
            # TODO move this logic to theme_fill_and_stroke_bounds
            remaining_height = box_height - caption_height
            i = 0
            while remaining_height > 0
              start_new_page if i > 0
              fill_height = [remaining_height, cursor].min
              bounding_box [0, cursor], width: bounds.width, height: fill_height do
                theme_fill_and_stroke_bounds :code
              end
              remaining_height -= fill_height
              i += 1
            end
          end
        end

        pad_box @theme.code_padding do
          typeset_formatted_text source_chunks, (calc_line_metrics @theme.code_line_height), color: @theme.code_font_color
        end
      end
    end
    stroke_horizontal_rule @theme.caption_border_bottom_color if node.title? && @theme.caption_border_bottom_color

    #move_down @theme.block_margin_bottom
    theme_margin :block, :bottom
  end

  alias :convert_listing :convert_listing_or_literal
  alias :convert_literal :convert_listing_or_literal

  def convert_table node
    num_rows = 0
    num_cols = node.columns.size
    table_header = false

    table_data = []
    node.rows[:head].each do |rows|
      table_header = true
      num_rows += 1
      row_data = []
      rows.each do |cell|
        row_data << {
          content: cell.text,
          text_color: (@theme.table_head_font_color || @font_color),
          inline_format: true,
          font_style: :bold,
          colspan: cell.colspan || 1,
          rowspan: cell.rowspan || 1,
          align: (cell.attr 'halign').to_sym,
          valign: (cell.attr 'valign').to_sym
        }
      end
      table_data << row_data
    end

    node.rows[:body].each do |rows|
      num_rows += 1
      row_data = []
      rows.each do |cell|
        cell_data = {
          content: cell.text,
          text_color: (@theme.table_body_font_color || @font_color),
          inline_format: true,
          colspan: cell.colspan || 1,
          rowspan: cell.rowspan || 1,
          align: (cell.attr 'halign').to_sym,
          valign: (cell.attr 'valign').to_sym
        }
        case cell.style
        when :emphasis
          cell_data[:font_style] = :italic
        when :strong, :header
          cell_data[:font_style] = :bold
        when :monospaced
          cell_data[:font] = @theme.literal_font_family
          if (size = @theme.literal_font_size)
            cell_data[:size] = size
          end
          if (color = @theme.literal_font_color)
            cell_data[:text_color] = color
          end
        # TODO finish me
        end
        row_data << cell_data
      end
      table_data << row_data
    end

    # TODO support footer row

    column_widths = node.columns.map {|col| ((col.attr 'colpcwidth') * bounds.width) / 100.0 }

    border = {}
    table_border_width = @theme.table_border_width
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

    table_settings = {
      header: table_header,
      cell_style: {
        padding: @theme.table_cell_padding,
        border_width: 0,
        border_color: @theme.table_border_color
      },
      column_widths: column_widths,
      row_colors: ['FFFFFF', @theme.table_background_color_alt]
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
    end
    theme_margin :block, :bottom
  end

  def convert_thematic_break node
    #move_down @theme.thematic_break_margin_top
    theme_margin :thematic_break, :top
    stroke_horizontal_rule @theme.thematic_break_border_color, line_width: @theme.thematic_break_border_width
    #move_down @theme.thematic_break_margin_bottom
    theme_margin :thematic_break, :bottom
  end

  # deprecated
  alias :convert_horizontal_rule :convert_thematic_break

  # NOTE can't alias to start_new_page since methods have different arity
  def convert_page_break node
    start_new_page unless at_page_top?
  end

  def convert_inline_anchor node
    target = node.target
    case node.type
    when :xref
      refid = (node.attr 'refid') || target
      # NOTE we lookup text in converter because DocBook doesn't need this logic
      if (text = node.text || (node.document.references[:ids][refid] || %([#{refid}])))
        # FIXME shouldn't target be refid? logic seems confused here
        %(<link anchor="#{target}">#{text}</link>)
      # FIXME hack for bibliography references
      # should be able to reenable once we parse inline destinations
      else
        %((see [#{refid}]))
      end
    when :ref
      #%(<a id="#{target}"></a>)
      ''
    when :bibref
      #%(<a id="#{target}"></a>[#{target}])
      %([#{target}])
    when :link
      attrs = []
      #attrs << %( id="#{node.id}") if node.id
      if (role = node.role)
        attrs << %( class="#{role}")
      end
      #attrs << %( title="#{node.attr 'title'}") if node.attr? 'title'
      attrs << %( target="#{node.attr 'window'}") if node.attr? 'window'
      if (node.document.attr? 'showlinks') && !(node.has_role? 'bare')
        # TODO cleanup look, perhaps put target in smaller text
        %(<link href="#{target}"#{attrs.join}>#{node.text}</a> (#{target}))
      else
        %(<link href="#{target}"#{attrs.join}>#{node.text}</a>)
      end
    else
      warn %(asciidoctor: WARNING: unknown anchor type: #{node.type.inspect})
    end
  end

  def convert_inline_break node
    %(#{node.text}<br>)
  end

  def convert_inline_button node
    %(<b>[#{NarrowNoBreakSpace}#{node.text}#{NarrowNoBreakSpace}]</b>)
  end

  def convert_inline_footnote node
    if (index = node.attr 'index')
      #text = node.document.footnotes.find {|fn| fn.index == index }.text
      %( [#{node.text}])
    elsif node.type == :xref
      %( <color rgb="FF0000">[#{node.text}]</color>)
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

    node.id ? %(<a id="#{node.id}"></a>#{quoted_text}) : quoted_text
  end

  def layout_title_page doc
    return unless doc.header? && !doc.noheader && !doc.notitle

    start_new_page
    # IMPORTANT this is the first page created, so we need to set the base font
    font @theme.base_font_family, size: @theme.base_font_size

    # TODO treat title-logo like front and back cover images
    if doc.attr? 'title-logo'
      # FIXME theme setting
      move_down @theme.vertical_rhythm * 2
      # FIXME add API to Asciidoctor for creating blocks like this (extract from extensions module?)
      image = ::Asciidoctor::Block.new doc, :image, content_model: :empty
      attrs = { 'target' => (doc.attr 'title-logo'), 'align' => 'center' }
      image.update_attributes attrs
      convert_image image
      # FIXME theme setting
      move_down @theme.vertical_rhythm * 4
    end

    # FIXME only create title page if doctype=book!
    # FIXME honor subtitle!
    theme_font :heading, level: 1 do
      layout_heading doc.doctitle, align: :center
    end
    # FIXME theme setting
    move_down @theme.vertical_rhythm
    if doc.attr? 'authors'
      layout_prose doc.attr('authors'), align: :center, margin_top: 0, margin_bottom: @theme.vertical_rhythm / 2.0, normalize: false
    end
    layout_prose [(doc.attr? 'revnumber') ? %(#{doc.attr 'version-label'} #{doc.attr 'revnumber'}) : nil, (doc.attr 'revdate')].compact * "\n", align: :center, margin_top: @theme.vertical_rhythm * 5, margin_bottom: 0, normalize: false
  end

  def layout_cover_page position, doc
    # TODO turn processing of attribute with inline image a utility function in Asciidoctor
    if (cover_image = (doc.attr %(#{position}-cover-image)))
      if cover_image =~ ImageAttributeValueRx
        cover_image = %(#{resolve_imagesdir doc}#{$1})
      end
      # QUESTION should we go to page 1 when position == :front?
      go_to_page page_count if position == :back
      image_page cover_image, canvas: true
    end
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
    margin_top = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || @theme.heading_margin_top
    margin_bottom = margin || (opts.delete :margin_bottom) || @theme.heading_margin_bottom
    #move_down margin_top
    self.margin_top margin_top
    typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme.heading_line_height), {
      color: @font_color,
      inline_format: true,
      align: :left
    }.merge(opts)
    #move_down margin_bottom
    self.margin_bottom margin_bottom
  end

  # NOTE inline_format is true by default
  def layout_prose string, opts = {}
    margin_top = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || @theme.prose_margin_top || 0
    margin_bottom = margin || (opts.delete :margin_bottom) || @theme.prose_margin_bottom || @theme.vertical_rhythm
    if (anchor = opts.delete :anchor)
      # FIXME won't work if inline_format is true; should instead pass through as attribute w/ link color set
      if (link_color = opts.delete :link_color)
        string = %(<link anchor="#{anchor}"><color rgb="#{link_color}">#{string}</color></link>)
      else
        string = %(<link anchor="#{anchor}">#{string}</link>)
      end
    end
    if opts.delete :preserve
      # preserve leading space using non-breaking space chars
      string = string.gsub(IndentationRx) { NoBreakSpace * $&.length }
    end
    #move_down margin_top
    self.margin_top margin_top
    typeset_text string, calc_line_metrics((opts.delete :line_height) || @theme.base_line_height), {
      color: @font_color,
      # NOTE normalize makes endlines soft (replaces "\n" with ' ')
      inline_format: [{ normalize: (opts.delete :normalize) != false }],
      align: (@theme.base_align || :justify).to_sym
    }.merge(opts)
    #move_down margin_bottom
    self.margin_bottom margin_bottom
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
        align: (@theme.caption_align || :left).to_sym,
        normalize: false
      }.merge(opts)
      if position == :top && @theme.caption_border_bottom_color
        stroke_horizontal_rule @theme.caption_border_bottom_color
        # HACK move down slightly so line isn't covered by filled area (half width of line)
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
    go_to_page toc_page_number unless scratch? || page_number == toc_page_number
    theme_font :heading, level: 2 do
      layout_heading doc.attr('toc-title')
    end
    line_metrics = calc_line_metrics @theme.base_line_height
    dot_width = width_of DotLeader
    if num_levels > 0
      layout_toc_level doc.sections, num_levels, line_metrics, dot_width, num_front_matter_pages
    end
    toc_page_numbers = (toc_page_number..page_number)
    go_to_page page_count - 1 unless scratch?
    toc_page_numbers
  end

  def layout_toc_level sections, num_levels, line_metrics, dot_width, num_front_matter_pages = 0
    sections.each do |sect|
      sect_title = sect.numbered_title
      # NOTE we do some cursor hacking here so the dots don't affect vertical alignment
      start_page_number = page_number
      start_cursor = cursor
      typeset_text %(<link anchor="#{sect.id}">#{sect_title}</link>), line_metrics, inline_format: true
      # we only write the label if this is a dry run
      unless scratch?
        end_page_number = page_number
        end_cursor = cursor
        # TODO it would be convenient to have a cursor mark / placement utility that took page number into account
        go_to_page start_page_number if start_page_number != end_page_number
        move_cursor_to start_cursor
        sect_page_num = (sect.attr 'page_start') - num_front_matter_pages
        num_dots = ((bounds.width - (width_of %(#{sect_title} #{sect_page_num}), inline_format: true)) / dot_width).floor
        typeset_formatted_text [text: %(#{DotLeader * num_dots} #{sect_page_num}), anchor: sect.id], line_metrics, align: :right
        go_to_page end_page_number if start_page_number != end_page_number
        move_cursor_to end_cursor
      end
      if sect.level < num_levels
        indent @theme.horizontal_rhythm do
          layout_toc_level sect.sections, num_levels, line_metrics, dot_width, num_front_matter_pages
        end
      end
    end
  end

  def stamp_page_numbers opts = {}
    skip = opts[:skip] || 1
    start = skip + 1
    pattern = page_number_pattern
    repeat (start..page_count), dynamic: true do
      # don't stamp pages which are imported / inserts
      next if page.imported_page?
      case (align = (page_number - skip).odd? ? :left : :right)
      when :left
        page_number_label = pattern[:left] % [page_number - skip]
      when :right
        page_number_label = pattern[:right] % [page_number - skip]
      end
      theme_font :footer do
        canvas do
          if @theme.footer_border_color && @theme.footer_border_color != 'transparent'
            save_graphics_state do
              line_width @theme.base_border_width
              stroke_color @theme.footer_border_color
              stroke_horizontal_line left_margin, bounds.width - right_margin, at: (page.margins[:bottom] / 2.0 + @theme.vertical_rhythm / 2.0)
            end
          end
          indent left_margin, right_margin do
            formatted_text_box [text: page_number_label, color: @theme.footer_font_color], at: [0, (page.margins[:bottom] / 2.0)], align: align
          end
        end
      end
    end
  end

  def page_number_pattern
    { left: '%s', right: '%s' }
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
    if doc.header? && !doc.noheader && !doc.notitle
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
      if (doctitle = (doc.doctitle sanitize: true, use_fallback: true))
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
      sect_title = sanitize(sect.numbered_title formal: true)
      sect_destination = sect.attr 'destination'
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
    pdf_doc.render_file target
    #@prototype.render_file 'scratch.pdf'
    # QUESTION restore attributes first?
    @pdfmarks.generate_file target if @pdfmarks
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

  def theme_fill_and_stroke_bounds category
    fill_and_stroke_bounds @theme[%(#{category}_background_color)], @theme[%(#{category}_border_color)], {
      line_width: @theme[%(#{category}_border_width)],
      radius: @theme[%(#{category}_border_radius)]
    }
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
      if cursor <= y
        @margin_box.move_past_bottom
      else
        move_down y
      end
    end
  end

  # Lookup margin for theme element and position, then delegate to margin method.
  # If the margin value is not found, assume 0 for position = :top and $vertical_rhythm for position = :bottom.
  def theme_margin category, position
    margin(@theme[%(#{category}_margin_#{position})] || (position == :bottom ? @theme.vertical_rhythm : 0), position)
  end

  def theme_font category, opts = {}
    # QUESTION should we fallback to base_font_* or just leave current setting?
    family = @theme[%(#{category}_font_family)] || @theme.base_font_family

    if (level = opts[:level])
      size = @theme[%(#{category}_font_size_h#{level})] || @theme.base_font_size
    else
      size = @theme[%(#{category}_font_size)] || @theme.base_font_size
    end

    style = (@theme[%(#{category}_font_style)] || :normal).to_sym

    if level
      color = @theme[%(#{category}_font_color_h#{level})] || @theme[%(#{category}_font_color)]
    else
      color = @theme[%(#{category}_font_color)]
    end

    if color
      prev_color = @font_color
      @font_color = color
    end
    font family, size: size, style: style do
      yield
    end
    if color
      @font_color = prev_color
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

  def prepare_verbatim string
    string.gsub(BuiltInEntityCharsRx, BuiltInEntityChars)
        .gsub(IndentationRx) { NoBreakSpace * $&.length }
  end

  # Remove all HTML tags and resolve all entities in a string
  # FIXME add option to control escaping entities, or a filter mechanism in general
  def sanitize string
    string.gsub(/<[^>]+>/, '')
        .gsub(/&#(\d{2,4});/) { [$1.to_i].pack('U*') }
        .gsub('&lt;', '<').gsub('&gt;', '>').gsub('&amp;', '&')
        .tr_s(' ', ' ')
        .strip
  end

  def resolve_imagesdir doc
    @imagesdir ||= begin
      imagesdir = (doc.attr 'imagesdir', '.').chomp '/'
      imagesdir = imagesdir == '.' ? nil : %(#{imagesdir}/)
    end
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
  def create_stamps
    create_stamp 'masthead' do
      canvas do
        save_graphics_state do
          stroke_color '000000'
          x_margin = mm2pt 20
          y_margin = mm2pt 15
          stroke_horizontal_line x_margin, bounds.right - x_margin, at: bounds.top - y_margin
          stroke_horizontal_line x_margin, bounds.right - x_margin, at: y_margin
        end
      end
    end

    @stamps_initialized = true
  end
=end
end
end
end
