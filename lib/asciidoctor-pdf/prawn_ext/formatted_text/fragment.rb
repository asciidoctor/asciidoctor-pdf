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
end

class ::Prawn::Text::Formatted::Fragment
  if respond_to? :prepend
    prepend Fragment
  else
    # NOTE it's necessary to remove the accessor methods or else they won't get replaced
    remove_method :ascender=
    remove_method :descender=
    include Fragment
  end
end
end
end
end
