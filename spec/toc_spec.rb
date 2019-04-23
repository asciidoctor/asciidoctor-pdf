require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - TOC' do
  context 'book' do
    it 'should not generate toc by default' do
      pdf = to_pdf <<~'EOS', doctype: 'book', analyze: true
      = Document Title

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages.size).to eql 4
      strings = pdf.pages.inject([]) {|accum, page| accum.concat page[:strings]; accum }
      (expect strings).not_to include 'Table of Contents'
    end

    it 'should insert toc between title page and first page of body when toc is set' do
      pdf = to_pdf <<~'EOS', doctype: 'book', analyze: true
      = Document Title
      :toc:

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages.size).to eql 5
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include '1'
      (expect pdf.pages[1][:strings]).to include '2'
      (expect pdf.pages[1][:strings]).to include '3'
      (expect pdf.pages[2][:strings]).to include 'Introduction'
    end

    it 'should only include preface in toc if preface-title is set' do
      input = <<~'EOS'
      = Document Title

      [preface]
      This is the preface.

      == Chapter 1

      And away we go!
      EOS

      ['toc', %(toc preface-title=Preface)].each do |attrs|
        pdf = to_pdf input, doctype: 'book', attributes: attrs, analyze: true
        (expect pdf.pages.size).to eql 4
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
      pdf = to_pdf <<~'EOS', doctype: 'book', analyze: true
      = Document Title
      :toc:
      :toclevels: 1

      == Level 1

      === Level 2

      ==== Level 3
      EOS
      (expect pdf.pages.size).to eql 3
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include 'Level 1'
      (expect pdf.pages[1][:strings]).not_to include 'Level 2'
      (expect pdf.pages[1][:strings]).not_to include 'Level 3'
      (expect pdf.pages[2][:strings]).to include 'Level 1'
    end

    it 'should reserve enough pages for toc if it spans more than one page' do
      sections = (1..40).map {|num| %(\n\n=== Section #{num}) }
      pdf = to_pdf <<~EOS, doctype: 'book', analyze: true
      = Document Title
      :toc:

      == Chapter 1#{sections.join}
      EOS
      (expect pdf.pages.size).to eql 6
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
      (expect pdf.pages.size).to eql 1
      strings = pdf.pages.inject([]) {|accum, page| accum.concat page[:strings]; accum }
      (expect strings).not_to include 'Table of Contents'
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
      (expect pdf.pages.size).to eql 2
      (expect pdf.pages[0][:strings]).to include 'Table of Contents'
      (expect pdf.pages[0][:strings].count 'Introduction').to eql 2
      pdf = to_pdf input, analyze: :text
      strings, text = pdf.strings, pdf.text
      idx_doctitle = strings.index 'Document Title'
      idx_toc_title = strings.index 'Table of Contents'
      idx_toc_bottom = strings.index '2'
      idx_content_top = strings.index 'Preamble'
      (expect text[idx_doctitle][:y]).to be > text[idx_toc_title][:y]
      (expect text[idx_toc_title][:y]).to be > text[idx_content_top][:y]
      (expect text[idx_toc_bottom][:y]).to be > text[idx_content_top][:y]
      # NOTE assert there's no excess gap between end of toc and start of content
      (expect text[idx_toc_bottom][:y] - text[idx_content_top][:y]).to be < 35
    end

    it 'should reserve enough pages for toc if it spans more than one page' do
      sections = (1..40).map {|num| %(\n\n== Section #{num}) }
      input = <<~EOS
      = Document Title
      :toc:

      #{sections.join}
      EOS
      pdf = to_pdf input, analyze: true
      (expect pdf.pages.size).to eql 4
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[0][:strings]).to include 'Table of Contents'
      (expect pdf.pages[0][:strings]).not_to include 'Section 40'
      (expect pdf.pages[1][:strings]).to include 'Section 40'
      (expect pdf.pages[1][:strings]).to include 'Section 1'
      pdf = to_pdf input, analyze: :text
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
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :toc:
      :title-page:

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages.size).to eql 3
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include '1'
      (expect pdf.pages[1][:strings]).not_to include '2'
      (expect pdf.pages[2][:strings]).to include 'Introduction'
    end
  end
end
