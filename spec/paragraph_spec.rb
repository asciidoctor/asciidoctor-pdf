# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Paragraph' do
  it 'should normalize newlines and whitespace' do
    pdf = to_pdf <<~EOS, analyze: true
    He's  a  real  nowhere  man,
    Sitting in his nowhere land,
    Making all his nowhere plans\tfor nobody.
    EOS
    (expect pdf.text).to have_size 1
    text = pdf.text[0][:string]
    (expect text).not_to include '  '
    (expect text).not_to include ?\t
    (expect text).not_to include ?\n
    (expect text).to include 'man, Sitting'
  end

  it 'should indent first line of paragraph if prose_text_indent key is set in theme' do
    pdf = to_pdf (lorem_ipsum '2-paragraphs'), pdf_theme: { prose_text_indent: 18 }, analyze: true

    (expect pdf.text).to have_size 4
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
  end

  it 'should not alter line height of wrapped lines when prose_text_indent is set in theme that uses a TTF font' do
    input = lorem_ipsum '4-sentences-2-paragraphs'

    pdf = to_pdf input, analyze: true

    last_line_y = pdf.text[-1][:y]

    pdf = to_pdf input, pdf_theme: { prose_text_indent: 18 }, analyze: true

    (expect pdf.text[-1][:y]).to eql last_line_y
  end

  it 'should not alter line height of wrapped lines when prose_text_indent is set in theme that uses an AFM font' do
    input = lorem_ipsum '4-sentences-2-paragraphs'

    pdf = to_pdf input, pdf_theme: { extends: 'base' }, analyze: true

    last_line_y = pdf.text[-1][:y]

    pdf = to_pdf input, pdf_theme: { extends: 'base', prose_text_indent: 18 }, analyze: true

    (expect pdf.text[-1][:y]).to eql last_line_y
  end

  it 'should use prose_margin_inner between paragraphs when prose-text_indent key is set in theme' do
    pdf = to_pdf <<~EOS, pdf_theme: { prose_text_indent: 18, prose_margin_inner: 0 }, analyze: true
    #{lorem_ipsum '2-sentences-2-paragraphs'}

    * list item
    EOS

    line_spacing = 1.upto(3).map {|i| (pdf.text[i - 1][:y] - pdf.text[i][:y]).round 2 }.uniq
    (expect line_spacing).to have_size 1
    (expect line_spacing[0]).to eql 15.78
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
    list_item_text = (pdf.find_text 'list item')[0]
    (expect (pdf.text[3][:y] - list_item_text[:y]).round 2).to eql 27.78
  end

  it 'should allow text alignment to be controlled using text-align document attribute' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    :text-align: right

    right-aligned
    EOS

    center_x = (pdf.page 1)[:size][1] / 2
    paragraph_text = (pdf.find_text 'right-aligned')[0]
    (expect paragraph_text[:x]).to be > center_x
  end

  it 'should output block title for paragraph if specified' do
    pdf = to_pdf <<~'EOS', analyze: true
    .Disclaimer
    All views expressed are my own.
    EOS

    (expect pdf.lines).to eql ['Disclaimer', 'All views expressed are my own.']
    disclaimer_text = (pdf.find_text 'Disclaimer')[0]
    (expect disclaimer_text[:font_name]).to eql 'NotoSerif-Italic'
  end
end
