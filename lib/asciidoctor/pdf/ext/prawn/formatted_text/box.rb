# frozen_string_literal: true

Prawn::Text::Formatted::Box.prepend (Module.new do
  include Asciidoctor::Logging

  def initialize formatted_text, options = {}
    if (color = options[:color]) && !formatted_text.empty?
      formatted_text = formatted_text.map {|fragment| fragment[:color] ? fragment : (fragment.merge color: color) }
    end
    super
    formatted_text[0][:normalize_line_height] = true if options[:normalize_line_height] && !formatted_text.empty?
    options[:extensions]&.each {|extension| extend extension }
    extend Prawn::Text::Formatted::IndentedParagraphWrap if (@indent_paragraphs = options[:indent_paragraphs])
    if (bottom_gutter = options[:bottom_gutter]) && bottom_gutter > 0
      @bottom_gutter = bottom_gutter
      extend Prawn::Text::Formatted::ProtectBottomGutter
    end
    @force_justify = options[:force_justify]
  end

  def draw_fragment_overlay_styles fragment
    if (underline = (styles = fragment.styles).include? :underline) || (styles.include? :strikethrough)
      (doc = fragment.document).save_graphics_state do
        if (text_decoration_width = (fs = fragment.format_state)[:text_decoration_width] || doc.text_decoration_width)
          doc.line_width = text_decoration_width
        end
        if (text_decoration_color = fs[:text_decoration_color])
          doc.stroke_color = text_decoration_color
        end
        underline ? (doc.stroke_line fragment.underline_points) : (doc.stroke_line fragment.strikethrough_points)
      end
    end
  end

  # TODO: remove when upgrading to prawn-2.5.0
  def analyze_glyphs_for_fallback_font_support fragment_hash
    fragment_font = fragment_hash[:font] || (original_font = @document.font.family)
    if (fragment_font_styles = fragment_hash[:styles])
      if fragment_font_styles.include? :bold
        fragment_font_opts = { style: (fragment_font_styles.include? :italic) ? :bold_italic : :bold }
      elsif fragment_font_styles.include? :italic
        fragment_font_opts = { style: :italic }
      end
    end
    fallback_fonts = @fallback_fonts.dup
    font_glyph_pairs = []
    @document.save_font do
      fragment_hash[:text].each_char do |char|
        font_glyph_pairs << [(find_font_for_this_glyph char, fragment_font, fragment_font_opts || {}, fallback_fonts.dup), char]
      end
    end
    # NOTE: don't add a :font to fragment if it wasn't there originally
    font_glyph_pairs.each {|pair| pair[0] = nil if pair[0] == original_font } if original_font
    form_fragments_from_like_font_glyph_pairs font_glyph_pairs, fragment_hash
  end

  # TODO: remove once Prawn 2.5 is released
  def find_font_for_this_glyph char, current_font, current_font_opts = {}, fallback_fonts_to_check = [], original_font = current_font
    (doc = @document).font current_font, current_font_opts
    if doc.font.glyph_present? char
      current_font
    elsif fallback_fonts_to_check.empty?
      if logger.info? && !doc.scratch?
        fonts_checked = @fallback_fonts.dup.unshift original_font
        missing_chars = (doc.instance_variable_defined? :@missing_chars) ?
            (doc.instance_variable_get :@missing_chars) : (doc.instance_variable_set :@missing_chars, {})
        previous_fonts_checked = (missing_chars[char] ||= [])
        if previous_fonts_checked.empty? && !(previous_fonts_checked.include? fonts_checked)
          logger.warn %(Could not locate the character `#{char}' (#{char.unpack('U*').map {|it| "\\u#{(it.to_s 16).rjust 4, '0'}" }.join}) in the following fonts: #{fonts_checked.join ', '})
          previous_fonts_checked << fonts_checked
        end
      end
      original_font
    else
      find_font_for_this_glyph char, fallback_fonts_to_check.shift, current_font_opts, fallback_fonts_to_check, original_font
    end
  end

  # Override method to force text justification when :force_justify option is set (typically for rendering a single line)
  def word_spacing_for_this_line
    if @align == :justify && (@force_justify || (@line_wrap.space_count > 0 && !@line_wrap.paragraph_finished?))
      (available_width - @line_wrap.width) / @line_wrap.space_count
    else
      0
    end
  end

  # Override method in super class to provide support for a tuple consisting of alignment and offset
  def process_vertical_alignment text
    return super if Symbol === (valign = @vertical_align)

    return if defined? @vertical_alignment_processed
    @vertical_alignment_processed = true

    valign, offset = valign

    case valign
    when :center
      wrap text
      @at[1] -= (@height - (rendered_height = height) + @descender) * 0.5 + offset
      @height = rendered_height
    when :bottom
      wrap text
      @at[1] -= (@height - (rendered_height = height)) + offset
      @height = rendered_height
    else # :top
      @at[1] -= offset
    end

    nil
  end
end)
