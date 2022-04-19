# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Verse' do
  it 'should show caption above block if title is specified' do
    input = <<~'EOS'
    .Fog
    [verse]
    ____
    The fog comes
    on little cat feet.
    ____
    EOS

    pdf = to_pdf input, analyze: :line
    lines = pdf.lines
    (expect pdf.lines).to have_size 1

    pdf = to_pdf input, analyze: true
    (expect pdf.lines).to eql ['Fog', 'The fog comes', 'on little cat feet.']
    title_text = (pdf.find_text 'Fog')[0]
    body_text = (pdf.find_text 'The fog comes')[0]
    (expect title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect title_text[:x]).to eql 48.24
    (expect title_text[:y]).to be > lines[0][:from][:y]
    (expect title_text[:x]).to be < lines[0][:from][:x]
    (expect lines[0][:from][:x]).to be < body_text[:x]
  end

  it 'should show attribution line below text of verse' do
    pdf = to_pdf <<~'EOS', analyze: true
    [verse,Robert Frost,'Fire & Ice']
    ____
    Some say the world will end in fire,
    Some say in ice.
    ____
    EOS

    last_verse_text = pdf.text[-2]
    attribution_text = (pdf.find_text %r/Robert Frost/)[0]
    (expect attribution_text[:string]).to eql %(\u2014 Robert Frost, Fire & Ice)
    (expect attribution_text[:font_size]).to eql 9
    (expect attribution_text[:font_color]).to eql '999999'
    (expect attribution_text[:font_name]).to eql 'NotoSerif'
    (expect (last_verse_text[:y] - attribution_text[:y]).round).to eql 27
    (expect attribution_text[:x]).to eql last_verse_text[:x]
  end

  it 'should expand tabs and preserve indentation' do
    pdf = to_pdf <<~EOS, analyze: true
    [verse]
    ____
    here
    \twe
    \t\tgo
    again
    ____
    EOS

    lines = pdf.lines
    (expect lines).to have_size 4
    (expect lines[1]).to eql %(\u00a0   we)
    (expect lines[2]).to eql %(\u00a0       go)
  end

  it 'should not draw left border if border_left_width is 0' do
    pdf = to_pdf <<~'EOS', pdf_theme: { verse_border_left_width: 0 }, analyze: :line
    [verse]
    ____
    here
    we
    go
    ____
    EOS

    (expect pdf.lines).to be_empty
  end

  it 'should not draw left border if border_left_width is nil' do
    pdf = to_pdf <<~'EOS', pdf_theme: { verse_border_left_width: nil, verse_border_width: nil }, analyze: :line
    [verse]
    ____
    here
    we
    go
    ____
    EOS

    (expect pdf.lines).to be_empty
  end

  it 'should be able to modify styles using verse category in theme' do
    pdf_theme = {
      verse_font_size: 10.5,
      verse_font_family: 'M+ 1mn',
      verse_font_color: '555555',
    }

    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    [verse]
    ____
    The fog comes
    on little cat feet.
    ____
    EOS

    text = pdf.text
    (expect text).to have_size 2
    (expect text[0][:font_name]).to eql 'mplus1mn-regular'
    (expect text[0][:font_size]).to eql 10.5
    (expect text[0][:font_color]).to eql '555555'
  end

  it 'should apply specified background color', visual: true do
    pdf_theme = {
      verse_background_color: 'dddddd',
      verse_border_color: 'aa0000',
    }
    to_file = to_pdf_file <<~'EOS', 'verse-background-color.pdf', pdf_theme: pdf_theme
    [verse]
    ____
    Let it be.
    Let it be.
    ____
    EOS

    (expect to_file).to visually_match 'verse-background-color.pdf'
  end

  it 'should apply specified border and background color', visual: true do
    pdf_theme = build_pdf_theme \
      verse_border_left_width: 0,
      verse_border_width: 0.5,
      verse_border_color: 'aa0000',
      verse_background_color: 'dddddd'
    pdf_theme.quote_padding = pdf_theme.sidebar_padding
    to_file = to_pdf_file <<~'EOS', 'verse-border-and-background-color.pdf', pdf_theme: pdf_theme
    [verse,Paul McCartney]
    ____
    Let it be.
    Let it be.
    ____
    EOS

    (expect to_file).to visually_match 'verse-border-and-background-color.pdf'
  end

  it 'should apply correct padding around content' do
    input = <<~'EOS'
    [verse]
    ____
    first

    last
    ____
    EOS

    pdf = to_pdf input, analyze: true
    lines = (to_pdf input, analyze: :line).lines
    (expect lines).to have_size 1
    top = lines[0][:from][:y]
    bottom = lines[0][:to][:y]
    left = lines[0][:from][:x]
    text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
    text_bottom = (pdf.find_unique_text 'last')[:y]
    text_left = (pdf.find_unique_text 'first')[:x]
    (expect (top - text_top).to_f).to be < 2
    (expect (text_bottom - bottom).to_f).to (be_within 1).of 8.0
    (expect (text_left - left).to_f).to eql 12.0
  end

  it 'should apply correct padding around content when using base theme' do
    input = <<~'EOS'
    [verse]
    ____
    first

    last
    ____
    EOS

    pdf = to_pdf input, attribute_overrides: { 'pdf-theme' => 'base' }, analyze: true
    lines = (to_pdf input, attribute_overrides: { 'pdf-theme' => 'base' }, analyze: :line).lines
    (expect lines).to have_size 1
    top = lines[0][:from][:y]
    bottom = lines[0][:to][:y]
    left = lines[0][:from][:x]
    text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
    text_bottom = (pdf.find_unique_text 'last')[:y]
    text_left = (pdf.find_unique_text 'first')[:x]
    (expect (top - text_top).to_f).to (be_within 2).of 8.0
    (expect (text_bottom - bottom).to_f).to (be_within 2).of 8.0
    (expect (text_left - left).to_f).to eql 12.0
  end

  it 'should split border when block is split across pages', visual: true do
    pdf_theme = {
      verse_border_left_width: 0,
      verse_border_width: 0.5,
      verse_border_color: 'CCCCCC',
      verse_background_color: 'EEEEEE',
      verse_padding: [6, 10, 12, 10],
    }
    to_file = to_pdf_file <<~EOS, 'verse-page-split.pdf', pdf_theme: pdf_theme
    [verse]
    ____
    #{(['Let it be.'] * 50).join ?\n}
    ____
    EOS

    (expect to_file).to visually_match 'verse-page-split.pdf'
  end
end
