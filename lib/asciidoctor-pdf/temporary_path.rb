module Asciidoctor
module PDF
module TemporaryPath
  def unlink
    ::File.unlink self
  end

  def exist?
    ::File.file? self
  end
end
end
end
