require 'prawn'
require 'prawn-svg'
require 'asciidoctor/prawn'
require 'asciidoctor/ext/section'
require 'roman_numeral'

Prawn::Document.extensions << Asciidoctor::Prawn::Extensions

module Asciidoctor
class PDFRenderer < ::Prawn::Document
  include ::Prawn::Measurements

  def self.unicode_char number
    [number].pack 'U*'
  end

  FONTS_DIR = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', 'data', 'fonts'))

  IndentationPattern = /^ +/
  TabSpaces = ' ' * 4
  NonBreakingSpace = unicode_char 0x00a0
  EmDash = unicode_char 0x2014
  LowercaseGreekA = unicode_char 0x03b1
  Bullets = {
    disc: (unicode_char 0x2022),
    circle: (unicode_char 0x25e6),
    square: (unicode_char 0x25aa)
  }
  BuiltInCharEntities = {
    '&lt;' => '<',
    '&gt;' => '>',
    '&amp;' => '&'
  }
  BuiltInCharEntitiesPattern = /(?:#{BuiltInCharEntities.keys * '|'})/
  AdmonitionIcons = {
    note: (unicode_char 0xf0eb)
  }

  def self.render doc, output_filename, theme, options = {}
    options = build_document_options doc, theme, options
    generate output_filename, options do
      @theme = theme
      @output_filename = output_filename
      register_fonts
      init_scratch_prototype
      @font_color = @theme.base_font_color
      render_document_node doc
      #@prototype.render_file 'scratch.pdf'
      generate_pdfmarks_file doc
    end
  end

  def font_path font_file
    ::File.join FONTS_DIR, font_file
  end

  def register_fonts
    # FIXME read from theme
    register_font LiberationSans: {
      normal: (font_path 'liberation_sans-normal.ttf'),
      bold: (font_path 'liberation_sans-bold.ttf'),
      italic: (font_path 'liberation_sans-italic.ttf'),
      bold_italic: (font_path 'liberation_sans-bold_italic.ttf')
    }

    register_font LiberationMono: {
      normal: (font_path 'liberation_mono-normal.ttf'),
      bold: (font_path 'liberation_mono-bold.ttf'),
      italic: (font_path 'liberation_mono-italic.ttf'),
      bold_italic: (font_path 'liberation_mono-bold_italic.ttf')
    }

    #register_font FontAwesome: {
    #  normal: (font_path 'fontawesome-webfont.ttf')
    #}

    #@fallback_fonts ||= []
    #@fallback_fonts << 'LiberationSans'
    default_kerning true
  end

  def render_node node
    if node.is_a? ::Asciidoctor::AbstractBlock
      context = node.context
      node.document.playback_attributes node.attributes unless context == :document
      dispatch = %(render_#{context}_node).to_sym

      if respond_to? dispatch
        send dispatch, node
      else
        render_fallback node
      end
    end
  end

  def render_children node
    node.blocks.each {|child| render_node child } if node.blocks?
  end

  def render_section_content section
    render_children section
  end

  # TODO honor content model
  def render_node_content node
    if node.blocks?
      render_children node
    elsif (string = node.content)
      prose string
    end
  end

  def render_list_item_content node
    prose node.text if node.text?
    render_children node
  end

  def render_fallback node
    puts "Unhandled node: #{node}"
  end

  def theme_fill_and_stroke_bounds category
    fill_and_stroke_bounds @theme[%(#{category}_background_color)], @theme[%(#{category}_border_color)], {
      line_width: @theme[%(#{category}_border_width)],
      radius: @theme[%(#{category}_border_radius)]
    }
  end

  def theme_font category, options = {}
    # QUESTION should we fallback to base_font_* or just leave current setting?
    family = @theme[%(#{category}_font_family)] || @theme.base_font_family
    if (level = options[:level])
      size = @theme[%(#{category}_font_size_h#{level})] || @theme.base_font_size
    else
      size = @theme[%(#{category}_font_size)] || @theme.base_font_size
    end
    style = (@theme[%(#{category}_font_style)] || :normal).to_sym
    prev_font_color = @font_color
    @font_color = @theme[%(#{category}_font_color)] || prev_font_color
    font family, size: size, style: style do
      yield
    end
    @font_color = prev_font_color
  end

  def render_document_node doc
    if (bg_color = @theme.page_background_color) && !(['transparent', 'FFFFFF'].include? bg_color.to_s)
      on_page_create do
        canvas do
          fill_bounds bg_color
        end
      end
    end

    render_title_page doc

    @list_numbers = []
    @list_bullets = []

    start_new_page
    font @theme.base_font_family, size: @theme.base_font_size
    render_children doc

    num_toc_levels = (doc.attr 'toclevels', 2).to_i
    toc_page_nums = if doc.attr? 'toc'
      add_toc doc, num_toc_levels
    else
      (0..-1)
    end

    add_page_numbers skip: (toc_page_nums.to_a.size + 1)

    add_outline doc, num_toc_levels, toc_page_nums
    catalog.data[:ViewerPreferences] = [:FitWindow]
  end

  def render_title_page doc
    start_new_page

    if doc.attr? 'title-logo'
      move_down @theme.vertical_rhythm * 2
      image_node = ::Asciidoctor::Block.new doc, :image, content_model: :empty
      attrs = { 'target' => (doc.attr 'title-logo'), 'align' => 'center' }
      image_node.update_attributes attrs
      render_image_node image_node
      move_down @theme.vertical_rhythm * 4
    end

    # only create title page if doctype=book!
    theme_font :heading, level: 1 do
      heading doc.doctitle, align: :center
    end
    move_down @theme.vertical_rhythm
    if doc.attr? 'authors'
      prose doc.attr('authors'), align: :center, margin_bottom: @theme.vertical_rhythm / 2
    end
    prose [(doc.attr? 'revnumber') ? %(#{doc.attr 'version-label'} #{doc.attr 'revnumber'}) : nil, (doc.attr 'revdate')].compact * "\n", align: :center, margin_top: @theme.vertical_rhythm * 5, normalize: false
  end

  # TODO start new page if chapter
  def render_section_node section
    theme_font :heading, level: (section.level + 1) do
      sect_title = section.numbered_title formal: true
      unless at_page_top?
        if section.chapter?
          start_new_page
        # FIXME someone hackish...need to sort out a cleaner approach here
        elsif cursor < (height_of sect_title) + @theme.heading_margin_top + @theme.heading_margin_bottom + @theme.base_line_height_length * 1.5
          start_new_page
        end
      end
      section.set_attr 'page_start', page_number
      section.set_attr 'destination', (sect_destination = (dest_xyz 0, section.level == 0 ? page_height : y))
      add_dest section.id, sect_destination
      heading sect_title
    end

    render_section_content section
    section.set_attr 'page_end', page_number
  end

  def render_floating_title_node node
    theme_font :heading, level: (node.level + 1) do
      heading node.title
    end
  end

  def render_paragraph_node node
    prose node.content
  end

  def prose string, options = {}
    margin_top = (margin = (options.delete :margin)) || (options.delete :margin_top) || 0
    margin_bottom = margin || (options.delete :margin_bottom) || @theme.vertical_rhythm
    if (anchor = options.delete :anchor)
      # FIXME won't work if inline_format is true; should instead pass through as attribute w/ link color set
      string = %(<link anchor="#{anchor}">#{string}</link>)
    end
    move_down margin_top
    typeset_text string, calc_line_metrics((options.delete :line_height) || @theme.base_line_height), {
      color: @font_color,
      inline_format: [{normalize: (options.delete :normalize) != false}],
      align: (@theme.base_align || :justify).to_sym
    }.merge(options)
    move_down margin_bottom
  end

  def pre string, options = {}
    string = string.gsub(IndentationPattern) { NonBreakingSpace * $&.length }
    prose string, { normalize: false, align: :left }.merge(options)
  end

  # QUESTION why doesn't heading set the font??
  def heading string, options = {}
    margin_top = options[:margin] || options[:margin_top] || @theme.heading_margin_top
    margin_bottom = options[:margin] || options[:margin_bottom] || @theme.heading_margin_bottom
    line_height = options[:line_height] || @theme.heading_line_height
    move_down margin_top
    typeset_text string, (calc_line_metrics line_height), { color: @font_color, inline_format: true }.merge(options)
    move_down margin_bottom
  end

  # Render the caption and return the height of the rendered content
  def caption subject, options = {}
    mark = { cursor: cursor, page_number: page_number }
    string = case subject
    when ::String
      subject
    when ::Asciidoctor::AbstractBlock
      subject.title? ? subject.captioned_title : nil
    end
    return 0 if string.nil?
    theme_font :caption do
      margin = if ((options.delete :position) || :top) == :top
        { top: @theme.caption_margin_outside, bottom: @theme.caption_margin_inside }
      else
        { top: @theme.caption_margin_inside, bottom: @theme.caption_margin_outside }
      end
      prose string, {
        margin_top: margin[:top],
        margin_bottom: margin[:bottom],
        align: (@theme.caption_align || :left).to_sym,
        normalize: false
      }.merge(options)
    end
    # NOTE we assume we don't clear more than one page
    if page_number > mark[:page_number]
      mark[:cursor] + (bounds.top - cursor)
    else
      mark[:cursor] - cursor
    end
  end

  def typeset_text string, line_metrics, options = {}
    move_down line_metrics.shift
    text string, { leading: line_metrics.leading, final_gap: line_metrics.final_gap }.merge(options)
    move_up line_metrics.shift
  end

  # QUESTION combine with typeset_text?
  def typeset_formatted_text fragments, line_metrics, options = {}
    move_down line_metrics.shift
    formatted_text fragments, { leading: line_metrics.leading, final_gap: line_metrics.final_gap }.merge(options)
    move_up line_metrics.shift
  end

  def height_of_typeset_text string, options = {}
    line_metrics = (calc_line_metrics options[:line_height] || @theme.base_line_height)
    height_of string, leading: line_metrics.leading, final_gap: line_metrics.final_gap
  end

  def prepare_verbatim string
    string.gsub(BuiltInCharEntitiesPattern, BuiltInCharEntities)
        .gsub(IndentationPattern) { NonBreakingSpace * $&.length }
  end

  def unescape string
    string.gsub BuiltInCharEntitiesPattern, BuiltInCharEntities
  end

  # Remove all HTML tags and resolve all entities in a string
  #
  def sanitize string
    string.gsub(/<[^>]+>/, '').gsub(/&#(\d{2,4});/) { [$1.to_i].pack('U*') }.tr_s(' ', ' ').strip
  end

  def TODO_create_stamps
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

=begin
  def render_document_title title, authors = nil
    start_new_page if page_count == 0

    if title.include? ': '
      title, subtitle = title.split ': ', 2
    else
      subtitle = nil
    end

    move_down 18
    font @theme.TitleFontFamily, size: @theme.TitleFontSize, style: @theme.TitleFontStyle do
      text title, align: @theme.TitleAlign, color: @theme.TitleFontColor
    end

    if subtitle
      move_down 14
      font @theme.SubtitleFontFamily, size: @theme.SubtitleFontSize, style: @theme.SubtitleFontStyle do
        text subtitle, align: @theme.SubtitleAlign, color: @theme.SubtitleFontColor
      end
    end

    if authors
      move_down 18
      font @theme.BylineFontFamily, size: @theme.BylineFontSize, style: @theme.BylineFontStyle do
        text authors, align: @theme.BylineAlign, color: @theme.BylineFontColor
      end
    end

    start_new_page
  end
=end

  def render_open_node node
    case node.style
    when 'abstract'
      render_abstract_node node
    when 'partintro'
      if node.blocks.size == 1 && node.blocks.first.style == 'abstract'
        render_abstract_node node.blocks.first
      else
        render_children node
      end
    else
      render_children node
    end
  end

  def render_preamble_node node
    # emulate lead paragraph
    # may want to do this in paragraph and check for explicit 'lead' role
    font_size @theme.lead_font_size do
      render_children node
    end
  end

  def render_abstract_node node
    theme_font :abstract do
      render_node_content node
    end
    move_down @theme.vertical_rhythm
  end

  def render_admonition_node node
    # perfect case where we need to be able to merge margins (record size of last skipped space)
    move_down @theme.vertical_rhythm unless cursor == bounds.absolute_top
    keep_together do |box_height = nil|
      #theme_font :admonition do
        label = node.caption.upcase
        label_width = width_of label
        indent @theme.horizontal_rhythm, @theme.horizontal_rhythm do
          if box_height
            float do
              bounding_box [0, cursor], width: label_width + @theme.horizontal_rhythm, height: box_height do
                line_metrics = calc_line_metrics @theme.base_line_height
                formatted_text_box [text: label],
                    at: [0, cursor - line_metrics.shift],
                    style: :bold,
                    valign: :center,
                    leading: line_metrics.leading,
                    final_gap: line_metrics.final_gap
                stroke_vertical_rule @theme.admonition_border_color, at: bounds.width
              end
            end
          end
          indent label_width + @theme.horizontal_rhythm * 2 do
            #caption node
            if node.title?
              caption node.title
              # minor hack to make title in this location look right
              #move_up @theme.caption_margin_inside
            end
            render_node_content node
            move_up @theme.vertical_rhythm
          end
        end
      #end
    end
    move_down @theme.vertical_rhythm * 2
  end

  def render_sidebar_node node
    keep_together do |box_height = nil|
      if box_height
        float do
          bounding_box [0, cursor], width: bounds.width, height: box_height do
            theme_fill_and_stroke_bounds :sidebar
          end
        end
      end
      move_down @theme.vertical_rhythm * 1.5
      indent @theme.horizontal_rhythm, @theme.horizontal_rhythm do
        if node.title?
          theme_font :sidebar_title do
            heading node.title, margin: 0, align: @theme.sidebar_title_align.to_sym
          end
          move_down @theme.vertical_rhythm
        end
        theme_font :sidebar do
          render_node_content node
        end
        move_down @theme.vertical_rhythm / 2
      end
    end
    move_down @theme.vertical_rhythm * 2
  end

  def render_example_node node
    keep_together do |box_height = nil|
      caption_height = caption node
      if box_height
        float do
          bounding_box [0, cursor], width: bounds.width, height: box_height - caption_height do
            theme_fill_and_stroke_bounds :example
          end
        end
      end
      pad_box [@theme.vertical_rhythm, @theme.horizontal_rhythm, 0, @theme.horizontal_rhythm] do
        theme_font :example do
          render_node_content node
        end
      end
    end
    move_down @theme.vertical_rhythm * 2
  end

  def render_quote_node node
    render_quote_or_verse node
  end

  def render_verse_node node
    render_quote_or_verse node
  end

  def render_quote_or_verse node
    border_width = @theme.blockquote_border_width
    keep_together do |box_height = nil|
      start_cursor = cursor
      pad_box [@theme.vertical_rhythm, @theme.horizontal_rhythm, 0, @theme.horizontal_rhythm + border_width / 2] do
        theme_font :blockquote do
          if node.context == :quote
            render_node_content node
          else
            #prose node.content, normalize: false
            pre node.content
          end
        end
        theme_font :blockquote_cite do
          if node.attr? 'attribution'
            prose %(#{EmDash} #{[(node.attr 'attribution'), (node.attr 'citetitle')].compact * ', '}), align: :left, normalize: false
          end
        end
      end
      if box_height
        # QUESTION should we use bounding_box + stroke_vertical_rule instead?
        save_graphics_state do
          stroke_color @theme.blockquote_border_color
          line_width border_width
          stroke_vertical_line cursor, start_cursor, at: border_width / 2
        end
      end
    end
    move_down @theme.vertical_rhythm * 2
  end

  def render_olist_node node
    @list_numbers ||= []
    counter = case node.style
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
      skip.times { counter = counter.next  }
    end
    @list_numbers << counter
    render_outline_list node
    @list_numbers.pop
  end

  def render_ulist_node node
    @list_bullets ||= []
    bullet_type = if node.style
      node.style.to_sym
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
    render_outline_list node
    @list_bullets.pop
  end

  def render_dlist_node node
    node.items.each do |terms, definition|
      terms = [*terms]
      # NOTE don't orphan the terms, allow for at least one line of content
      start_new_page if cursor < @theme.base_line_height_length * (terms.size + 1)
      [*terms].each do |term|
        prose term.text, style: @theme.definition_list_term_font_style.to_sym, margin: 0, align: :left
      end
      unless definition.nil?
        indent @theme.definition_list_definition_indent do
          render_list_item_content definition
        end
      end
    end
  end

  # NOTE children will provide the necessary bottom margin
  def render_outline_list node
    indent @theme.outline_list_indent do
      render_children node
    end
  end

  def render_list_item_node node
    # NOTE we need at least one line of content, so move down if we don't have it
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
        end
        prose label, align: :center, normalize: false, inline_format: false
      end
    end
    render_list_item_content node
  end

  def render_image_node node
    # FIXME use normalize_path here!
    image_path = File.join((node.attr 'docdir'), (node.attr 'imagesdir') || '', (node.attr 'target'))
    # TODO extension should be an attribute on an image node
    image_type = File.extname(image_path)[1..-1]
    width = if node.attr? 'scaledwidth'
      ((node.attr 'scaledwidth').to_f / 100.0) * bounds.width
    elsif node.attr? 'width'
      (node.attr 'width').to_f
    else
      0.75 * bounds.width # TODO make me a theme setting
    end
    height = nil
    position = ((node.attr 'align') || :left).to_sym
    case image_type
    when 'svg'
      svg IO.read(image_path), at: [0, cursor], width: width, position: position
    else
      begin
        # FIXME temporary workaround to group caption & image
        # Prawn doesn't provide access to rendered width and height before placing the
        # image on the page
        image_obj, image_info = build_image_object node.image_uri image_path
        rendered_w, rendered_h = image_info.calc_image_dimensions width: width
        caption_height = if node.title?
          @theme.caption_margin_inside + @theme.caption_margin_outside + @theme.base_line_height_length
        else
          0
        end
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
        warn %(WARNING: #{e.message})
        return
      end
    end
    caption node, position: :bottom
    move_down @theme.vertical_rhythm * 2
  end

  def render_literal_node node
    render_listing_or_literal node
  end

  def render_listing_node node
    # HACK disable built-in syntax highlighter
    if (idx = (node.subs.index :highlight))
      node.subs[idx] = :specialcharacters
    end
    render_listing_or_literal node
  end

  def render_listing_or_literal node
    source_string = prepare_verbatim node.content
    source_chunks = if node.context == :listing && (node.attr? 'language') && (node.attr? 'source-highlighter')
      case node.attr 'source-highlighter'
      when 'coderay'
        require 'asciidoctor/prawn/coderay_encoder' unless defined? ::Asciidoctor::Prawn::CodeRayEncoder
        (::CodeRay.scan source_string, (node.attr 'language', 'text').to_sym).to_prawn
      when 'pygments'
        require 'pygments.rb' unless defined? ::Pygments
        if (lexer = ::Pygments::Lexer[(node.attr 'language')])
          text_formatter.format lexer.highlight(source_string, options: { nowrap: true, noclasses: true })
        end
      end
    end
    source_chunks ||= [{ text: source_string }]

    keep_together do |box_height = nil|
      caption_height = caption node
      theme_font :code do
        if box_height
          float do
            bounding_box [0, cursor], width: bounds.width, height: box_height - caption_height do
              theme_fill_and_stroke_bounds :code
            end
          end
        end
        pad_box @theme.code_padding do
          typeset_formatted_text source_chunks, (calc_line_metrics @theme.base_line_height), color: @theme.code_font_color
        end
      end
    end
    move_down @theme.vertical_rhythm
  end

  def render_table_node node
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
          # TODO pull character_spacing from theme
          cell_data[:size] = 0.9
          cell_data[:text_color] = @theme.literal_font_color
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

    caption node

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
    move_down @theme.vertical_rhythm
  end

  def render_horizontal_rule_node node
    move_down @theme.vertical_rhythm
    stroke_horizontal_rule @theme.horizontal_rule_color
    move_down @theme.vertical_rhythm * 2
  end

  alias :render_ruler_node :render_horizontal_rule_node

  def render_page_break_node node
    start_new_page
  end

  def TODO_render_toc_node node
    node.document.attr('articles').each do |article|
      pad 14, 12 do
        font @theme.AbstractFontFamily, style: @theme.AbstractFontStyle, size: @theme.AbstractFontSize do
          write_prose article.title, color: @theme.AbstractFontColor, leading: 2, anchor: article.id
        end
      end
      font @theme.DefaultFontFamily, size: @theme.DefaultFontSize do
        write_prose %(#{article.attr('page_begin')} - #{article.attr('page_end')}), align: :right
      end
      stroke_horizontal_rule 'E6A617'
    end
    move_down @theme.VerticalRhythm
  end

  def add_toc doc, num_levels = 2, toc_page_num = 2
    go_to_page toc_page_num - 1
    start_new_page
    theme_font :heading, level: 2 do
      heading doc.attr('toc-title')
    end
    line_metrics = calc_line_metrics @theme.base_line_height
    dot_width = width_of '.'
    if num_levels > 0
      toc_level doc.sections, num_levels, line_metrics, dot_width
    end
    toc_page_nums = (toc_page_num..page_number)
    go_to_page page_count - 1
    toc_page_nums
  end

  def toc_level sections, num_levels, line_metrics, dot_width
    sections.each do |sec|
      sec_title = sec.numbered_title
      sec_page_num = (sec.attr 'page_start') - 1
      typeset_text %(<link anchor="#{sec.id}">#{sec_title}</link>), line_metrics, inline_format: true
      move_up line_metrics.height
      num_dots = ((bounds.width - (width_of %(#{sec_title} #{sec_page_num}), inline_format: true)) / dot_width).floor
      typeset_formatted_text [text: %(#{'.' * num_dots} #{sec_page_num}), anchor: sec.id], line_metrics, align: :right
      if sec.level < num_levels
        indent @theme.horizontal_rhythm do
          toc_level sec.sections, num_levels, line_metrics, dot_width
        end
      end
    end
  end

  # TODO clean me up!
  def add_page_numbers options = {}
    skip = options[:skip] || 1
    start = skip + 1
    repeat (start..page_count), dynamic: true do
      align = (page_number - skip).odd? ? :left : :right
      theme_font :footer do
        save_graphics_state do
          line_width @theme.base_border_width
          stroke_color @theme.footer_border_color
          # FIXME calculate this in a less hacky way
          stroke_horizontal_line bounds.left, bounds.right, at: -bounds.absolute_bottom + @theme.vertical_rhythm * 2.5 + @theme.footer_font_size
        end
        formatted_text_box [text: %(#{page_number - skip}), color: @theme.footer_font_color], height: @theme.footer_font_size, character_spacing: 1, align: align, at: [0, @theme.footer_font_size - bounds.absolute_bottom + @theme.vertical_rhythm * 2]
      end
    end
  end

  # FIXME we are assuming we always have exactly one title page
  def add_outline doc, num_levels = 2, toc_page_nums = (0..-1)
    front_matter_counter = RomanNumeral.new 0, :lower

    page_num_labels = {}

    # title page (i)
    page_num_labels[0] = { P: ::PDF::Core::LiteralString.new(front_matter_counter.next!.to_s) }

    # toc pages (ii..?)
    toc_page_nums.each do
      page_num_labels[front_matter_counter.to_i] = { P: ::PDF::Core::LiteralString.new(front_matter_counter.next!.to_s) }
    end

    # number of front matter pages aside from the document title to skip in page number index
    numbering_offset = front_matter_counter.to_i - 1

    outline.define do
      if (doctitle = (doc.doctitle sanitize: true))
        page title: doctitle, destination: (document.dest_top 1)
      end
      if doc.attr? 'toc'
        page title: doc.attr('toc-title'), destination: (document.dest_top toc_page_nums.first)
      end
      # QUESTION any way to get outline_level to invoke in the context of the outline?
      document.outline_level self, doc.sections, num_levels, page_num_labels, numbering_offset
    end

    catalog.data[:PageLabels] = state.store.ref Nums: page_num_labels.flatten
    catalog.data[:PageMode] = :UseOutlines
    nil
  end

  # TODO only nest inside root node if doctype=article
  def outline_level outline, sections, num_levels, page_num_labels, numbering_offset
    sections.each do |sec|
      sec_title = sanitize(sec.numbered_title formal: true)
      sec_destination = sec.attr 'destination'
      sec_page_num = (sec.attr 'page_start') - 1
      page_num_labels[sec_page_num + numbering_offset] = { P: ::PDF::Core::LiteralString.new(sec_page_num.to_s) }
      if (subsections = sec.sections).empty? || sec.level == num_levels
        outline.page title: sec_title, destination: sec_destination
      elsif sec.level < num_levels + 1
        outline.section sec_title, { destination: sec_destination } do
          outline_level outline, subsections, num_levels, page_num_labels, numbering_offset
        end
      end
    end
  end

  def generate_pdfmarks_file doc
    current_dt = ::DateTime.now.strftime '%Y%m%d%H%M%S'
    #doc_rootname = (doc.id || ::Asciidoctor::Helpers.rootname(::File.basename(doc.attr 'docfile')))
    pdfmarks_filename = %(#{::Asciidoctor::Helpers.rootname @output_filename}.pdfmarks)
    ::File.open(pdfmarks_filename, 'w') do |f|
      f.write <<-EOS
[ /Title (#{doc.doctitle sanitize: true})
  /Author (#{doc.attr 'authors'})
  /Subject (#{doc.attr 'subject'})
  /Keywords (#{doc.attr 'keywords'})
  /ModDate (D:#{current_dt})
  /CreationDate (D:#{current_dt})
  /Creator (Prawn #{::Prawn::VERSION})
  /Producer (#{doc.attr 'producer'})
  /DOCINFO pdfmark
      EOS
    end
  end

  def self.build_document_options doc, theme, options = {}
    docinfo = {}
    # NOTE split this out to control order and handle missing data
    docinfo[:Title] = ::PDF::Core::LiteralString.new((doc.doctitle sanitize: true) || 'Untitled')
    if doc.attr? 'authors'
      docinfo[:Author] = ::PDF::Core::LiteralString.new(doc.attr 'authors')
    end
    if doc.attr? 'subject'
      docinfo[:Subject] = ::PDF::Core::LiteralString.new(doc.attr 'subject')
    end
    if doc.attr? 'keywords'
      docinfo[:Keywords] = ::PDF::Core::LiteralString.new(doc.attr 'keywords')
    end
    if (doc.attr? 'producer')
      docinfo[:Producer] = ::PDF::Core::LiteralString.new(doc.attr 'producer')
    end
    docinfo[:Creator] = ::PDF::Core::LiteralString.new(%(Prawn #{::Prawn::VERSION}))
    docinfo[:Producer] ||= docinfo[:Author] || docinfo[:Creator]
    docinfo[:ModDate] = docinfo[:CreationDate] = ::Time.now

    options = {
      margin: (theme.page_margin || 36),
      page_size: (theme.page_size || 'LETTER').upcase,
      page_layout: (theme.page_layout || :portrait).to_sym,
      #compress: true,
      #optimize_objects: true,
      info: docinfo
    }.merge(options)
    
    options[:skip_page_creation] = true
    options[:text_formatter] ||= ::Asciidoctor::Prawn::FormattedTextFormatter.new theme: theme
    options
  end

  # QUESTION move to prawn/extensions.rb?
  def init_scratch_prototype
    # don't set font before using Marshal, it causes serialization to fail
    @prototype = ::Marshal.load ::Marshal.dump self
    @prototype.state.store.info.data[:Scratch] = true
    # we're now starting a new page each time, so no need to do it here
    #@prototype.start_new_page if @prototype.page_number == 0
  end
end
end
