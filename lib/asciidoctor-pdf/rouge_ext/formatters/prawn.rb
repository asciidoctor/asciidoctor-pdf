module Rouge
module Formatters
# Transforms a token stream into an array of
# formatted text fragments for use with Prawn.
class Prawn < Formatter
  tag 'prawn'

  Tokens = ::Rouge::Token::Tokens
  LineOrientedTokens = [
    ::Rouge::Token::Tokens::Generic::Inserted,
    ::Rouge::Token::Tokens::Generic::Deleted,
    ::Rouge::Token::Tokens::Generic::Heading,
    ::Rouge::Token::Tokens::Generic::Subheading
  ]

  LF = ?\n
  NoBreakSpace = ?\u00a0
  InnerIndent = %(#{LF} )
  GuardedIndent = NoBreakSpace
  GuardedInnerIndent = %(#{LF}#{NoBreakSpace})
  BoldStyle = [:bold].to_set
  ItalicStyle = [:italic].to_set
  BoldItalicStyle = [:bold, :italic].to_set
  UnderlineStyle = [:underline].to_set

  def initialize opts = {}
    unless ::Rouge::Theme === (theme = opts[:theme])
      unless theme && (theme = ::Rouge::Theme.find theme)
        theme = ::Rouge::Themes::AsciidoctorPDFDefault
      end
      theme = theme.new
    end
    @theme = theme
    @normalized_colors = {}
    @background_colorizer = BackgroundColorizer.new line_gap: opts[:line_gap]
    @linenum_fragment_base = (create_fragment Tokens::Generic::Lineno).merge linenum: true
  end

  def background_color
    @background_color ||= normalize_color((@theme.style_for Tokens::Text).bg)
  end

  # Override format method so fragments don't get flatted to a string
  # and to add an options Hash.
  def format tokens, opts = {}
    stream tokens, opts
  end

  def stream tokens, opts = {}
    if opts[:line_numbers]
      if (linenum = opts[:start_line]) > 0
        linenum -= 1
      else
        linenum = 0
      end
      fragments = []
      fragments << (create_linenum_fragment linenum += 1)
      tokens.each do |tok, val|
        if val == LF
          fragments << { text: LF }
          fragments << (create_linenum_fragment linenum += 1)
        elsif val.include? LF
          # NOTE we assume if the fragment ends in a line feed, the intention was to match a line-oriented form
          line_oriented = val.end_with? LF
          base_fragment = create_fragment tok, val
          val.each_line do |line|
            fragments << (line_oriented ? (base_fragment.merge text: line, line_oriented: true) : (base_fragment.merge text: line))
            # NOTE append linenum fragment if there's a next line; only works if source doesn't have trailing endline
            fragments << (create_linenum_fragment linenum += 1) if line.end_with? LF
          end
        else
          fragments << (create_fragment tok, val)
        end
      end
      # NOTE drop orphaned linenum fragment (due to trailing endline in source)
      fragments.pop if (last_fragment = fragments[-1]) && last_fragment[:linenum]
      # NOTE pad numbers that have less digits than the largest line number
      if (linenum_w = linenum.to_s.length) > 1
        # NOTE extra column is the trailing space after the line number
        linenum_w += 1
        fragments.each do |fragment|
          fragment[:text] = %(#{fragment[:text].rjust linenum_w, NoBreakSpace}) if fragment[:linenum]
        end
      end
      fragments
    else
      start_of_line = true
      tokens.map do |tok, val|
        # match one or more consecutive endlines
        if val == LF || (val == (LF * val.length))
          start_of_line = true
          { text: val }
        else
          val[0] = GuardedIndent if start_of_line && (val.start_with? ' ')
          val.gsub! InnerIndent, GuardedInnerIndent if val.include? InnerIndent
          # QUESTION do we need the call to create_fragment if val contains only spaces? consider bg
          #fragment = create_fragment tok, val
          fragment = val.rstrip.empty? ? { text: val } : (create_fragment tok, val)
          # NOTE we assume if the fragment ends in a line feed, the intention was to match a line-oriented form
          fragment[:line_oriented] = true if (start_of_line = val.end_with? LF)
          fragment
        end
      end
      # QUESTION should we strip trailing newline?
    end
  end

  # TODO method could still be optimized (for instance, check if val is LF or empty)
  def create_fragment tok, val = nil
    fragment = val ? { text: val } : {}
    if (style_rules = @theme.style_for tok)
      if (bg = normalize_color style_rules.bg) && bg != @background_color
        fragment[:background_color] = bg
        fragment[:callback] = @background_colorizer
        if LineOrientedTokens.include? tok
          fragment[:inline_block] = true unless style_rules[:inline_block] == false
          fragment[:extend] = true unless style_rules[:extend] == false
        else
          fragment[:inline_block] = true if style_rules[:inline_block]
          fragment[:extend] = true if style_rules[:extend]
        end
      end
      if (fg = normalize_color style_rules.fg)
        fragment[:color] = fg
      end
      if style_rules[:bold]
        fragment[:styles] = style_rules[:italic] ? BoldItalicStyle.dup : BoldStyle.dup
      elsif style_rules[:italic]
        fragment[:styles] = ItalicStyle.dup
      end
      if style_rules[:underline]
        if fragment.key? :styles
          fragment[:styles] << UnderlineStyle[0]
        else
          fragment[:styles] = UnderlineStyle.dup
        end
      end
    end
    fragment
  end

  def create_linenum_fragment linenum
    @linenum_fragment_base.merge text: %(#{linenum} )
  end

  def normalize_color raw
    return unless raw
    if (normalized = @normalized_colors[raw])
      normalized
    else
      normalized = (raw.start_with? '#') ? raw[1..-1] : raw
      normalized = normalized.each_char.map {|c| c * 2 }.join if normalized.length == 3
      @normalized_colors[raw] = normalized
    end
  end
end

class BackgroundColorizer
  def initialize opts = {}
    @line_gap = opts[:line_gap] || 0
  end

  def render_behind fragment
    pdf = fragment.document
    data = fragment.format_state
    prev_fill_color = pdf.fill_color
    pdf.fill_color data[:background_color]
    v_gap = data[:inline_block] ? @line_gap : 0
    fragment_width = data[:line_oriented] && data[:extend] ? (pdf.bounds.width - fragment.left) : fragment.width
    pdf.fill_rectangle [fragment.left, fragment.top + v_gap * 0.5], fragment_width, (fragment.height + v_gap)
    pdf.fill_color prev_fill_color
  end
end
end
end
