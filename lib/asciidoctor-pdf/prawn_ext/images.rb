module Asciidoctor
module Prawn
module Images
  # Dispatch to suitable image method in Prawn based on file extension.
  def image file, opts = {}
    if (::File.extname file).downcase == '.svg'
      opts[:at] ||= bounds.top_left
      svg ::IO.read(file), opts
    else
      _builtin_image file, opts
    end
  end
end
end
end

module Prawn
class Document
  alias :_builtin_image :image
  include ::Asciidoctor::Prawn::Images
end
end
