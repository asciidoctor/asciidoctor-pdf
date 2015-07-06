module Rouge
module Formatters
# Transforms a token stream into an array of 
# formatted text fragments for use with Prawn.
class Prawn < Formatter
  tag 'prawn'

  EOL = %(\n)
  NoBreakSpace = %(\u00a0)
  InnerIndent = %(\n )
  GuardedIndent = %(\u00a0)
  GuardedInnerIndent = %(\n\u00a0)
  BoldStyle = [:bold].to_set
  ItalicStyle = [:italic].to_set
  BoldItalicStyle = [:bold, :italic].to_set

  def initialize opts = {}
    unless ::Rouge::Theme === (theme = opts[:theme])
      unless theme && (theme = ::Rouge::Theme.find theme)
        theme = ::Rouge::Themes::Pastie
      end
      theme = theme.new
    end
    @theme = theme
    @normalized_colors = {}
    @linenum_fragment_base = (create_fragment Token['Generic.Lineno']).merge linenum: true
  end

  # Override format method so fragments don't get flatted to a string
  # and to add an options Hash.
  def format tokens, opts = {}
    stream tokens, opts
  end

  def stream tokens, opts = {}
    if opts[:line_numbers]
      # TODO implement line number start (offset)
      linenum = 0
      fragments = []
      fragments << (create_linenum_fragment linenum += 1)
      tokens.each do |tok, val|
        if val == EOL
          fragments << { text: EOL }
          fragments << (create_linenum_fragment linenum += 1)
        elsif val.include? EOL
          base_fragment = create_fragment tok, val
          val.each_line do |line|
            fragments << (base_fragment.merge text: line)
            # NOTE append linenum fragment if there's a next line; only works if source doesn't have trailing endline
            if line.end_with? EOL
              fragments << (create_linenum_fragment linenum += 1)
            end
          end
        else
          fragments << (create_fragment tok, val)
        end
      end
      # NOTE drop orphaned linenum fragment (due to trailing endline in source)
      fragments.pop if (last_fragment = fragments[-1]) && last_fragment[:linenum]
      # NOTE pad numbers that have less digits than the largest line number
      if (linenum_w = (linenum / 10) + 1) > 1
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
        if val == EOL || (val == (EOL * val.length))
          start_of_line = true
          { text: val }
        else
          val[0] = GuardedIndent if start_of_line && (val.start_with? ' ')
          val.gsub! InnerIndent, GuardedInnerIndent if val.include? InnerIndent
          start_of_line = val.end_with? EOL
          # NOTE this optimization assumes we don't support/use background colors
          val.rstrip.empty? ? { text: val } : (create_fragment tok, val)
        end
      end
      # QUESTION should we strip trailing newline?
    end
  end

  # TODO method could still be optimized (for instance, check if val is EOL or empty)
  def create_fragment tok, val = nil
    fragment = val ? { text: val } : {}
    if (style_rules = @theme.style_for tok)
      # TODO support background color
      if (fg = normalize_color style_rules.fg)
        fragment[:color] = fg
      end
      if style_rules[:bold]
        fragment[:styles] = style_rules[:italic] ? BoldItalicStyle : BoldStyle
      elsif style_rules[:italic]
        fragment[:styles] = ItalicStyle
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
      normalized = normalized.each_char.map {|c| c * 2 }.join if normalized.size == 3
      @normalized_colors[raw] = normalized
    end
  end
end
end
end
