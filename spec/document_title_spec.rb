require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Document Title' do
  context 'book' do
    it 'should place document title on title page for doctype book' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title

      body
      EOS

      (expect pdf.pages).to have_size 2
      text = pdf.text
      (expect text).to have_size 2
      (expect pdf.pages[0][:text]).to have_size 1
      doctitle_text = pdf.pages[0][:text][0]
      (expect doctitle_text[:string]).to eql 'Document Title'
      (expect doctitle_text[:font_size]).to eql 27
      (expect pdf.pages[1][:text]).to have_size 1
    end

    it 'should not include title page if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).to_not include 'Document Title'
    end

    it 'should allow left margin of elements on title page to be configured' do
      input = <<~'EOS'
      = Book Title: Bring Out Your Dead Trees
      Author Name
      v1.0, 2001-01-01

      body
      EOS

      theme_overrides = { title_page_align: 'left' }

      pdf = to_pdf input, doctype: :book, pdf_theme: theme_overrides, analyze: true

      expected_x = (pdf.find_text page_number: 1).map {|it| it[:x] + 10 }

      theme_overrides.update \
        title_page_title_margin_left: 10,
        title_page_subtitle_margin_left: 10,
        title_page_authors_margin_left: 10,
        title_page_revision_margin_left: 10

      pdf = to_pdf input, doctype: :book, pdf_theme: theme_overrides, analyze: true

      actual_x = (pdf.find_text page_number: 1).map {|it| it[:x] }
      (expect actual_x).to eql expected_x
    end

    it 'should allow right margin of elements on title page to be configured' do
      input = <<~'EOS'
      = Book Title: Bring Out Your Dead Trees
      Author Name
      v1.0, 2001-01-01

      body
      EOS

      pdf = to_pdf input, doctype: :book, analyze: true

      expected_x = (pdf.find_text page_number: 1).map {|it| it[:x] - 10 }

      theme_overrides = {
        title_page_title_margin_right: 10,
        title_page_subtitle_margin_right: 10,
        title_page_authors_margin_right: 10,
        title_page_revision_margin_right: 10,
      }

      pdf = to_pdf input, doctype: :book, pdf_theme: theme_overrides, analyze: true

      actual_x = (pdf.find_text page_number: 1).map {|it| it[:x] }
      (expect actual_x).to eql expected_x
    end

    it 'should be able to set background color of title page', integration: true do
      theme_overrides = {
        title_page_background_color: '000000',
        title_page_title_font_color: 'EFEFEF',
        title_page_authors_font_color: 'DBDBDB',
      }

      to_file = to_pdf_file <<~EOS, 'document-title-background-color.pdf', pdf_theme: theme_overrides
      = Dark and Stormy
      Author Name
      :doctype: book

      body
      EOS

      (expect to_file).to visually_match 'document-title-background-color.pdf'
    end
  end

  context 'article' do
    it 'should center document title at top of first page of content' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title

      body
      EOS

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text).not_to be_nil
      (expect doctitle_text[:page_number]).to eql 1
      body_text = (pdf.find_text 'body')[0]
      (expect body_text).not_to be_nil
      (expect body_text[:page_number]).to eql 1
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

    it 'should place document title on title page if title-page attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: :page
      = Document Title
      :title-page:

      body
      EOS
      (expect pdf.pages).to have_size 2
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'body'
    end

    it 'should not include document title if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: :page
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).to_not include 'Document Title'
    end
  end
end
