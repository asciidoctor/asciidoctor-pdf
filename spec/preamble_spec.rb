# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Preamble' do
  context 'article' do
    it 'should not style first paragraph of preamble as lead in untitled article with no sections' do
      pdf = to_pdf <<~'END', analyze: true
      first paragraph

      second paragraph
      END

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should not crash if preamble has no blocks' do
      doc = Asciidoctor.load <<~'END', backend: :pdf, standalone: true
      = Document Title
      :nofooter:

      --
      --

      == Section

      content
      END

      doc.blocks[0].blocks.clear
      doc.convert.render (pdf_io = StringIO.new)
      pdf = PDF::Reader.new pdf_io
      lines = (pdf.page 1).text.strip.squeeze.split ?\n
      (expect lines).to eql ['Document Title', 'Section', 'content']
    end

    it 'should not style first paragraph of preamble as lead in article with no sections' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title

      first paragraph

      second paragraph
      END

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should style first paragraph of preamble as lead' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title

      preamble content

      more preamble content

      == First Section

      section content
      END

      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to be 13
      more_preamble_text = pdf.find_text 'more preamble content'
      (expect more_preamble_text).to have_size 1
      (expect more_preamble_text[0][:font_size]).to eql 10.5
      section_text = pdf.find_text 'section content'
      (expect section_text).to have_size 1
      (expect section_text[0][:font_size]).to eql 10.5
    end

    it 'should not style first paragraph of preamble as lead if it already has a role' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title

      [.nolead]
      preamble content

      more preamble content

      == First Section

      section content
      END

      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to eql 10.5
      more_preamble_text = pdf.find_text 'more preamble content'
      (expect more_preamble_text).to have_size 1
      (expect more_preamble_text[0][:font_size]).to eql 10.5
    end
  end

  context 'book' do
    it 'should not style first paragraph of preamble in untitled book with no sections' do
      pdf = to_pdf <<~'END', analyze: true
      :doctype: book

      first paragraph

      second paragraph
      END

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should not style first paragraph of preamble as lead in book with no sections' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book

      first paragraph

      second paragraph
      END

      first_paragraph_text = pdf.find_text 'first paragraph'
      (expect first_paragraph_text).to have_size 1
      (expect first_paragraph_text[0][:font_size]).to eql 10.5
      second_paragraph_text = pdf.find_text 'first paragraph'
      (expect second_paragraph_text).to have_size 1
      (expect second_paragraph_text[0][:font_size]).to eql 10.5
    end

    it 'should style first paragraph of preamble as lead in book with at least one chapter' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book

      preamble content

      more preamble content

      == First Chapter

      chapter content
      END

      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to be 13
      more_preamble_text = pdf.find_text 'more preamble content'
      (expect more_preamble_text).to have_size 1
      (expect more_preamble_text[0][:font_size]).to eql 10.5
      section_text = pdf.find_text 'chapter content'
      (expect section_text).to have_size 1
      (expect section_text[0][:font_size]).to eql 10.5
    end

    it 'should not style paragraph after abstract as lead in book with an abstract' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book

      [abstract]
      This is the abstract.

      This is the paragraph after the abstract.

      This is the paragraph after that.

      == First Chapter

      chapter content
      END

      after_abstract_text = pdf.find_text 'This is the paragraph after the abstract.'
      (expect after_abstract_text).to have_size 1
      (expect after_abstract_text[0][:font_size]).to eql 10.5
      after_that_text = pdf.find_text 'This is the paragraph after that.'
      (expect after_that_text).to have_size 1
      (expect after_that_text[0][:font_size]).to eql 10.5
    end

    it 'should ignore abstract with no blocks' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book

      [abstract]
      --
      --

      == First Chapter

      content

      == Second Chapter

      content
      END

      (expect pdf.pages).to have_size 3
      first_chapter_text = pdf.find_unique_text 'First Chapter'
      second_chapter_text = pdf.find_unique_text 'Second Chapter'
      (expect first_chapter_text[:y]).to eql second_chapter_text[:y]
    end

    it 'should promote preamble to preface if preface-title is set' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :preface-title: Preface

      preamble content

      == First Chapter

      chapter content
      END

      (expect pdf.find_text 'Preface', page_number: 2, font_size: 22).to have_size 1
      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to eql 10.5
      section_text = pdf.find_text 'chapter content'
      (expect section_text).to have_size 1
      (expect section_text[0][:font_size]).to eql 10.5
    end
  end

  context 'theming' do
    it 'should allow theme to customize style of lead paragraph' do
      pdf_theme = {
        role_lead_font_size: 14,
        role_lead_font_color: '000000',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title

      preamble content

      more preamble content

      == First Section

      section content
      END

      preamble_text = pdf.find_text 'preamble content'
      (expect preamble_text).to have_size 1
      (expect preamble_text[0][:font_size]).to be 14
      (expect preamble_text[0][:font_color]).to eql '000000'
      more_preamble_text = pdf.find_text 'more preamble content'
      (expect more_preamble_text).to have_size 1
      (expect more_preamble_text[0][:font_size]).to eql 10.5
      (expect more_preamble_text[0][:font_color]).to eql '333333'
    end
  end
end
