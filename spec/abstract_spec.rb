# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Abstract' do
  it 'should outdent abstract title and body' do
    pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36, abstract_title_align: :left }, analyze: true
    = Document Title
    :doctype: book

    .Abstract
    [abstract]
    A presage of what is to come.

    == Chapter

    What came to pass.
    EOS

    abstract_title_text = (pdf.find_text 'Abstract')[0]
    (expect abstract_title_text[:x]).to eql 48.24
    abstract_content_text = (pdf.find_text 'A presage of what is to come.')[0]
    (expect abstract_content_text[:x]).to eql 48.24
    chapter_text = (pdf.find_text 'What came to pass.')[0]
    (expect chapter_text[:x]).to eql 84.24
  end
end
