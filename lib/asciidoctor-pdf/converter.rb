# encoding: UTF-8
# TODO cleanup imports...decide what belongs in asciidoctor-pdf.rb
require_relative 'core_ext/array'
require 'prawn'
require 'prawn-svg'
require 'prawn/table'
require 'prawn/templates'
require 'prawn/icon'
require_relative 'pdf_core_ext'
require_relative 'sanitizer'
require_relative 'prawn_ext'
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

  def self.unicode_char number
    [number].pack 'U*'
  end

  AdmonitionIcons = {
    caution:   { key: 'fa-fire', color: 'BF3400' },
    important: { key: 'fa-exclamation-circle', color: 'BF0000' },
    note:      { key: 'fa-info-circle', color: '19407C' },
    tip:       { key: 'fa-lightbulb-o', color: '111111' },
    warning:   { key: 'fa-exclamation-triangle', color: 'BF6900' }
  }

  IndentationRx = /^ +/
  TabSpaces = ' ' * 4
  NoBreakSpace = unicode_char 0x00a0
  NarrowNoBreakSpace = unicode_char 0x202f
  HairSpace = unicode_char 0x200a
  DotLeader = %(#{HairSpace}.)
  EmDash = unicode_char 0x2014
  LowercaseGreekA = unicode_char 0x03b1
  Bullets = {
    disc: (unicode_char 0x2022),
    circle: (unicode_char 0x25e6),
    square: (unicode_char 0x25aa)
  }
  ImageAttributeValueRx = /^image:{1,2}(.*?)\[(.*?)\]$/

  def initialize backend, opts
    super
    basebackend 'html'
    outfilesuffix '.pdf'
    #htmlsyntax 'xml'
    @list_numbers = []
    @list_bullets = []
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
      # TODO this content could be catched on repeat invocations!
      layout_prose string, opts
    end
    node.document.instance_variable_set :@converter, prev_converter if prev_converter
  end

  def convert_document doc
    init_pdf doc
    # data-uri doesn't apply to PDF, so explicitly disable (is there a better place?)
    doc.attributes.delete 'data-uri'

    on_page_create do
      # TODO implement as a watermark (on top)
      if @page_bg_image
        # FIXME implement fitting and centering for SVG
        # TODO implement image scaling (numeric value or "fit")
        float { canvas { image @page_bg_image, position: :center, fit: [bounds.width, bounds.height] } }
      elsif @page_bg_color
        fill_absolute_bounds @page_bg_color
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
    theme = ThemeLoader.load_theme doc.attr('pdf-style'), (stylesdir = (doc.attr 'pdf-stylesdir'))
    pdf_opts = (build_pdf_options doc, theme)
    @theme = theme
    ::Prawn::Document.instance_method(:initialize).bind(self).call pdf_opts
    # QUESTION should ThemeLoader register fonts?
    register_fonts theme.font_catalog, (doc.attr 'scripts', 'latin'), (doc.attr 'pdf-fontsdir', ThemeLoader::FontsDir)
    if (bg_image = theme.page_background_image) && bg_image != 'none'
      if ::File.readable?(bg_image = (ThemeLoader.resolve_theme_asset bg_image, stylesdir))
        @page_bg_image = bg_image
      else
        warn %(asciidoctor: WARNING: page background image #{bg_image} not found or readable)
      end
    end
    if ['FFFFFF', 'transparent'].include?(@page_bg_color = theme.page_background_color)
      @page_bg_color = nil
    end
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
      skip_page_creation: true,
    }

    if doc.attr? 'pdf-page-size'
      page_size = ::YAML.safe_load(doc.attr 'pdf-page-size')
    else
      page_size = theme.page_size
    end

    pdf_opts[:page_size] = case page_size
    when ::String
      if ::PDF::Core::PageGeometry::SIZES.key?(page_size = page_size.upcase)
        page_size
      else
        'LETTER'
      end
    when ::Array
      page_size.fill(0..1) {|i| page_size[i] || 0 }.map {|d|
        if ::Numeric === d
          break if d == 0
          d
        elsif ::String === d && (m = /^(\d*(?:\.\d+)?)(in|mm|cm|pt)$/.match d)
          val = m[1].to_f
          val = case m[2]
          when 'in'
            val * 72
          when 'mm'
            val * (72 / 25.4)
          when 'cm'
            val * (720 / 25.4)
          when 'pt'
            val
          end
          # NOTE 4 is the max practical precision in PDFs
          if (val = val.round 4) == (i_val = val.to_i)
            val = i_val
          end
          val
        else
          break
        end
      }
    end

    pdf_opts[:page_size] ||= 'LETTER'

    # FIXME fix the namespace for FormattedTextFormatter
    pdf_opts[:text_formatter] ||= ::Asciidoctor::Prawn::FormattedTextFormatter.new theme: theme
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
    #move_down @theme.block_margin_top unless at_page_top?
    theme_margin :block, :top
    icons = node.document.attr? 'icons', 'font'
    label = icons ? (node.attr 'name').to_sym : node.caption.upcase
    shift_base = @theme.prose_margin_bottom || @theme.vertical_rhythm
    #shift_top = icons ? (shift_base / 3.0) : 0
    #shift_bottom = icons ? ((shift_base * 2) / 3.0) : shift_base
    shift_top = shift_base / 3.0
    shift_bottom = (shift_base * 2) / 3.0
    keep_together do |box_height = nil|
      #theme_font :admonition do
        label_width = icons ? (bounds.width / 12.0) : (width_of label)
        # FIXME use padding from theme
        indent @theme.horizontal_rhythm, @theme.horizontal_rhythm do
          if box_height
            float do
              bounding_box [0, cursor], width: label_width + @theme.horizontal_rhythm, height: box_height do
                # IMPORTANT the label must fit in the alotted space or it shows up on another page!
                # QUESTION anyway to prevent text overflow in the case it doesn't fit?
                stroke_vertical_rule @theme.admonition_border_color, at: bounds.width
                # FIXME HACK make title in this location look right
                label_margin_top = node.title? ? @theme.caption_margin_inside : 0
                if icons
                  admon_icon_data = AdmonitionIcons[label]
                  icon admon_icon_data[:key], valign: :center, align: :center, color: admon_icon_data[:color], size: (admonition_icon_size node)
                else
                  layout_prose label, valign: :center, style: :bold, line_height: 1, margin_top: label_margin_top, margin_bottom: 0
                end
              end
            end
          end
          indent label_width + @theme.horizontal_rhythm * 2 do
            move_down shift_top
            layout_caption node.title if node.title?
            convert_content_for_block node
            # FIXME HACK compensate for margin bottom of admonition content
            move_up shift_bottom
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
        # FIXME HACK compensate for margin bottom of sidebar content
        move_up(@theme.prose_margin_bottom || @theme.vertical_rhythm)
      end
    end
    #move_down @theme.block_margin_bottom
    theme_margin :block, :bottom
  end

  def convert_colist node
    # HACK undo the margin below previous listing or literal block
    unless at_page_top? || (self_idx = node.parent.blocks.index node) == 0 ||
        ![:listing, :literal].include?(node.parent.blocks[self_idx - 1].context)
      move_up ((@theme.block_margin_bottom || @theme.vertical_rhythm) * 0.5)
    end
    @list_numbers ||= []
    # FIXME move \u2460 to constant (or theme setting)
    # \u2460 = circled one, \u24f5 = double circled one, \u278b = negative circled one
    @list_numbers << %(\u2460)
    #stroke_horizontal_rule @theme.caption_border_bottom_color
    line_metrics = calc_line_metrics @theme.base_line_height
    item_spacing_adjustment = (@theme.prose_margin_bottom || @theme.vertical_rhythm) * 0.5
    node.items.each_with_index do |item, idx|
      # FIXME HACK tighten items on colist
      move_up item_spacing_adjustment unless idx == 0
      # FIXME extract to an ensure_space (or similar) method; simplify
      start_new_page if cursor < (line_metrics.height + line_metrics.leading + line_metrics.padding_top)
      convert_colist_item item
    end
    @list_numbers.pop
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
      convert_content_for_list_item node
    end
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
    line_metrics = calc_line_metrics @theme.base_line_height
    indent @theme.outline_list_indent do
      node.items.each do |item|
        # FIXME extract to an ensure_space (or similar) method; simplify
        start_new_page if cursor < (line_metrics.height + line_metrics.leading + line_metrics.padding_top)
        convert_outline_list_item item
      end
    end
    # NOTE children will provide the necessary bottom margin
  end

  def convert_outline_list_item node
    # TODO move this to a draw_bullet (or draw_marker) method
    marker = case (list_type = node.parent.context)
    when :ulist
      @list_bullets.last
    when :olist
      @list_numbers << (index = @list_numbers.pop).next
      %(#{index}.)
    else
      warn %(asciidoctor: WARNING: unknown list type #{list_type.inspect})
      Bullets[:disc]
    end

    marker_width = width_of marker
    start_position = -marker_width + -(width_of 'x')
    float do
      bounding_box [start_position, cursor], width: marker_width do
        layout_prose marker,
          align: :right,
          normalize: false,
          inline_format: false,
          margin: 0,
          character_spacing: -0.5,
          single_line: true
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
    valid_image = true
    target = node.attr 'target'
    # TODO file extension should be an attribute on an image node
    image_type = (::File.extname target)[1..-1].downcase

    if image_type == 'gif'
      valid_image = false
      warn %(asciidoctor: WARNING: GIF image format not supported. Please convert the image #{target} to PNG.)
    #elsif image_type == 'pdf'
    #  import_page image_path
    #  return
    end

    unless (image_path = resolve_image_path node, target) && (::File.readable? image_path)
      valid_image = false
      warn %(asciidoctor: WARNING: image to embed not found or not readable: #{image_path || target})
    end

    unless valid_image
      theme_margin :block, :top
      layout_prose %(#{node.attr 'alt'} | #{target}), normalize: false, margin: 0, single_line: true
      layout_caption node, position: :bottom if node.title?
      theme_margin :block, :bottom
      return
    end

    theme_margin :block, :top

    # TODO support cover (aka canvas) image layout using "canvas" (or "cover") role
    width = if node.attr? 'scaledwidth'
      ((node.attr 'scaledwidth').to_f / 100.0) * bounds.width
    elsif image_type == 'svg'
      bounds.width
    elsif node.attr? 'width'
      (node.attr 'width').to_f
    else
      bounds.width * (@theme.image_scaled_width_default || 0.75)
    end
    position = ((node.attr 'align') || @theme.image_align_default || :left).to_sym
    case image_type
    when 'svg'
      # NOTE prawn-svg can't position, so we have to do it manually (file issue?)
      left = case position
      when :left
        0
      when :right
        bounds.width - width
      when :center
        ((bounds.width - width) / 2.0).floor
      end
      begin
        keep_together do
          svg (::IO.read image_path), at: [left, cursor], width: width
          layout_caption node, position: :bottom if node.title?
        end
      rescue => e
        warn %(asciidoctor: WARNING: could not embed image: #{image_path}; #{e.message})
      end
    else
      begin
        # FIXME temporary workaround to group caption & image
        # Prawn doesn't provide access to rendered width and height before placing the
        # image on the page
        image_obj, image_info = build_image_object image_path
        rendered_w, rendered_h = image_info.calc_image_dimensions width: width
        caption_height = node.title? ?
            (@theme.caption_margin_inside + @theme.caption_margin_outside + @theme.base_line_height_length) : 0
        height = nil
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
        warn %(asciidoctor: WARNING: could not embed image: #{image_path}; #{e.message})
      end
      layout_caption node, position: :bottom if node.title?
    end
    theme_margin :block, :bottom
  ensure
    unlink_tmp_file image_path
  end

  # TODO shrink text if it's too wide to fit in the bounding box
  def convert_listing_or_literal node
    # HACK disable built-in syntax highlighter; must be done before calling node.content!
    if node.style == 'source' && ((subs = node.subs).include? :highlight)
      highlighter = node.document.attr 'source-highlighter'
      # NOTE the source highlighter logic below handles the callouts and highlight subs
      # QUESTION should we restore subs after conversion?
      subs.delete :callouts
      subs.delete :highlight
    else
      highlighter = nil
    end
    # FIXME source highlighter freaks out about the non-breaking space characters; does it?
    source_string = preserve_indentation node.content
    source_chunks = case highlighter
    when 'coderay'
      unless defined? ::Asciidoctor::Prawn::CodeRayEncoder
        # NOTE require_library doesn't support require_relative and we don't modify the load path for this gem
        Helpers.require_library ::File.join(::File.dirname(__FILE__), 'prawn_ext/coderay_encoder'), 'coderay'
      end
      source_string, conum_mapping = extract_conums source_string
      fragments = (::CodeRay.scan source_string, (node.attr 'language', 'text', false).to_sym).to_prawn
      conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
    when 'pygments'
      Helpers.require_library 'pygments', 'pygments.rb'
      source_string, conum_mapping = extract_conums source_string
      lexer = ::Pygments::Lexer[node.attr 'language', 'text', false] || ::Pygments::Lexer['text']
      pygments_config = { nowrap: true, noclasses: true, style: (node.document.attr 'pygments-style') || 'pastie' }
      result = lexer.highlight source_string, options: pygments_config
      fragments = text_formatter.format result
      conum_mapping ? (restore_conums fragments, conum_mapping) : fragments
    else
      # NOTE only format if we detect a need
      (source_string =~ BuiltInEntityCharOrTagRx) ? (text_formatter.format source_string) : [{ text: source_string }]
    end

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
          line << fragment.merge(text: line_in_fragment) unless line_in_fragment.empty?
        end
      else
        line << fragment
      end
    end
    conum_color = @theme.conum_font_color
    last_line_num = lines.size - 1
    # append conums to appropriate lines, then flatten to an array of fragments
    lines.flat_map.with_index do |line, line_num|
      if (conums = conum_mapping.delete line_num)
        conums = conums.map {|num| conum_glyph num }
        # ensure there's at least one space between content and conum(s)
        if line.size > 0 && (end_text = line.last[:text]) && !(end_text.end_with? ' ')
          line.last[:text] = %(#{end_text} )
        end
        line << { text: (conums * ' '), color: conum_color }
      end
      line << { text: EOL } unless line_num == last_line_num
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

  def convert_table node
    num_rows = 0
    num_cols = node.columns.size
    table_header = false

    # FIXME this is a mess!
    unless (page_bg_color = @theme.page_background_color) && page_bg_color != 'transparent'
      page_bg_color = nil
    end

    unless (bg_color = @theme.table_background_color) && bg_color != 'transparent'
      bg_color = page_bg_color
    end

    unless (head_bg_color = @theme.table_head_background_color) && head_bg_color != 'transparent'
      head_bg_color = bg_color
    end

    unless (odd_row_bg_color = @theme.table_odd_row_background_color) && odd_row_bg_color != 'transparent'
      odd_row_bg_color = bg_color
    end

    unless (even_row_bg_color = @theme.table_even_row_background_color) && even_row_bg_color != 'transparent'
      even_row_bg_color = bg_color
    end

    table_data = []
    node.rows[:head].each do |rows|
      table_header = true
      num_rows += 1
      row_data = []
      rows.each do |cell|
        row_data << {
          content: cell.text,
          inline_format: [{ normalize: true }],
          background_color: head_bg_color,
          text_color: (@theme.table_head_font_color || @theme.table_font_color || @font_color),
          size: (@theme.table_head_font_size || @theme.table_font_size),
          font: (@theme.table_head_font_family || @theme.table_font_family),
          font_style: (@theme.table_head_font_style || :bold).to_sym,
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
          inline_format: [{ normalize: true }],
          text_color: (@theme.table_body_font_color || @font_color),
          size: @theme.table_font_size,
          font: @theme.table_font_family,
          colspan: cell.colspan || 1,
          rowspan: cell.rowspan || 1,
          align: (cell.attr 'halign').to_sym,
          valign: (cell.attr 'valign').to_sym
        }
        cell_data[:valign] = :center if cell_data[:valign] == :middle
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
      target = node.target
      # NOTE the presence of path indicates an inter-document xref
      if (path = node.attributes['path'])
        # QUESTION should we use local instead of href here?
        %(<a href="#{target}">#{node.text || path}</a>)
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
      # FIXME add destination to PDF document
      #target = node.target
      #%(<a id="#{target}"></a>)
      ''
    when :bibref
      # FIXME add destination to PDF document
      #target = node.target
      #%(<a id="#{target}"></a>[#{target}])
      %([#{node.target}])
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

  def convert_inline_callout node
    if (conum_color = @theme.conum_font_color)
      %(<color rgb="#{conum_color}">#{conum_glyph node.text.to_i}</color>)
    else
      node.text
    end
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

  # FIXME only create title page if doctype=book!
  def layout_title_page doc
    return unless doc.header? && !doc.noheader && !doc.notitle

    prev_bg_image = @page_bg_image
    prev_bg_color = @page_bg_color
    if (bg_image = (doc.attr 'title-background-image', @theme.title_page_background_image))
      if bg_image == 'none'
        @page_bg_image = nil
      else
        if bg_image =~ ImageAttributeValueRx
          bg_image = $1
          # QUESTION should we support width and height?
        end

        # NOTE resolve image relative to its origin
        resolved_bg_image = if doc.attr? 'title-background-image'
          resolve_image_path doc, bg_image
        else
          ThemeLoader.resolve_theme_asset bg_image, (doc.attr 'pdf-stylesdir')
        end

        if resolved_bg_image && (::File.readable? resolved_bg_image)
          @page_bg_image = resolved_bg_image
        else
          warn %(asciidoctor: WARNING: title page background image #{resolved_bg_image || bg_image} not found or readable)
          bg_image = nil
        end
      end
    end
    if !bg_image && (bg_color = @theme.title_page_background_color) && bg_color != 'transparent'
      @page_bg_color = bg_color
    else
      bg_color = nil
    end
    start_new_page
    @page_bg_image = prev_bg_image if bg_image
    @page_bg_color = prev_bg_color if bg_color

    # IMPORTANT this is the first page created, so we need to set the base font
    font @theme.base_font_family, size: @theme.base_font_size

    # QUESTION allow aligment per element on title page?
    title_align = (@theme.title_page_align || :center).to_sym

    # FIXME rework image handling once fix for #134 is merged
    if (logo_image_path = (doc.attr 'title-logo-image', @theme.title_page_logo_image))
      if logo_image_path =~ ImageAttributeValueRx
        logo_image_path = $1
        logo_image_attrs = ::Asciidoctor::AttributeList.new($2).parse(['alt', 'width', 'height'])
      else
        logo_image_attrs = {}
      end
      # HACK quick fix to resolve image path relative to theme
      unless doc.attr? 'title-logo-image'
        # FIXME use ThemeLoader.resolve_theme_asset once fix for #134 is merged
        logo_image_path = ::File.expand_path logo_image_path, (doc.attr 'pdf-stylesdir', ThemeLoader::ThemesDir) 
      end
      logo_image_attrs['target'] = logo_image_path
      logo_image_attrs['align'] ||= (@theme.title_page_logo_align || title_align.to_s)
      logo_image_top = (logo_image_attrs['top'] || @theme.title_page_logo_top || '10%')
      # FIXME delegate to method to convert page % to y value
      logo_image_top = [(page_height - page_height * (logo_image_top.to_i / 100.0)), bounds.absolute_top].min
      float do
        @y = logo_image_top
        # FIXME add API to Asciidoctor for creating blocks like this (extract from extensions module?)
        image_block = ::Asciidoctor::Block.new doc, :image, content_model: :empty, attributes: logo_image_attrs
        # FIXME prevent image from spilling to next page
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
      if cover_image =~ ImageAttributeValueRx
        cover_image = resolve_image_path doc, $1
      end
      # QUESTION should we go to page 1 when position == :front?
      go_to_page page_count if position == :back
      if (::File.extname cover_image) == '.pdf'
        import_page cover_image
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
        string = %(<a anchor="#{anchor}"><color rgb="#{link_color}">#{string}</color></a>)
      else
        string = %(<a anchor="#{anchor}">#{string}</a>)
      end
    end

    # preserve leading space using non-breaking space chars
    string = preserve_indentation string if opts.delete :preserve

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
      typeset_text %(<a anchor="#{sect.id}">#{sect_title}</a>), line_metrics, inline_format: true
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

  # Reduce icon size to fit inside bounds.height. Icons will not render
  # properly if they are larger than the current bounds.height.
  def admonition_icon_size node, max_size = 24
    min_height = bounds.height.floor
    min_height < max_size ? min_height : max_size
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
    inherited_font = font_info
    family = @theme[%(#{category}_font_family)] || inherited_font[:family]

    if (level = opts[:level])
      size = @theme[%(#{category}_font_size_h#{level})] || @theme.base_font_size
    else
      size = @theme[%(#{category}_font_size)] || inherited_font[:size]
    end

    style = (@theme[%(#{category}_font_style)] || inherited_font[:style]).to_sym

    if level
      color = @theme[%(#{category}_font_color_h#{level})] || @theme[%(#{category}_font_color)]
    else
      color = @theme[%(#{category}_font_color)]
    end

    prev_color, @font_color = @font_color, color if color
    font family, size: size, style: style do
      yield
    end
    @font_color = prev_color if color
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

  def preserve_indentation string
    string.gsub(IndentationRx) { NoBreakSpace * $&.length }
  end

  # QUESTION is this method still necessary?
  def resolve_imagesdir doc
    @imagesdir ||= begin
      imagesdir = (doc.attr 'imagesdir', '.').chomp '/'
      imagesdir = imagesdir == '.' ? nil : %(#{imagesdir}/)
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
  # When a temporary file is used, the file descriptor is assigned to the
  # @tmp_file instance variable of the return string.
  def resolve_image_path node, image_path = nil, image_type = nil
    imagesdir = resolve_imagesdir(doc = node.document)
    image_path ||= (node.attr 'target', nil, false)
    image_type ||= (::File.extname image_path)[1..-1]
    # handle case when image is a URI
    if (node.is_uri? image_path) || (imagesdir && (node.is_uri? imagesdir) &&
        (image_path = (node.normalize_web_path image_path, image_base_uri, false)))
      unless doc.attr? 'allow-uri-read'
        warn %(asciidoctor: WARNING: allow-uri-read is not enabled; cannot embed remote image: #{image_path})
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
        tmp_image_path.instance_variable_set :@tmp_file, tmp_image
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

  # QUESTION is there a better way to do this?
  # I suppose we could have @tmp_files as an instance variable on converter instead
  def unlink_tmp_file holder
    if (tmp_file = (holder.instance_variable_get :@tmp_file))
      tmp_file.unlink
      holder.remove_instance_variable :@tmp_file
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
