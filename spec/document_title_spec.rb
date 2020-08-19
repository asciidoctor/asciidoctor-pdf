# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Document Title' do
  context 'book' do
    it 'should partition the main title and subtitle' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Main Title: Subtitle
      :doctype: book

      body
      EOS

      title_page_texts = pdf.find_text page_number: 1
      (expect title_page_texts).to have_size 2
      main_title_text = title_page_texts[0]
      subtitle_text = title_page_texts[1]
      (expect main_title_text[:string]).to eql 'Main Title'
      (expect main_title_text[:font_color]).to eql '999999'
      (expect main_title_text[:font_name]).to eql 'NotoSerif'
      (expect subtitle_text[:string]).to eql 'Subtitle'
      (expect subtitle_text[:font_color]).to eql '333333'
      (expect subtitle_text[:font_name]).to eql 'NotoSerif-BoldItalic'
      (expect subtitle_text[:y]).to be < main_title_text[:y]
    end

    it 'should not include title page if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).not_to include 'Document Title'
    end

    it 'should not include title page if title_page key in theme is false' do
      pdf = to_pdf <<~'EOS', doctype: :book, pdf_theme: { title_page: false }, analyze: :page
      = Document Title

      body
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).not_to include 'Document Title'
    end

    it 'should include title page if showtitle attribute is unset (as it has no effect)' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :!showtitle:

      body
      EOS
      (expect pdf.pages[0][:strings]).to include 'Document Title'
    end
  end

  context 'article' do
    it 'should place document title at top of first page of content' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title

      body
      EOS

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text).not_to be_nil
      (expect doctitle_text[:page_number]).to be 1
      body_text = (pdf.find_text 'body')[0]
      (expect body_text).not_to be_nil
      (expect body_text[:page_number]).to be 1
      (expect doctitle_text[:y]).to be > body_text[:y]
    end

    it 'should align document title according to value of heading_h1_align theme key' do
      pdf = to_pdf <<~'EOS', pdf_theme: { heading_h1_align: 'left' }, analyze: true
      = Document Title

      body
      EOS

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text).not_to be_nil
      body_text = (pdf.find_text 'body')[0]
      (expect body_text).not_to be_nil
      (expect doctitle_text[:x]).to eql body_text[:x]
    end

    it 'should not include document title if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: :page
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).not_to include 'Document Title'
    end
  end
end
