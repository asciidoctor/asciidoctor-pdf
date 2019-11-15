require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Hyphenate' do
  it 'should hyphenate text in paragraph if hyphenate attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphenate:

    This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to eql 1
  end

  it 'should hyphenate text split across multiple lines' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphenate:

    This story chronicles the
    inexplicable hazards and
    vicious beasts a team must
    conquer and vanquish.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to eql 1
  end

  it 'should hyphenate text in table cell if hyphenate attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphenate:

    |===
    |This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    |===
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to eql 1
  end

  it 'should hyphenate text in a list item if hyphenate attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphenate:

    * This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to eql 1
  end

  it 'should hyphenate formatted word' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphenate:

    This story chronicles the inexplicable hazards and vicious beasts a team must conquer and *vanquish* on the journey to discover the true power of Open Source.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to eql 1
    bold_texts = pdf.find_text font_name: 'NotoSerif-Bold'
    (expect bold_texts).to have_size 2
    (expect bold_texts[0][:string]).to eql %(van\u00ad)
    (expect bold_texts[1][:string]).to eql 'quish'
    (expect bold_texts[1][:y]).to be < bold_texts[0][:y]
  end

  it 'should not mangle formatting when hyphenating text' do
    (expect {
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font
      :hyphenate:

      This story chronicles the inexplicable icon:biohazard@fas[] and vicious icon:paw@fas[] teams must conquer on the journey to discover the true power of Open Source.
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0]).to end_with ?\u00ad
      (expect lines[0].count ?\u00ad).to eql 1
      (expect lines[0]).to include ?\uf780
      (expect lines[0]).to include ?\uf1b0
    }).to not_log_message
  end

  it 'should set hyphenation language based on value of hyphenate attribute' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphenate: DE

    Mitwirkende sind immer willkommen.
    Neue Mitwirkende sind immer willkommen!
    Wenn Sie Fehler oder Auslassungen im Quellcode, in der Dokumentation oder im Inhalt der Website entdecken, zögern Sie bitte nicht, ein Problem zu melden oder eine Pull Request mit einem Fix zu öffnen.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to eql 1
  end

  it 'should set hyphenation language based on value of lang attribute if value of hyphenate attribute is empty' do
    pdf = to_pdf <<~'EOS', analyze: true
    :lang: DE
    :hyphenate:

    Mitwirkende sind immer willkommen.
    Neue Mitwirkende sind immer willkommen!
    Wenn Sie Fehler oder Auslassungen im Quellcode, in der Dokumentation oder im Inhalt der Website entdecken, zögern Sie bitte nicht, ein Problem zu melden oder eine Pull Request mit einem Fix zu öffnen.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to eql 1
  end

  it 'should show visible hyphen at locate where word is split across lines', visual: true do
    to_file = to_pdf_file <<~'EOS', 'hyphenate-word-break.pdf'
    :hyphenate:

    This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    EOS

    (expect to_file).to visually_match 'hyphenate-word-break.pdf'
  end
end
