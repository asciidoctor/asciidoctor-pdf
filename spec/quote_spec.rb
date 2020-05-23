# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Quote' do
  it 'should show caption above block if title is specified' do
    input = <<~'EOS'
    .Words of wisdom
    ____
    Let it be.
    ____
    EOS

    pdf = to_pdf input, analyze: :line
    lines = pdf.lines
    (expect pdf.lines).to have_size 1

    pdf = to_pdf input, analyze: true
    (expect pdf.lines).to eql ['Words of wisdom', 'Let it be.']
    title_text = (pdf.find_text 'Words of wisdom')[0]
    body_text = (pdf.find_text 'Let it be.')[0]
    (expect title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect title_text[:x]).to eql 48.24
    (expect title_text[:y]).to be > lines[0][:from][:y]
    (expect title_text[:x]).to be < lines[0][:from][:x]
    (expect lines[0][:from][:x]).to be < body_text[:x]
  end

  it 'should show attribution line below text of quote' do
    pdf = to_pdf <<~'EOS', analyze: true
    [,Alice Walker,Speech]
    ____
    The most common way people give up their power is by thinking they don't have any.
    ____
    EOS

    last_quote_text = pdf.text[-2]
    attribution_text = (pdf.find_text %r/Alice Walker/)[0]
    (expect attribution_text[:string]).to eql %(\u2014 Alice Walker, Speech)
    (expect attribution_text[:font_size]).to eql 9
    (expect attribution_text[:font_color]).to eql '999999'
    (expect attribution_text[:font_name]).to eql 'NotoSerif'
    (expect (last_quote_text[:y] - attribution_text[:y]).round).to eql 27
    (expect attribution_text[:x]).to eql last_quote_text[:x]
  end

  it 'should escape bare ampersand in attribution' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      [quote, J. Helliwell & B. McMahon]
      The richer the metadata available to the scientist, the greater the potential for new discoveries.
      EOS

      (expect pdf.lines[-1]).to eql %(\u2014 J. Helliwell & B. McMahon)
    end).to not_log_message
  end

  it 'should escape bare ampersand in citetitle' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      [quote, J. Helliwell & B. McMahon, Melbourne Congress & General Assembly of the IUCr]
      The richer the metadata available to the scientist, the greater the potential for new discoveries.
      EOS

      (expect pdf.lines[-1]).to eql %(\u2014 J. Helliwell & B. McMahon, Melbourne Congress & General Assembly of the IUCr)
    end).to not_log_message
  end

  it 'should render character reference in attribute if enclosed in single quotes' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      [quote, J. Helliwell & B. McMahon &#169; IUCr]
      The richer the metadata available to the scientist, the greater the potential for new discoveries.
      EOS

      (expect pdf.lines[-1]).to eql %(\u2014 J. Helliwell & B. McMahon \u00a9 IUCr)
    end).to not_log_message
  end

  it 'should not draw left border if border_left_width is 0' do
    pdf = to_pdf <<~'EOS', pdf_theme: { blockquote_border_left_width: 0 }, analyze: :line
    ____
    Let it be.
    ____
    EOS

    (expect pdf.lines).to be_empty
  end

  it 'should not draw left border if border_left_width is nil' do
    pdf = to_pdf <<~'EOS', pdf_theme: { blockquote_border_left_width: nil, blockquote_border_width: nil }, analyze: :line
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
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
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
    (expect quote_borders[0][:page_number]).to be 1
  end

  it 'should apply specified background color', visual: true do
    pdf_theme = {
      blockquote_background_color: 'dddddd',
      blockquote_border_color: 'aa0000',
    }
    to_file = to_pdf_file <<~'EOS', 'quote-background-color.pdf', pdf_theme: pdf_theme
    ____
    Let it be. +
    Let it be.
    ____
    EOS

    (expect to_file).to visually_match 'quote-background-color.pdf'
  end

  it 'should apply specified border and background color', visual: true do
    pdf_theme = build_pdf_theme \
      blockquote_border_left_width: 0,
      blockquote_border_width: 0.5,
      blockquote_border_color: 'aa0000',
      blockquote_background_color: 'dddddd'
    pdf_theme.blockquote_padding = pdf_theme.sidebar_padding
    to_file = to_pdf_file <<~'EOS', 'quote-border-and-background-color.pdf', pdf_theme: pdf_theme
    [,Paul McCartney]
    ____
    Let it be. +
    Let it be.
    ____
    EOS

    (expect to_file).to visually_match 'quote-border-and-background-color.pdf'
  end

  it 'should split border when block is split across pages', visual: true do
    pdf_theme = {
      blockquote_border_left_width: 0,
      blockquote_border_width: 0.5,
      blockquote_border_color: 'CCCCCC',
      blockquote_background_color: 'EEEEEE',
      blockquote_padding: [6, 10, 0, 10],
    }
    to_file = to_pdf_file <<~EOS, 'quote-page-split.pdf', pdf_theme: pdf_theme
    ____
    #{(['Let it be.'] * 30).join %(\n\n)}
    ____
    EOS

    (expect to_file).to visually_match 'quote-page-split.pdf'
  end
end
