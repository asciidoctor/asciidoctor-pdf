module Asciidoctor
module Pdf
module TemporaryPath
  def unlink
    ::File.unlink self
  end
end
end
end
