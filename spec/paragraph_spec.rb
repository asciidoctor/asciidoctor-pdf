require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Paragraph' do
  it 'should normalize whitespace' do
    pdf = to_pdf <<~EOS, analyze: true
    He's  a  real  nowhere  man,
    Sitting in his nowhere land,
    Making all his nowhere plans\tfor nobody.
    EOS
    text = pdf.text
    (expect text.size).to eql 1
    (expect text).not_to include '  '
    (expect text).not_to include ?\t
    (expect text).not_to include ?\n
  end

  it 'should indent first line of paragraph if prose_text_indent key is set in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme prose_text_indent: 18), analyze: true
    Unix cat buffer.
    I'm sorry Dave, I'm afraid I can't do that.
    Race condition bang endif linux L0phtCrack fork gnu int long stdio.h unix memory leak fail try catch void.

    Hack the mainframe segfault for hexadecimal private deadlock echo linux float stack alloc brute force tcp false packet.
    All your base are belong to us.
    EOS

    (expect pdf.text.size).to eql 4
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
  end

  it 'should use prose_margin_inner between paragraphs when prose-text_indent key is set in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme prose_text_indent: 18, prose_margin_inner: 0), analyze: true
    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

    * list item
    EOS

    line_spacing = 1.upto(3).map {|i| (pdf.text[i - 1][:y] - pdf.text[i][:y]).round 2 }.uniq
    (expect line_spacing.size).to eql 1
    (expect line_spacing[0]).to eql 15.78
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
    list_item_text = (pdf.find_text 'list item')[0]
    (expect (pdf.text[3][:y] - list_item_text[:y]).round 2).to eql 27.78
  end

  it 'should not alter line height of wrapped lines when prose_text_indent is set in theme' do
    pdf = to_pdf <<~'EOS', analyze: true
    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
    EOS

    last_line_y = pdf.text[-1][:y]

    pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme prose_text_indent: 18), analyze: true
    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
    EOS

    (expect pdf.text[-1][:y]).to eql last_line_y
  end

  it 'should indent first line of abstract if prose_text_indent key is set in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme prose_text_indent: 18), analyze: true
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
end
