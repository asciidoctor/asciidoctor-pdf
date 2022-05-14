# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - STEM' do
  it 'should render stem as code block if stem extension not present' do
    pdf = to_pdf <<~'EOS', analyze: true
    [stem]
    ++++
    sig = enc(H(D), s)
    ++++

    after
    EOS

    equation_text = (pdf.find_text 'sig = enc(H(D), s)')[0]
    (expect equation_text[:font_name]).to eql 'mplus1mn-regular'
    after_text = pdf.find_unique_text 'after'
    (expect equation_text[:y] - after_text[:y]).to be > 36
  end

  it 'should preserve indentation in stem block' do
    pdf = to_pdf <<~'EOS', pdf_theme: { page_margin: 36, code_padding: 10 }, analyze: true
    [stem]
    ++++
    M = \left[
      \begin{array}{ c c }
       1 & 2 \\
       3 & 4
      \end{array} \right]
    ++++
    EOS

    pdf.text.each {|text| (expect text[:font_name]).to eql 'mplus1mn-regular' }
    lhs_text = pdf.find_unique_text %r/^M/
    (expect lhs_text[:x]).to eql 46.0
    begin_text = pdf.find_unique_text %r/begin/
    (expect begin_text[:x]).to eql 46.0
    (expect begin_text[:string]).to start_with %(\u00a0 )
  end

  it 'should show caption and anchor above block if specified' do
    input = <<~'EOS'
    // listing-caption is not used in this case
    :listing-caption: Listing

    .A basic matrix
    [stem#matrix]
    ++++
    M = \left[
      \begin{array}{ c c }
       1 & 2 \\
       3 & 4
      \end{array} \right]
    ++++
    EOS

    pdf = to_pdf input, analyze: true
    caption_text = pdf.find_unique_text 'A basic matrix'
    (expect caption_text[:font_name]).to eql 'NotoSerif-Italic'
    lhs_text = pdf.find_unique_text %r/^M/
    (expect caption_text[:y]).to be > lhs_text[:y]
    (expect get_names (to_pdf input)).to have_key 'matrix'
  end
end
