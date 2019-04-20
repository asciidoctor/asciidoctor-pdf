require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Document Title' do
  context 'book' do
    it 'should place document title on title page for doctype book' do
      pdf = to_pdf <<~'EOS', doctype: 'book', analyze: true
      = Document Title

      body
      EOS
      (expect pdf.pages.size).to eql 2
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'body'
    end

    it 'should not include title page if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', doctype: 'book', analyze: true
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:strings]).to_not include 'Document Title'
    end
  end

  context 'article' do
    it 'should place document title centered on first page of content' do
      input = <<~'EOS'
      = Document Title

      body
      EOS

      pdf = to_pdf input, analyze: true
      (expect pdf.pages.size).to eql 1
      p1_strings = pdf.pages[0][:strings]
      (expect p1_strings).to include 'Document Title'
      (expect p1_strings).to include 'body'
      (expect p1_strings.index 'Document Title').to be < (p1_strings.index 'body')
      pdf = to_pdf input, analyze: :text
      (expect pdf.positions[0][0]).to be > pdf.positions[1][0]
    end

    it 'should place document title on title page if title-page attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :title-page:

      body
      EOS
      (expect pdf.pages.size).to eql 2
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'body'
    end

    it 'should not include document title if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:strings]).to_not include 'Document Title'
    end
  end
end
