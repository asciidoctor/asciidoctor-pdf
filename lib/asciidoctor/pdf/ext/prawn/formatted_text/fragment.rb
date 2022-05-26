# frozen_string_literal: true

Prawn::Text::Formatted::Fragment.prepend (Module.new do
  attr_reader :document

  # Prevent fragment from being written by discarding the text, optionally forcing the width to 0
  def conceal force_width_to_zero = false
    if force_width_to_zero
      @width = 0
      @text = ''
    else
      @text = ' ' * space_count # preserve space_count so width is still computed correctly
    end
  end

  # Don't strip soft hyphens when repacking unretrieved fragments
  def include_trailing_white_space!
    @format_state.delete :normalized_soft_hyphen
    super
  end

  # Use .tr instead of .gsub to remove zero-width spaces
  def strip_zero_width_spaces string
    string.encoding == Encoding::UTF_8 ? (string.tr Prawn::Text::ZWSP, '') : string
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
      val = (val.end_with? 'em') ? val.to_f * @document.font_size : (@document.str_to_pt val) if String === val
    else
      val = super
    end
    if (border_offset = format_state[:border_offset])
      val += border_offset * 2
    end
    val
  end
end)
