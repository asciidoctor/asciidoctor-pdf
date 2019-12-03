# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Quote' do
  it 'should show caption above block if title is specified' do
    pdf = to_pdf <<~'EOS', analyze: true
    .Words of wisdom
    ____
    Let it be.
    ____
    EOS

    (expect pdf.lines).to eql ['Words of wisdom', 'Let it be.']
    title_text = (pdf.find_text 'Words of wisdom')[0]
    (expect title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect title_text[:x]).to eql 48.24
  end

  it 'should not draw left border if border_width is 0' do
    pdf = to_pdf <<~'EOS', pdf_theme: { blockquote_border_width: 0 }, analyze: :line
    ____
    Let it be.
    ____
    EOS

    (expect pdf.lines).to be_empty
  end

  it 'should not draw left border on next page if block falls at bottom of page' do
    pdf_theme = {
      thematic_break_border_color: 'DDDDDD',
      thematic_break_margin_bottom: 669.75,
    }
    pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: :line
    filler

    ---

    ____
    Let it be.

    Let it be.
    ____

    Words of wisdom were spoken.
    EOS

    quote_borders = pdf.lines.select {|it| it[:color] == 'EEEEEE' }
    (expect quote_borders).to have_size 1
    (expect quote_borders[0][:page_number]).to eql 1
  end
end
