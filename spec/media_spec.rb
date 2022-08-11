# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - media' do
  context 'print' do
    it 'should use default-for-print theme if media is print and theme is not specified' do
      input = 'worth #marking#'
      text = (to_pdf input, attribute_overrides: { 'media' => 'print' }, analyze: true).text
      (expect text[0][:font_color]).to eql '000000'
      rects = (to_pdf input, attribute_overrides: { 'media' => 'print' }, analyze: :rect).rectangles
      (expect rects).to have_size 1
      (expect rects[0][:fill_color]).to eql 'CCCCCC'
    end
  end

  context 'prepress' do
    it 'should use default-for-print theme if media is prepress and theme is not specified' do
      input = 'worth #marking#'
      text = (to_pdf input, attribute_overrides: { 'media' => 'prepress' }, analyze: true).text
      (expect text[0][:font_color]).to eql '000000'
      rects = (to_pdf input, attribute_overrides: { 'media' => 'prepress' }, analyze: :rect).rectangles
      (expect rects).to have_size 1
      (expect rects[0][:fill_color]).to eql 'CCCCCC'
    end

    it 'should leave blank page after image cover page' do
      pdf = to_pdf <<~EOS
      = Document Title
      :doctype: book
      :media: prepress
      :front-cover-image: #{fixture_file 'cover.jpg', relative: true}

      == Chapter Title
      EOS

      (expect pdf.pages).to have_size 5
      (expect (pdf.page 3).text).to eql 'Document Title'
      (expect (pdf.page 5).text).to eql 'Chapter Title'
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
    end

    it 'should leave blank page after PDF cover page' do
      pdf = to_pdf <<~EOS
      = Document Title
      :doctype: book
      :media: prepress
      :front-cover-image: #{fixture_file 'blue-letter.pdf', relative: true}

      == Chapter Title
      EOS

      (expect pdf.pages).to have_size 5
      (expect (pdf.page 1).text).to be_empty
      (expect (pdf.page 3).text).to eql 'Document Title'
      (expect (pdf.page 5).text).to eql 'Chapter Title'
      # TODO: add helper method to get content stream for page
      title_page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (title_page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 1.0 scn']
    end

    it 'should insert blank page after TOC' do
      pdf = to_pdf <<~EOS, analyze: true
      = Document Title
      :doctype: book
      :media: prepress
      :toc:
      :front-cover-image: #{fixture_file 'cover.jpg', relative: true}

      == Beginning

      == Middle

      == End
      EOS

      (expect pdf.pages).to have_size 11
      (expect (pdf.find_text 'Document Title')[0][:page_number]).to be 3
      (expect (pdf.find_text 'Table of Contents')[0][:page_number]).to be 5
      (expect (pdf.find_text 'Beginning')[0][:page_number]).to be 5
      (expect (pdf.find_text 'Beginning')[1][:page_number]).to be 7
      (expect (pdf.find_text 'Middle')[0][:page_number]).to be 5
      (expect (pdf.find_text 'Middle')[1][:page_number]).to be 9
      (expect (pdf.find_text 'End')[0][:page_number]).to be 5
      (expect (pdf.find_text 'End')[1][:page_number]).to be 11
    end

    it 'should not insert blank page at start of document if document has no cover' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :media: prepress

      Preface content.

      == Chapter Title

      Chapter content.
      EOS

      (expect pdf.pages).to have_size 5
      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to be 1
      preface_text = (pdf.find_text 'Preface content.')[0]
      (expect preface_text[:page_number]).to be 3
      chapter_title_text = (pdf.find_text 'Chapter Title')[0]
      (expect chapter_title_text[:page_number]).to be 5
    end

    it 'should not insert blank page at start of document with toc if title page is disabled' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :media: prepress
      :notitle:
      :toc:

      == Chapter Title

      Chapter content.
      EOS

      (expect pdf.pages).to have_size 3
      toc_text = (pdf.find_text 'Table of Contents')[0]
      (expect toc_text[:page_number]).to be 1
      chapter_title_texts = pdf.find_text 'Chapter Title'
      (expect chapter_title_texts).to have_size 2
      (expect chapter_title_texts[0][:page_number]).to be 1
      (expect chapter_title_texts[1][:page_number]).to be 3
    end

    it 'should not insert blank page before chapter that follows preamble if chapter has nonfacing option' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :media: prepress

      preamble

      [%nonfacing]
      == Chapter
      EOS

      chapter_text = (pdf.find_text 'Chapter')[0]
      (expect chapter_text[:page_number]).to be 4
    end

    it 'should not insert blank page before chapter that follows document title if chapter has nonfacing option' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :media: prepress

      [%nonfacing]
      == Chapter
      EOS

      chapter_text = (pdf.find_text 'Chapter')[0]
      (expect chapter_text[:page_number]).to be 2
    end
  end
end
