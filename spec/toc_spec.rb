require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - TOC' do
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

  it 'should insert toc between title page and content by default when toc is set' do
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

  it 'should insert toc between title page and content by default when toc is set, doctype is article, and title-page is set' do
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

  it 'should reserve enough pages for toc if it spans more than one page' do
    sections = (1..40).map {|num| %(\n\n=== Section #{num}) }
    input = %(= Document Title\n:toc:#{sections.join})
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
