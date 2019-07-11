require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - TOC' do
  context 'book' do
    it 'should not generate toc by default' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 4
      (expect pdf.find_text 'Table of Contents').to be_empty
    end

    it 'should insert toc between title page and first page of body when toc is set' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title
      :toc:

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 5
      (expect pdf.find_text string: 'Document Title', page_number: 1).not_to be_empty
      (expect pdf.find_text string: 'Table of Contents', page_number: 2).not_to be_empty
      (expect pdf.find_text string: '1', page_number: 2).not_to be_empty
      (expect pdf.find_text string: '2', page_number: 2).not_to be_empty
      (expect pdf.find_text string: '3', page_number: 2).not_to be_empty
      (expect pdf.find_text string: 'Introduction', page_number: 3).not_to be_empty
    end

    it 'should only include preface in toc if preface-title is set' do
      input = <<~'EOS'
      = Document Title

      [preface]
      This is the preface.

      == Chapter 1

      And away we go!
      EOS

      [{ 'toc' => '' }, { 'toc' => '', 'preface-title' => 'Preface' }].each do |attrs|
        pdf = to_pdf input, doctype: :book, attributes: attrs, analyze: :page
        (expect pdf.pages).to have_size 4
        (expect pdf.pages[0][:strings]).to include 'Document Title'
        (expect pdf.pages[1][:strings]).to include 'Table of Contents'
        if attrs.include? 'preface-title'
          (expect pdf.pages[1][:strings]).to include 'Preface'
          (expect pdf.pages[1][:strings]).to include '1'
        else
          (expect pdf.pages[1][:strings]).not_to include 'Preface'
          (expect pdf.pages[1][:strings]).not_to include '1'
        end
        (expect pdf.pages[1][:strings]).to include 'Chapter 1'
        (expect pdf.pages[1][:strings]).to include '2'
        if attrs.include? 'preface-title'
          (expect pdf.pages[2][:strings]).to include 'Preface'
        end
        (expect pdf.pages[2][:strings]).to include 'This is the preface.'
        (expect pdf.pages[3][:strings]).to include 'Chapter 1'
      end
    end

    it 'should output toc with depth specified by toclevels' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :toc:
      :toclevels: 1

      == Level 1

      === Level 2

      ==== Level 3
      EOS
      (expect pdf.pages).to have_size 3
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include 'Level 1'
      (expect pdf.pages[1][:strings]).not_to include 'Level 2'
      (expect pdf.pages[1][:strings]).not_to include 'Level 3'
      (expect pdf.pages[2][:strings]).to include 'Level 1'
    end

    it 'should only show parts in toc if toclevels attribute is 0' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :toc:
      :toclevels: 0

      = Part One

      == Chapter A

      = Part Two

      == Chapter B
      EOS
      (expect pdf.pages).to have_size 6
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include 'Part One'
      (expect pdf.pages[1][:strings]).to include 'Part Two'
      (expect pdf.pages[1][:strings]).not_to include 'Chapter A'
      (expect pdf.pages[1][:strings]).not_to include 'Chapter B'
    end

    it 'should reserve enough pages for toc if it spans more than one page' do
      sections = (1..40).map {|num| %(\n\n=== Section #{num}) }
      pdf = to_pdf <<~EOS, doctype: :book, analyze: :page
      = Document Title
      :toc:

      == Chapter 1#{sections.join}
      EOS
      (expect pdf.pages).to have_size 6
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[3][:strings]).to include 'Chapter 1'
    end
  end

  context 'article' do
    it 'should not generate toc by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.find_text 'Table of Contents').to be_empty
    end

    it 'should insert toc between document title and content when toc is set' do
      lorem = ['lorem ipsum'] * 10 * %(\n\n)
      input = <<~EOS
      = Document Title
      :toc:

      Preamble

      == Introduction

      #{lorem}

      == Main

      #{lorem}

      == Conclusion

      #{lorem}
      EOS
      pdf = to_pdf input, analyze: true
      (expect pdf.pages).to have_size 2
      (expect pdf.find_text string: 'Table of Contents', page_number: 1).to have_size 1
      (expect pdf.find_text string: 'Introduction', page_number: 1).to have_size 2
      doctitle_text = (pdf.find_text 'Document Title')[0]
      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      toc_bottom_text = (pdf.find_text '2')[0]
      content_top_text = (pdf.find_text 'Preamble')[0]
      (expect doctitle_text[:y]).to be > toc_title_text[:y]
      (expect toc_title_text[:y]).to be > content_top_text[:y]
      (expect toc_bottom_text[:y]).to be > content_top_text[:y]
      # NOTE assert there's no excess gap between end of toc and start of content
      (expect toc_bottom_text[:y] - content_top_text[:y]).to be < 35
    end

    it 'should reserve enough pages for toc if it spans more than one page' do
      sections = (1..40).map {|num| %(\n\n== Section #{num}) }
      input = <<~EOS
      = Document Title
      :toc:

      #{sections.join}
      EOS
      pdf = to_pdf input, analyze: :page
      (expect pdf.pages).to have_size 4
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[0][:strings]).to include 'Table of Contents'
      (expect pdf.pages[0][:strings]).not_to include 'Section 40'
      (expect pdf.pages[1][:strings]).to include 'Section 40'
      (expect pdf.pages[1][:strings]).to include 'Section 1'
      pdf = to_pdf input, analyze: true
      text = pdf.text
      idx_toc_bottom = nil
      idx_content_top = nil
      text.each_with_index do |candidate, idx|
        idx_toc_bottom = idx if candidate[:string] == 'Section 40' && candidate[:font_size] == 10.5
      end
      text.each_with_index do |candidate, idx|
        idx_content_top = idx if candidate[:string] == 'Section 1' && candidate[:font_size] == 22
      end
      (expect text[idx_toc_bottom][:y]).to be > text[idx_content_top][:y]
      # NOTE assert there's no excess gap between end of toc and start of content
      (expect text[idx_toc_bottom][:y] - text[idx_content_top][:y]).to be < 50
    end

    it 'should insert toc between title page and first page of body when toc and title-page are set' do
      pdf = to_pdf <<~'EOS', analyze: :page
      = Document Title
      :toc:
      :title-page:

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 3
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include '1'
      (expect pdf.pages[1][:strings]).not_to include '2'
      (expect pdf.pages[2][:strings]).to include 'Introduction'
    end
  end

  it 'should apply consistent font color to running content when base font color is unset', integration: true do
    theme_overrides = {
      extends: 'base',
      base_font_color: nil,
      header_height: 36,
      header_font_color: '0000FF',
      header_columns: '0% =100% 0%',
      header_recto_center_content: 'header text',
      header_verso_center_content: 'header text',
      toc_dot_leader_font_color: 'CCCCCC',
      running_content_start_at: 'toc',
    }
    to_file = to_pdf_file <<~'EOS', 'toc-running-content-font-color.pdf', pdf_theme: theme_overrides, analyze: true
    = Document Title
    Author Name
    :doctype: book
    :toc:

    == A

    text

    == B

    text
    EOS

    (expect to_file).to visually_match 'toc-running-content-font-color.pdf'
  end
end
