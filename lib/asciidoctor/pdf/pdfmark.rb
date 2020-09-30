# frozen_string_literal: true

module Asciidoctor
  module PDF
    class Pdfmark
      include ::Asciidoctor::PDF::Sanitizer

      def initialize doc
        @doc = doc
      end

      def generate
        doc = @doc
        if doc.attr? 'reproducible'
          mod_date = creation_date = (::Time.at 0).utc
        else
          mod_date = (::Time.parse doc.attr 'docdatetime') rescue (now ||= ::Time.now)
          creation_date = (::Time.parse doc.attr 'localdatetime') rescue (now || ::Time.now)
        end
        <<~EOS
        [ /Title #{(sanitize doc.header? ? doc.doctitle : (doc.attr 'untitled-label')).to_pdf_object}
          /Author #{((doc.attr? 'authors') ? (sanitize doc.attr 'authors') : nil).to_pdf_object}
          /Subject #{((doc.attr? 'subject') ? (sanitize doc.attr 'subject') : nil).to_pdf_object}
          /Keywords #{((doc.attr? 'keywords') ? (sanitize doc.attr 'keywords') : nil).to_pdf_object}
          /ModDate #{mod_date.to_pdf_object}
          /CreationDate #{creation_date.to_pdf_object}
          /Creator (Asciidoctor PDF #{::Asciidoctor::PDF::VERSION}, based on Prawn #{::Prawn::VERSION})
          /Producer #{((doc.attr? 'publisher') ? (sanitize doc.attr 'publisher') : nil).to_pdf_object}
          /DOCINFO pdfmark
        EOS
      end

      def generate_file pdf_file
        # QUESTION: should we use the extension pdfmeta to be more clear?
        ::File.write %(#{pdf_file}mark), generate
      end
    end
  end
end
