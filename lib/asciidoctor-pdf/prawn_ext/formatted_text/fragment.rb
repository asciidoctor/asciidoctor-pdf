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

if ::RUBY_MIN_VERSION_2
  ::Prawn::Text::Formatted::Fragment.prepend Fragment
else
  # NOTE it's necessary to first remove the accessor methods we are replacing
  ::Prawn::Text::Formatted::Fragment.__send__ :remove_method, :ascender=
  ::Prawn::Text::Formatted::Fragment.__send__ :remove_method, :descender=
  # NOTE we use __send__ since :include wasn't public until Ruby 2.0
  ::Prawn::Text::Formatted::Fragment.__send__ :include, Fragment
end
end
end
end
