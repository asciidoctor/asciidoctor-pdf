# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Pass' do
  it 'should render pass as plain literal block' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_color: '222222', code_font_color: '0000EE' }, analyze: true
    ++++
    <p>
    stay
      calm
    and
      <strong>pass</strong>
    through
    </p>
    ++++
    EOS

    all_text = pdf.text
    (expect all_text.size).to be > 1
    all_text.each do |text|
      (expect text[:font_color]).to eql '222222'
      (expect text[:font_name]).to eql 'mplus1mn-regular'
    end
    (expect all_text[0][:string]).to eql '<p>'
    (expect all_text[4][:string]).to eql %(\u00a0 <strong>pass</strong>)
  end

  it 'should add bottom margin to pass block' do
    pdf = to_pdf <<~'EOS', analyze: true
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
