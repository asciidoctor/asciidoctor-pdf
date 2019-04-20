require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - PDF Info' do
  context 'compliance' do
    it 'should generate a PDF 1.3-compatible document' do
      (expect (to_pdf 'hello').pdf_version).to eq 1.3
    end
  end

  context 'attribution' do
    it 'should include Asciidoctor PDF and Prawn versions in Creator field' do
      creator = (to_pdf 'hello').info[:Creator]
      (expect creator).to_not be_nil
      (expect creator).to include %(Asciidoctor PDF #{Asciidoctor::Pdf::VERSION})
      (expect creator).to include %(Prawn #{Prawn::VERSION})
    end

    it 'should set Producer field to value of Creator field by default' do
      pdf = to_pdf 'hello'
      (expect pdf.info[:Producer]).to_not be_nil
      (expect pdf.info[:Producer]).to eql pdf.info[:Creator]
    end

    it 'should set Author and Producer field to value of author attribute if set' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      Author Name

      content
      EOS
      (expect pdf.info[:Producer]).to eql pdf.info[:Author]
      (expect pdf.info[:Author]).to eql 'Author Name'
    end

    it 'should set Producer field to value of publisher attribute if set' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      Author Name
      :publisher: Big Cheese
      
      content
      EOS
      (expect pdf.info[:Author]).to eql 'Author Name'
      (expect pdf.info[:Producer]).to eql 'Big Cheese'
    end
  end

  context 'document title' do
    it 'should set Title field to value of untitled-label attribute if doctitle is not set' do
      pdf = to_pdf 'body'
      (expect pdf.info[:Title]).to eql 'Untitled'
    end

    it 'should set Title field to value of document title if set' do
      pdf = to_pdf '= Document Title'
      (expect pdf.info[:Title]).to eql 'Document Title'
    end

    it 'should remove text formatting from document title before assigning to Title field' do
      pdf = to_pdf '= *Document* _Title_'
      (expect pdf.info[:Title]).to eql 'Document Title'
    end

    it 'should decode character references in document title before assigning to Title field' do
      pdf = to_pdf '= ACME(TM) Catalog <&#8470; 1>'
      (expect pdf.info[:Title]).to eql %(ACME\u2122 Catalog <\u2116 1>)
    end

    it 'should hex encode non-ASCII characters in Title field' do
      doctitle = 'Guide de démarrage rapide'
      pdf = to_pdf %(= #{doctitle})
      (expect pdf.info[:Title]).to eql doctitle
      encoded_doctitle = (pdf.objects[pdf.objects.trailer[:Info]])[:Title].unpack 'H*'
      (expect encoded_doctitle).to eql (doctitle.encode Encoding::UTF_16).unpack 'H*'
    end
  end
end
