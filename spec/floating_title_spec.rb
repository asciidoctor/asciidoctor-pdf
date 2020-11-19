# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Floating Title' do
  it 'should outdent discrete heading' do
    pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
    = Document Title

    == Section

    paragraph

    [discrete]
    === Discrete Heading

    paragraph

    === Nested Section

    paragraph

    [discrete]
    ==== Another Discrete Heading

    paragraph
    EOS

    discrete_heading_texts = pdf.find_text %r/Discrete/
    (expect discrete_heading_texts).to have_size 2
    (expect discrete_heading_texts[0][:x]).to eql 48.24
    (expect discrete_heading_texts[1][:x]).to eql 48.24
    paragraph_texts = pdf.find_text 'paragraph'
    (expect paragraph_texts.map {|it| it[:x] }.uniq).to eql [84.24]
  end

  it 'should not outdent discrete heading inside block' do
    pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
    == Section

    ****
    sidebar content

    [discrete]
    == Discrete Heading
    ****
    EOS

    sidebar_content_text = (pdf.find_text 'sidebar content')[0]
    discrete_heading_text = (pdf.find_text 'Discrete Heading')[0]
    (expect sidebar_content_text[:x]).to eql discrete_heading_text[:x]
  end

  it 'should honor text alignment role on discrete heading' do
    pdf = to_pdf <<~'EOS', analyze: true
    [discrete]
    == Discrete Heading
    EOS
    left_x = (pdf.find_text 'Discrete Heading')[0][:x]

    pdf = to_pdf <<~'EOS', analyze: true
    [discrete.text-right]
    == Discrete Heading
    EOS
    right_x = (pdf.find_text 'Discrete Heading')[0][:x]

    (expect right_x).to be > left_x
  end
end
