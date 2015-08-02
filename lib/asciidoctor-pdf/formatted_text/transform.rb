module Asciidoctor
module Pdf
module FormattedText
class Transform
  EOL = "\n"
  NamedEntityTable = {
    :lt => '<',
    :gt => '>',
    :amp => '&',
    :quot => '"',
    :apos => '\''
  }
  #ZeroWidthSpace = %(\u200b)

  def initialize(options = {})
    @merge_adjacent_text_nodes = options[:merge_adjacent_text_nodes]
    if (theme = options[:theme])
      @link_font_color = theme.link_font_color
      @monospaced_font_color = theme.literal_font_color
      @monospaced_font_family = theme.literal_font_family
      @monospaced_font_size = theme.literal_font_size
      case theme.literal_font_style
      when 'bold'
        @monospaced_font_style = [:bold]
      when 'italic'
        @monospaced_font_style = [:italic]
      when 'bold_italic'
        @monospaced_font_style = [:bold, :italic]
      else
        @monospaced_font_style = nil
      end
      #@monospaced_letter_spacing = theme.literal_letter_spacing
    else
      @link_font_color = '0000FF'
      @monospaced_font_color = nil
      @monospaced_font_family = 'Courier'
      @monospaced_font_size = 0.9
      @monospaced_font_style = nil
      #@monospaced_letter_spacing = -0.1
    end
  end

  # FIXME pass styles downwards to child elements rather than decorating on way out of hierarchy
  def apply(parsed)
    fragments = []
    previous_fragment_is_text = false
    # NOTE we use each since using inject is slower than a manual loop
    parsed.each do |node|
      case node[:type]
      when :element
        # case 1: non-void element
        if (pcdata = node[:pcdata])
          if pcdata.size > 0
            tag_name = node[:name]
            attributes = node[:attributes]
            fragments << apply(pcdata).map do |fragment|
              # decorate child fragments with styles from this element
              build_fragment(fragment, tag_name, attributes)
            end
            previous_fragment_is_text = false
          # NOTE skip element if it has no children
          #else
          #  # NOTE handle an empty anchor element (i.e., <a ...></a>)
          #  if (tag_name = node[:name]) == :a
          #    fragments << build_fragment({ text: ZeroWidthSpace }, tag_name, node[:attributes])
          #    previous_fragment_is_text = false
          #  end
          end
        # case 2: void element
        else
          case node[:name]
          when :br
            if @merge_adjacent_text_nodes && previous_fragment_is_text
              fragments << { text: %(#{fragments.pop[:text]}#{EOL}) }
            else
              fragments << { text: EOL }
            end
            previous_fragment_is_text = true
          when :img
            attributes = node[:attributes]
            fragment = {
              image_path: attributes[:src],
              image_type: attributes[:type],
              image_tmp: (attributes[:tmp] == 'true'),
              text: attributes[:alt],
              callback: InlineImageRenderer
            }
            if (img_w = attributes[:width])
              fragment[:image_width] = img_w.to_f
            end
            fragments << fragment
            previous_fragment_is_text = false
          end
        end
      when :text
        text = node[:value]
        # NOTE the remaining logic is shared with :entity
        if @merge_adjacent_text_nodes && previous_fragment_is_text
          fragments << { text: %(#{fragments.pop[:text]}#{text}) }
        else
          fragments << { text: text }
        end
        previous_fragment_is_text = true
      when :entity
        if (name = node[:name])
          text = NamedEntityTable[name]
        else
          # FIXME AFM fonts do not include a thin space glyph; set fallback_fonts to allow glyph to be resolved
          text = [node[:number]].pack('U*')
        end
        # NOTE the remaining logic is shared with :text
        if @merge_adjacent_text_nodes && previous_fragment_is_text
          fragments << { text: %(#{fragments.pop[:text]}#{text}) }
        else
          fragments << { text: text }
        end
        previous_fragment_is_text = true
      end
    end
    fragments.flatten
  end

  def build_fragment(fragment, tag_name, attrs = {})
    styles = (fragment[:styles] ||= ::Set.new)
    case tag_name
    when :strong
      styles << :bold
    when :em
      styles << :italic
    when :code
      fragment[:font] ||= @monospaced_font_family
      if @monospaced_font_size
        fragment[:size] ||= @monospaced_font_size
      end
      #if @monospaced_letter_spacing
      #  fragment[:character_spacing] ||= @monospaced_letter_spacing
      #end
      if @monospaced_font_color
        fragment[:color] ||= @monospaced_font_color
      end
      if @monospaced_font_style
        styles.merge @monospaced_font_style
      end
    when :color
      if !fragment[:color]
        if (rgb = attrs[:rgb])
          case rgb.chr
          when '#'
            fragment[:color] = rgb[1..-1]
          when '['
            # treat value as CMYK array (e.g., "[50, 100, 0, 0]")
            fragment[:color] = rgb[1..-1].chomp(']').split(', ').map(&:to_i)
            # ...or we could honor an rgb array too
            #case (vals = rgb[1..-1].chomp(']').split(', ')).size
            #when 4
            #  fragment[:color] = vals.map(&:to_i)
            #when 3
            #  fragment[:color] = vals.map {|e| '%02X' % e.to_i }.join
            #end
          else
            fragment[:color] = rgb
          end
        # QUESTION should we even support r,g,b and c,m,y,k as individual values?
        elsif (r = attrs[:r]) && (g = attrs[:g]) && (b = attrs[:b])
          fragment[:color] = [r, g, b].map {|e| '%02X' % e.to_i }.join
        elsif (c = attrs[:c]) && (m = attrs[:m]) && (y = attrs[:y]) && (k = attrs[:k])
          fragment[:color] = [c.to_i, m.to_i, y.to_i, k.to_i]
        end
      end
    when :font
      if !fragment[:font] && (value = attrs[:name])
        fragment[:font] = value
      end
      if !fragment[:size] && (value = attrs[:size])
        # FIXME can we make this comparison more robust / accurate?
        if %(#{f_value = value.to_f}) == value || %(#{value.to_i}) == value
          fragment[:size] = f_value
        elsif value != '1em'
          fragment[:size] = value
        end
      end
      #if !fragment[:character_spacing] && (value = attrs[:character_spacing])
      #  fragment[:character_spacing] = value.to_f
      #end
    when :a
      if !fragment[:anchor] && (value = attrs[:anchor])
        fragment[:anchor] = value
      end
      if !fragment[:link] && (value = attrs[:href])
        fragment[:link] = value
      end
      #if !fragment[:local] && (value = attrs[:local])
      #  fragment[:local] = value
      #end
      if !fragment[:name] && (value = attrs[:name])
        fragment[:name] = value
        fragment[:callback] = InlineDestinationMarker
      end
      fragment[:color] ||= @link_font_color
    when :sub
      styles << :subscript
    when :sup
      styles << :superscript
    #when :u
    #  styles << :underline
    when :del
      styles << :strikethrough
    when :span
      # span logic with normal style parsing
      if (inline_styles = attrs[:style])
        # NOTE for our purposes, spaces inside the style attribute are superfluous
        # NOTE split will ignore record after trailing ;
        inline_styles.tr(' ', '').split(';').each do |style|
          pname, pvalue = style.split(':', 2)
          case pname
          when 'color'
            unless fragment[:color]
              pvalue = pvalue[1..-1] if pvalue.start_with? '#'
              #pvalue = pvalue.each_char.map {|c| c * 2 }.join if pvalue.size == 3
              fragment[:color] = pvalue
            end
          when 'font-weight'
            if pvalue == 'bold'
              styles << :bold
            end
          when 'font-style'
            if pvalue == 'italic'
              styles << :italic
            end
          # TODO text-transform
          end
        end
      end
    end
    fragment.delete(:styles) if styles.empty?
    fragment
  end
end
end
end
end
