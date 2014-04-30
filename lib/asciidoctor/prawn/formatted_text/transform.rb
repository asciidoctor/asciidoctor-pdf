module Asciidoctor
module Prawn
class FormattedTextTransform
  def initialize(options = {})
    @merge_adjacent_text_nodes = options.fetch(:merge_adjacent_text_nodes, false)
    if (theme = options[:theme])
      @monospaced_font_family = theme.literal_font_family
      @monospaced_font_color = theme.literal_font_color
      @link_font_color = theme.link_font_color
    else
      @monospaced_font_family = 'Courier'
      @monospaced_font_color = nil
      @link_font_color = '0000FF'
    end
  end

  # FIXME might want to pass styles downwards rather than decorating on way up
  def apply(parsed)
    fragments = []
    previous_fragment_is_text = false
    # NOTE using inject is slower than a manual loop
    parsed.each {|node|
      case (node_type = node[:type])
      when :element
        if (tag_name = node[:name]) == :br
          if @merge_adjacent_text_nodes && previous_fragment_is_text
            fragments << { text: %(#{fragments.pop[:text]}\n) }
          else
            fragments << { text: "\n" }
          end
          previous_fragment_is_text = true
        else
          pcdata = node[:pcdata] || []
          attributes = node[:attributes]
          fragments << apply(pcdata).map {|fragment|
            # decorate child fragments with styles from this element
            build_fragment(fragment, tag_name, attributes)
          } unless pcdata.size == 0
          previous_fragment_is_text = false
        end
      when :text, :entity
        node_text = if node_type == :text
          node[:value]
        elsif node_type == :entity
          if (entity_name = node[:name])
            case entity_name
            when :lt
              '<'
            when :gt
              '>'
            when :amp
              '&'
            when :quot
              '"'
            when :apos
              '\''
            end
          else
            [node[:number]].pack('U*')
            # afm fonts do not include a thin space glyph
            # set fallback_fonts to allow glyph to be resolved
            #if (node_number = node[:number]) == 8201
            #  ' '
            #else
            #  [node_number].pack('U*')
            #end
          end
        end
        if @merge_adjacent_text_nodes && previous_fragment_is_text
          fragments << { text: %(#{fragments.pop[:text]}#{node_text}) }
        else
          fragments << { text: node_text }
        end
        previous_fragment_is_text = true
      end
    }
    fragments.flatten
  end

  def build_fragment(fragment, tag_name = nil, attrs = {})
    #return { text: fragment } if tag_name.nil?
    styles = (fragment[:styles] ||= ::Set.new)
    case tag_name
    when :b, :strong
      styles << :bold
    when :i, :em
      styles << :italic
    when :code
      fragment[:font] ||= @monospaced_font_family
      # TODO pull relative size and character_spacing from theme
      fragment[:size] ||= 0.9
      fragment[:character_spacing] ||= -0.1
      if @monospaced_font_color
        fragment[:color] ||= @monospaced_font_color
      end
    when :color
      if !fragment[:color]
        if (rgb = attrs[:rgb])
          if rgb[0] == '#'
            rgb = rgb[1..-1]
          end
          fragment[:color] = rgb
        elsif (r = attrs[:r]) && (g = attrs[:g]) && (b = attrs[:b])
          fragment[:color] = [r, g, b].map {|e| '%02x' % e.to_i }.join
        elsif (c = attrs[:c]) && (m = attrs[:m]) && (y = attrs[:y]) && (k = attrs[:k])
          fragment[:color] = [c.to_i, m.to_i, y.to_i, k.to_i]
        end
      end
    when :font
      if !fragment[:font] && (value = attrs[:name])
        fragment[:font] = value
      end
      if !fragment[:size] && (value = attrs[:size])
        fragment[:size] = value.to_f
      end
      if !fragment[:character_spacing] && (value = attrs[:character_spacing])
        fragment[:character_spacing] = value.to_f
      end
    when :a, :link
      if !fragment[:anchor] && (value = attrs[:anchor])
        fragment[:anchor] = value
      end
      if !fragment[:link] && (value = attrs[:href])
        fragment[:link] = value
      end
      if !fragment[:local] && (value = attrs[:local])
        fragment[:local] = value
      end
      fragment[:color] ||= @link_font_color
    when :sub
      styles << :subscript
    when :sup
      styles << :superscript
    when :u
      styles << :underline
    when :del, :strikethrough
      styles << :strikethrough
    when :span
      # span logic with normal style parsing
      if (inline_styles = attrs[:style])
        inline_styles.rstrip.chomp(';').split(';').each do |style|
          pname, pvalue = style.split(':', 2)
          case pname
          when 'color'
            fragment[:color] = pvalue.tr(' #', '') unless fragment[:color]
          when 'font-weight'
            if pvalue.lstrip == 'bold'
              styles << :bold
            end
          when 'font-style'
            if pvalue.lstrip == 'italic'
              styles << :italic
            end
          end
        end
      end

      # quicker span logic that only honors font color
      #if !fragment[:color] && (value = attrs[:style]) && value.start_with?('color:')
      #  if value.include?(';')
      #    value = value.split(';').first
      #  end
      #  fragment[:color] = value[6..-1].tr(' #', '')
      #end
    end
    #fragment.delete(:styles) if styles.empty?
    fragment
  end
end
end
end
