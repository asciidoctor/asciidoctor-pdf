module Asciidoctor
module Prawn
module Images
  class << self
    def extended base
      base.class.__send__ :alias_method, :_initial_image, :image
    end
  end

  # Dispatch to suitable image method in Prawn based on file extension.
  def image file, opts = {}
    if (::File.extname file).downcase == '.svg'
      opts[:at] ||= bounds.top_left
      svg ::IO.read(file), opts
    else
      _initial_image file, opts
    end
  end
end

::Prawn::Document.extensions << Images
end
end
