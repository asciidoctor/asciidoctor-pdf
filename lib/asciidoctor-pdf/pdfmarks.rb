module Asciidoctor
module Pdf
class Pdfmarks
  include ::Asciidoctor::Pdf::Sanitizer
  include ::Asciidoctor::PdfCore::PdfObject

  def initialize doc
    @doc = doc
  end

  def generate
    current_datetime = ::DateTime.now.strftime '%Y%m%d%H%M%S'
    doc = @doc
    # FIXME use sanitize: :plain_text once available
    content = <<-EOS
[ /Title #{str2pdfobj sanitize(doc.doctitle use_fallback: true)}
  /Author #{str2pdfobj(doc.attr 'authors')}
  /Subject #{str2pdfobj(doc.attr 'subject')}
  /Keywords #{str2pdfobj(doc.attr 'keywords')}
  /ModDate (D:#{current_datetime})
  /CreationDate (D:#{current_datetime})
  /Creator (Asciidoctor PDF #{::Asciidoctor::Pdf::VERSION}, based on Prawn #{::Prawn::VERSION})
  /Producer #{str2pdfobj(doc.attr 'publisher')}
  /DOCINFO pdfmark
    EOS
    content
  end

  def generate_file pdf_file
    # QUESTION should we use the extension pdfmeta to be more clear?
    ::IO.write %(#{pdf_file}marks), generate
  end
end
end
end
