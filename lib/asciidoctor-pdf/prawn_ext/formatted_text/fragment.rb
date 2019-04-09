module Asciidoctor
module Prawn
module FormattedText
module Fragment
  attr_reader :document

  # Prevent fragment from being written by discarding the text.
  def conceal
    @text = ''
  end

  # Modify the built-in ascender write method to allow an override value to be
  # specified using the format_state hash.
  def ascender= val
    @ascender = (format_state.key? :ascender) ? format_state[:ascender] : val
  end

  # Modify the built-in ascender write method to allow an override value to be
  # specified using the format_state hash.
  def descender= val
    @descender = (format_state.key? :descender) ? format_state[:descender] : val
  end

  def width
    if (val = format_state[:width])
      (val.end_with? 'em') ? val.to_f * @document.font_size : val
    else
      super
    end
  end
end

::Prawn::Text::Formatted::Fragment.prepend Fragment
end
end
end
