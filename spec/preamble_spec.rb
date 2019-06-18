require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Preamble' do
  context 'article' do
    it 'should not increase font size of first paragraph of untitled article with no sections' do
      pdf = to_pdf <<~'EOS', analyze: true
      first paragraph

      second paragraph
      EOS

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should not increase font size of first paragraph of article with no sections' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title

      first paragraph

      second paragraph
      EOS

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should increase font size of first paragraph in preamble' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title

      preamble content

      more preamble content

      == First Section

      section content
      EOS

      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to eql 13
      more_preamble_text = pdf.find_text 'more preamble content'
      (expect more_preamble_text).to have_size 1
      (expect more_preamble_text[0][:font_size]).to eql 10.5
      section_text = pdf.find_text 'section content'
      (expect section_text).to have_size 1
      (expect section_text[0][:font_size]).to eql 10.5
    end
  end

  context 'book' do
    it 'should not increase font size of first paragraph of untitled book with no sections' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      first paragraph

      second paragraph
      EOS

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should not increase font size of first paragraph of book with no sections' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title

      first paragraph

      second paragraph
      EOS

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should increase font size of first paragraph in preamble' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title

      preamble content

      more preamble content

      == First Section

      section content
      EOS

      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to eql 13
      more_preamble_text = pdf.find_text 'more preamble content'
      (expect more_preamble_text).to have_size 1
      (expect more_preamble_text[0][:font_size]).to eql 10.5
      section_text = pdf.find_text 'section content'
      (expect section_text).to have_size 1
      (expect section_text[0][:font_size]).to eql 10.5
    end

    it 'should promote preamble to preface if preface-title is set' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title
      :preface-title: Preface

      preamble content

      == First Section

      section content
      EOS

      (expect pdf.find_text string: 'Preface', page_number: 2, font_size: 22).to have_size 1
      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to eql 10.5
      section_text = pdf.find_text 'section content'
      (expect section_text).to have_size 1
      (expect section_text[0][:font_size]).to eql 10.5
    end
  end
end
