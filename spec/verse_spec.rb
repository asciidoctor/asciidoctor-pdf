# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Verse' do
  it 'should show caption above block if title is specified' do
    pdf = to_pdf <<~'EOS', analyze: true
    .Fog
    [verse]
    ____
    The fog comes
    on little cat feet.
    ____
    EOS

    (expect pdf.lines).to eql ['Fog', 'The fog comes', 'on little cat feet.']
    title_text = (pdf.find_text 'Fog')[0]
    (expect title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect title_text[:x]).to eql 48.24
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
    pdf_theme.blockquote_padding = pdf_theme.sidebar_padding
    to_file = to_pdf_file <<~'EOS', 'verse-border-and-background-color.pdf', pdf_theme: pdf_theme
    [verse,Paul McCartney]
    ____
    Let it be.
    Let it be.
    ____
    EOS

    (expect to_file).to visually_match 'verse-border-and-background-color.pdf'
  end
end
