module Asciidoctor
module PDF
class Pdfmark
  include ::Asciidoctor::PDF::Sanitizer

  def initialize doc
    @doc = doc
  end

  def generate
    doc = @doc
    # FIXME use sanitize: :plain_text once available
    content = <<~EOS
    [ /Title #{sanitize(doc.doctitle use_fallback: true).to_pdf}
      /Author #{(doc.attr 'authors').to_pdf}
      /Subject #{(doc.attr 'subject').to_pdf}
      /Keywords #{(doc.attr 'keywords').to_pdf}
      /ModDate #{date = ::Time.now.to_pdf}
      /CreationDate #{date}
      /Creator (Asciidoctor PDF #{::Asciidoctor::PDF::VERSION}, based on Prawn #{::Prawn::VERSION})
      /Producer #{(doc.attr 'publisher').to_pdf}
      /DOCINFO pdfmark
    EOS
    content
  end

  def generate_file pdf_file
    # QUESTION should we use the extension pdfmeta to be more clear?
    ::File.write %(#{pdf_file}mark), generate
  end
end
end
end
