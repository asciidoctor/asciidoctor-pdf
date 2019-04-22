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
    it 'should center document title at top of first page of content' do
      pdf = to_pdf <<~'EOS', analyze: :text
      = Document Title

      body
      EOS

      text = pdf.text
      doctitle_text = text.find {|candidate| candidate[:string] == 'Document Title' }
      body_text = text.find {|candidate| candidate[:string] == 'body' }
      (expect doctitle_text).not_to be_nil
      (expect doctitle_text[:page_number]).to be 1
      (expect body_text).not_to be_nil
      (expect body_text[:page_number]).to be 1
      (expect doctitle_text[:y]).to be > body_text[:y]
    end

    it 'should align document title according to value of heading_h1_align theme key' do
      pdf = to_pdf <<~'EOS', theme_overrides: { heading_h1_align: :left }, analyze: :text
      = Document Title

      body
      EOS

      doctitle_text = pdf.text.find {|candidate| candidate[:string] == 'Document Title' }
      body_text = pdf.text.find {|candidate| candidate[:string] == 'body' }
      (expect doctitle_text).not_to be_nil
      (expect body_text).not_to be_nil
      (expect doctitle_text[:x]).to eql body_text[:x]
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
