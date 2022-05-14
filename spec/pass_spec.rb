# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Pass' do
  it 'should render pass as code block' do
    pdf = to_pdf <<~'EOS', analyze: true
    ++++
    <p>This is a pass block.</p>
    ++++
    EOS

    (expect pdf.text).to have_size 1
    text = pdf.text[0]
    (expect text[:string]).to eql '<p>This is a pass block.</p>'
    (expect text[:font_name]).to eql 'mplus1mn-regular'
  end

  it 'should add bottom margin to pass block' do
    pdf = to_pdf <<~'EOS', pdf_theme: { code_padding: 0 }, analyze: true
    ++++
    This is a pass block.
    ++++

    This is a paragraph.
    EOS

    pass_text = pdf.find_unique_text 'This is a pass block.'
    para_text = pdf.find_unique_text 'This is a paragraph.'
    margin_bottom = pass_text[:y] - (para_text[:y] + para_text[:font_size])
    (expect margin_bottom).to be > 12
  end
end
