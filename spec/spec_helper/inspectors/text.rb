# frozen_string_literal: true

class TextInspector < PDF::Inspector
  include ::RSpec::Matchers

  attr_accessor :text
  attr_accessor :pages

  def initialize
    @color = nil
    @cursor = nil
    @fonts = {}
    @text = []
    @pages = []
  end

  def find_text string, filter = {}
    if ::Hash === string
      filter = string.merge filter
    else
      filter[:string] = string
    end
    if ::Regexp === filter[:string]
      string_rx = filter.delete :string
      @text.select {|candidate| filter <= candidate && (string_rx.match? candidate[:string]) }
    else
      @text.select {|candidate| filter <= candidate }
    end
  end

  def find_unique_text string, filter = {}
    result = find_text string, filter
    (expect result).to have_size 1 unless result.empty?
    result[0]
  end

  def strings text = @text
    text.map {|it| it[:string] }
  end

  def lines text = @text
    prev = nil
    text.each_with_object [] do |it, accum|
      #if prev && (prev[:y] == it[:y] || (prev[:y] - it[:y]).abs < [it[:font_size], prev[:font_size]].min * 0.5)
      if prev && prev[:page_number] == it[:page_number] && (prev[:y] == it[:y] || (prev[:y] - it[:y]).abs < 6)
        if it[:x] - prev[:x] > prev[:width] + 0.5
          accum << %(#{accum.pop.rstrip} #{it[:string].lstrip})
        else
          accum << %(#{accum.pop}#{it[:string]})
        end
      else
        accum << it[:string]
      end
      prev = it
    end
  end

  def page pagenum
    @pages[pagenum - 1]
  end

  def page= page
    @pages << { size: (page.attributes[:MediaBox].slice 2, 2), text: [], raw_content: page.raw_content }
    @page_number = page.number
    @state = ::PDF::Reader::PageState.new page
    page.fonts.each do |label, stream|
      base_font = stream[:BaseFont].to_s
      base_font = (base_font.partition '+')[-1] if base_font.include? '+'
      @fonts[label] = base_font
    end
  end

  def extract_graphic_states content
    content = (content.delete_prefix %(q\n)).delete_suffix %(\nQ)
    (content.scan %r/^q\n(.*?)\nQ$/m).map {|it| it[0].split ?\n }
  end

  # Tf
  def set_text_font_and_size *params
    @state.set_text_font_and_size(*params)
    @font_settings = { name: @fonts[params[0]], size: params[1], color: @color }
  end

  # scn (used for font color in SVG)
  def set_color_for_nonstroking_and_special *params
    @color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| sprintf '%02X', (it.to_f * 255).round }.join
  end

  # SCN
  def set_color_for_stroking_and_special *params
    @color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| sprintf '%02X', (it.to_f * 255).round }.join
  end

  def move_text_position x, y
    @cursor = { page_number: @page_number, x: x, y: y }
  end

  def show_text_with_positioning chunks
    show_text chunks.reject {|candidate| ::Numeric === candidate }.join, true
  end

  def show_text text, kerned = false
    # NOTE: this may be a rough approximation
    text_width = (@state.current_font.unpack text).reduce 0 do |width, code|
      width + (@state.current_font.glyph_width code) * @font_settings[:size] / 1000.0
    end

    string = @state.current_font.to_utf8 text
    if @cursor
      accum = @cursor
      accum[:order] = @text.size + 1
      accum[:font_name] = @font_settings[:name]
      accum[:font_size] = @font_settings[:size]
      accum[:font_color] = @font_settings[:color]
      accum[:string] = string
      accum[:width] = text_width
      @text << accum
      @pages[-1][:text] << accum
      @cursor = nil
    else
      (accum = @text[-1])[:string] += string
      accum[:width] += text_width
    end
    accum[:kerned] ||= kerned
  end
end
