module Asciidoctor
module PDF
module FormattedText
class Transform
  LF = ?\n
  ZeroWidthSpace = ?\u200b
  CharEntityTable = {
    amp: ?&,
    apos: ?',
    gt: ?>,
    lt: ?<,
    nbsp: ?\u00a0,
    quot: ?",
  }
  CharRefRx = /&(?:(#{CharEntityTable.keys * ?|})|#(?:(\d\d\d{0,4})|x([a-f\d][a-f\d][a-f\d]{0,3})));/
  TextDecorationTable = { 'underline' => :underline, 'line-through' => :strikethrough }
  #DummyText = ?\u0000

  def initialize(options = {})
    @merge_adjacent_text_nodes = options[:merge_adjacent_text_nodes]
    # TODO add support for character spacing
    if (theme = options[:theme])
      @theme_settings = {
        button: {
          color: theme.button_font_color,
          font: theme.button_font_family,
          size: theme.button_font_size,
          styles: to_styles(theme.button_font_style),
          background_color: (button_bg_color = theme.button_background_color),
          border_width: (button_border_width = theme.button_border_width),
          border_color: button_border_width && (theme.button_border_color || theme.base_border_color),
          border_offset: (button_bg_or_border = button_bg_color || button_border_width) && theme.button_border_offset,
          border_radius: button_bg_or_border && theme.button_border_radius,
          callback: button_bg_or_border && [TextBackgroundAndBorderRenderer],
        }.compact,
        code: {
          color: theme.literal_font_color,
          font: theme.literal_font_family,
          size: theme.literal_font_size,
          styles: to_styles(theme.literal_font_style),
          background_color: (monospaced_bg_color = theme.literal_background_color),
          border_width: (monospaced_border_width = theme.literal_border_width),
          border_color: monospaced_border_width && (theme.literal_border_color || theme.base_border_color),
          border_offset: (monospaced_bg_or_border = monospaced_bg_color || monospaced_border_width) && theme.literal_border_offset,
          border_radius: monospaced_bg_or_border && theme.literal_border_radius,
          callback: monospaced_bg_or_border && [TextBackgroundAndBorderRenderer],
        }.compact,
        link: {
          color: theme.link_font_color,
          font: theme.link_font_family,
          size: theme.link_font_size,
          styles: to_styles(theme.link_font_style, theme.link_text_decoration)
        }.compact,
      }
    else
      @theme_settings = {
        button: { font: 'Courier', styles: [:bold].to_set },
        code: { font: 'Courier', size: 0.9 },
        link: { color: '0000FF' },
      }
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
        if node.key?(:pcdata)
          unless (pcdata = node[:pcdata]).empty?
            tag_name = node[:name]
            attributes = node[:attributes]
            # NOTE decorate child fragments with styles from this element
            fragments << apply(pcdata).map {|fragment| build_fragment(fragment, tag_name, attributes) }
            previous_fragment_is_text = false
          # NOTE skip element if it has no children
          #else
          #  # NOTE handle an empty anchor element (i.e., <a ...></a>)
          #  if (tag_name = node[:name]) == :a
          #    fragments << build_fragment({ text: DummyText }, tag_name, node[:attributes])
          #    previous_fragment_is_text = false
          #  end
          end
        # case 2: void element
        else
          case node[:name]
          when :br
            if @merge_adjacent_text_nodes && previous_fragment_is_text
              fragments << { text: %(#{fragments.pop[:text]}#{LF}) }
            else
              fragments << { text: LF }
            end
            previous_fragment_is_text = true
          when :img
            attributes = node[:attributes]
            fragment = {
              image_path: attributes[:tmp] == 'true' ? attributes[:src].extend(TemporaryPath) : attributes[:src],
              image_format: attributes[:format],
              # a zero-width space in the text will cause the image to be duplicated
              text: (attributes[:alt].delete ZeroWidthSpace),
              callback: [InlineImageRenderer],
            }
            if (img_w = attributes[:width])
              fragment[:image_width] = img_w
            end
            fragments << fragment
            previous_fragment_is_text = false
          end
        end
      when :text
        if @merge_adjacent_text_nodes && previous_fragment_is_text
          fragments << { text: %(#{fragments.pop[:text]}#{node[:value]}) }
        else
          fragments << { text: node[:value] }
        end
        previous_fragment_is_text = true
      when :charref
        if (ref_type = node[:reference_type]) == :name
          text = CharEntityTable[node[:value]]
        elsif ref_type == :decimal
          # FIXME AFM fonts do not include a thin space glyph; set fallback_fonts to allow glyph to be resolved
          text = [node[:value]].pack('U1')
        else
          # FIXME AFM fonts do not include a thin space glyph; set fallback_fonts to allow glyph to be resolved
          text = [(node[:value].to_i 16)].pack('U1')
        end
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
    when :code, :button
      # NOTE prefer old value, except for styles and callback, which should be combined
      fragment.update(@theme_settings[tag_name]) {|k, oval, nval| k == :styles ? oval.merge(nval) : (k == :callback ? oval.union(nval) : oval) }
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
        elsif (r_val = attrs[:r]) && (g_val = attrs[:g]) && (b_val = attrs[:b])
          fragment[:color] = [r_val, g_val, b_val].map {|e| '%02X' % e.to_i }.join
        elsif (c_val = attrs[:c]) && (m_val = attrs[:m]) && (y_val = attrs[:y]) && (k_val = attrs[:k])
          fragment[:color] = [c_val.to_i, m_val.to_i, y_val.to_i, k_val.to_i]
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
      if (value = attrs[:width])
        fragment[:width] = value
        if (value = attrs[:align])
          fragment[:align] = value.to_sym
          (fragment[:callback] ||= []) << InlineTextAligner
        end
      end
      #if !fragment[:character_spacing] && (value = attrs[:character_spacing])
      #  fragment[:character_spacing] = value.to_f
      #end
    when :a
      visible = true
      # a element can have no attributes, so short-circuit if that's the case
      unless attrs.empty?
        # NOTE href, anchor, and name are mutually exclusive; nesting is not supported
        if (value = attrs[:anchor])
          fragment[:anchor] = value
        elsif (value = attrs[:href])
          fragment[:link] = value.include?(';') ? value.gsub(CharRefRx) {
            $1 ? CharEntityTable[$1.to_sym] : [$2 ? $2.to_i : ($3.to_i 16)].pack('U1')
          } : value
        elsif (value = attrs[:name])
          # NOTE text is null character, which is used as placeholder text so Prawn doesn't drop fragment
          fragment[:name] = value
          if (type = attrs[:type])
            fragment[:type] = type.to_sym
          end
          (fragment[:callback] ||= []) << InlineDestinationMarker
          visible = false
        end
      end
      # NOTE prefer old value, except for styles, which should be combined
      fragment.update(@theme_settings[:link]) {|k, oval, nval| k == :styles ? oval.merge(nval) : oval } if visible
    when :sub
      styles << :subscript
    when :sup
      styles << :superscript
    when :del
      styles << :strikethrough
    when :span
      # NOTE spaces in style attribute value are superfluous, for our purpose; split drops record after trailing ;
      attrs[:style].tr(' ', '').split(';').each do |style|
        pname, pvalue = style.split(':', 2)
        case pname
        when 'color'
          # QUESTION should we check whether the value is a valid hex color?
          unless fragment[:color]
            case pvalue.length
            when 6
              fragment[:color] = pvalue
            when 7
              fragment[:color] = pvalue.slice(1, 6) if pvalue.start_with?('#')
            # QUESTION should we support the 3 character form?
            #when 3
            #  fragment[:color] = pvalue.each_char.map {|c| c * 2 }.join
            #when 4
            #  fragment[:color] = pvalue.slice(1, 3).each_char.map {|c| c * 2 }.join if pvalue.start_with?('#')
            end
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
      end if attrs.key?(:style)
    end
    # TODO we could limit to select tags, but doesn't seem to really affect performance
    attrs[:class].split.each do |class_name|
      case class_name
      when 'underline'
        styles << :underline
      when 'line-through'
        styles << :strikethrough
      end
    end if attrs.key?(:class)
    fragment.delete(:styles) if styles.empty?
    fragment
  end

  def to_styles(font_style, text_decoration = nil)
    case font_style
    when 'bold'
      styles = [:bold].to_set
    when 'italic'
      styles = [:italic].to_set
    when 'bold_italic'
      styles = [:bold, :italic].to_set
    else
      styles = nil
    end
    if (style = TextDecorationTable[text_decoration])
      styles ? (styles << style) : [style].to_set
    else
      styles
    end
  end
end
end
end
end
