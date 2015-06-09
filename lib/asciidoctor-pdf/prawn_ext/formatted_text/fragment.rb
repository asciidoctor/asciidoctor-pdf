module Asciidoctor
module Prawn
module FormattedText
module Fragment
  attr_reader :document
  
  # Prevent fragment from being written by discarding the text.
  def conceal
    @text = ''
  end
end

# NOTE we use __send__ since :include wasn't public until Ruby 2.0
::Prawn::Text::Formatted::Fragment.__send__ :include, Fragment
end
end
end
