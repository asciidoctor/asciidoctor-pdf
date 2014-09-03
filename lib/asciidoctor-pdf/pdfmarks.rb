module Asciidoctor
module Pdf
class Pdfmarks
  def initialize doc
    @doc = doc
  end

  def generate
    current_datetime = ::DateTime.now.strftime '%Y%m%d%H%M%S'
    doc = @doc
    content = <<-EOS
[ /Title (#{doc.doctitle sanitize: true, use_fallback: true})
  /Author (#{doc.attr 'authors'})
  /Subject (#{doc.attr 'subject'})
  /Keywords (#{doc.attr 'keywords'})
  /ModDate (D:#{current_datetime})
  /CreationDate (D:#{current_datetime})
  /Creator (Asciidoctor PDF #{::Asciidoctor::Pdf::VERSION}, based on Prawn #{::Prawn::VERSION})
  /Producer (#{doc.attr 'publisher'})
  /DOCINFO pdfmark
    EOS
    content
  end

  def generate_file pdf_file
    ::IO.write %(#{pdf_file}marks), generate
  end
end
end
end
