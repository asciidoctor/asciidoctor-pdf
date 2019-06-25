require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Paragraph' do
  it 'should normalize whitespace' do
    pdf = to_pdf <<~EOS, analyze: true
    He's  a  real  nowhere  man,
    Sitting in his nowhere land,
    Making all his nowhere plans\tfor nobody.
    EOS
    text = pdf.text
    (expect text).to have_size 1
    (expect text).not_to include '  '
    (expect text).not_to include ?\t
    (expect text).not_to include ?\n
  end

  it 'should indent first line of paragraph if prose_text_indent key is set in theme' do
    pdf = to_pdf (lorem_ipsum '2-paragraphs'), pdf_theme: { prose_text_indent: 18 }, analyze: true

    (expect pdf.text).to have_size 4
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
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

  it 'should not alter line height of wrapped lines when prose_text_indent is set in theme' do
    input = lorem_ipsum '4-sentences-2-paragraphs'

    pdf = to_pdf input, analyze: true

    last_line_y = pdf.text[-1][:y]

    pdf = to_pdf input, pdf_theme: { prose_text_indent: 18 }, analyze: true

    (expect pdf.text[-1][:y]).to eql last_line_y
  end

  it 'should indent first line of abstract if prose_text_indent key is set in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: { prose_text_indent: 18 }, analyze: true
    = Document Title

    [abstract]
    This document is configured to have indented paragraphs.
    This option is controlled by the prose_text_indent key in the theme.

    And on it goes.
    EOS

    (expect pdf.text[1][:string]).to start_with 'This document'
    (expect pdf.text[1][:x]).to be > pdf.text[2][:x]
    (expect pdf.text[3][:string]).to eql 'And on it goes.'
  end

  it 'should decorate first line of abstract when abstract has multiple lines' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract]
    First line of abstract. +
    Second line of abstract.

    == Section

    content
    EOS

    abstract_text_line1 = pdf.find_text 'First line of abstract.'
    abstract_text_line2 = pdf.find_text 'Second line of abstract.'
    (expect abstract_text_line1).to have_size 1
    (expect abstract_text_line1[0][:order]).to eql 2
    (expect abstract_text_line1[0][:font_name]).to include 'BoldItalic'
    (expect abstract_text_line2).to have_size 1
    (expect abstract_text_line2[0][:order]).to eql 3
    (expect abstract_text_line2[0][:font_name]).not_to include 'BoldItalic'
    
  end

  it 'should decorate first line of abstract when abstract has single line' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract]
    First and only line of abstract.

    == Section

    content
    EOS

    abstract_text = pdf.find_text 'First and only line of abstract.'
    (expect abstract_text).to have_size 1
    (expect abstract_text[0][:order]).to eql 2
    (expect abstract_text[0][:font_name]).to include 'BoldItalic'
  end
end
