# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Floating Title' do
  it 'should apply alignment defined for headings in theme' do
    pdf_theme = {
      heading_text_align: 'center',
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    [discrete]
    == Discrete Heading

    main content
    EOS

    discrete_heading_text = pdf.find_unique_text 'Discrete Heading'
    main_text = pdf.find_unique_text 'main content'
    (expect discrete_heading_text[:x]).to be > main_text[:x]
  end

  it 'should apply alignment defined for heading level in theme' do
    pdf_theme = {
      heading_text_align: 'left',
      heading_h2_text_align: 'center',
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    [discrete]
    == Discrete Heading

    main content
    EOS

    discrete_heading_text = pdf.find_unique_text 'Discrete Heading'
    main_text = pdf.find_unique_text 'main content'
    (expect discrete_heading_text[:x]).to be > main_text[:x]
  end

  it 'should use base align to align floating title if theme does not specify alignemnt' do
    pdf_theme = {
      base_text_align: 'center',
      heading_h2_text_align: nil,
      heading_text_align: nil,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    [discrete]
    == Discrete Heading

    [.text-left]
    main content
    EOS

    discrete_heading_text = pdf.find_unique_text 'Discrete Heading'
    main_text = pdf.find_unique_text 'main content'
    (expect discrete_heading_text[:x]).to be > main_text[:x]
  end

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
