require_relative 'spec_helper'

describe Asciidoctor::PDF::Converter do
  context 'legacy module name' do
    it 'should map Asciidoctor::Pdf module to Asciidoctor::PDF' do
      (expect Asciidoctor::Pdf).to be Asciidoctor::PDF
      (expect Asciidoctor::Pdf::VERSION).to be Asciidoctor::PDF::VERSION
      (expect Asciidoctor::Pdf::Converter).to be Asciidoctor::PDF::Converter
      (expect Asciidoctor::Pdf::ThemeLoader).to be Asciidoctor::PDF::ThemeLoader
    end
  end

  context '.register_for' do
    it 'should self register to handle pdf backend' do
      registered = asciidoctor_2_or_better? ? (Asciidoctor::Converter.for 'pdf') : (Asciidoctor::Converter::Factory.resolve 'pdf')
      (expect registered).to be Asciidoctor::PDF::Converter
    end

    it 'should convert AsciiDoc string to PDF object when backend is pdf' do
      (expect Asciidoctor.convert 'hello', backend: 'pdf').to be_a Prawn::Document
    end

    it 'should convert AsciiDoc file to PDF file when backend is pdf' do
      pdf = to_pdf Pathname.new fixture_file 'hello.adoc'
      (expect Pathname.new output_file 'hello.pdf').to exist
      (expect pdf.page_count).to be > 0
    end
  end

  context '#convert' do
    it 'should not fail to convert empty string' do
      (expect to_pdf '').to_not be_nil
    end

    it 'should not fail to convert empty file' do
      pdf = to_pdf Pathname.new fixture_file 'empty.adoc'
      (expect Pathname.new output_file 'empty.pdf').to exist
      (expect pdf.page_count).to be > 0
    end

    it 'should ensure data-uri attribute is set' do
      doc = Asciidoctor.load <<~'EOS', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      image::logo.png[]
      EOS
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end if asciidoctor_2_or_better?

    it 'should ignore data-uri attribute entry in document' do
      doc = Asciidoctor.load <<~'EOS', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      :!data-uri:

      image::logo.png[]
      EOS
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end if asciidoctor_2_or_better?

    it 'should use theme passed in through :pdf_theme option' do
      theme = Asciidoctor::PDF::ThemeLoader.load_theme 'custom', fixtures_dir
      pdf = Asciidoctor.convert <<~'EOS', backend: 'pdf', pdf_theme: theme
      content
      EOS

      (expect pdf.instance_variable_get :@theme).to be theme
    end
  end
end
