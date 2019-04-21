require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - TOC' do
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
      strings, positions = pdf.strings, pdf.positions
      idx_doctitle = strings.index 'Document Title'
      idx_toc_title = strings.index 'Table of Contents'
      idx_toc_bottom = strings.index '2'
      idx_content_top = strings.index 'Preamble'
      (expect positions[idx_doctitle][1]).to be > positions[idx_toc_title][1]
      (expect positions[idx_toc_title][1]).to be > positions[idx_content_top][1]
      (expect positions[idx_toc_bottom][1]).to be > positions[idx_content_top][1]
      # NOTE assert there's no excess gap between end of toc and start of content
      (expect positions[idx_toc_bottom][1] - positions[idx_content_top][1]).to be < 35
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
      strings, positions, font_metrics = pdf.strings, pdf.positions, pdf.font_settings
      idx_toc_bottom = nil
      idx_content_top = nil
      strings.each_with_index do |candidate, idx|
        idx_toc_bottom = idx if candidate == 'Section 40' && font_metrics[idx][:size] == 10.5
      end
      strings.each_with_index do |candidate, idx|
        idx_content_top = idx if candidate == 'Section 1' && font_metrics[idx][:size] == 22
      end
      (expect positions[idx_toc_bottom][1]).to be > positions[idx_content_top][1]
      # NOTE assert there's no excess gap between end of toc and start of content
      (expect positions[idx_toc_bottom][1] - positions[idx_content_top][1]).to be < 50
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
