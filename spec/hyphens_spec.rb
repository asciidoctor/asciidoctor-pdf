# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Hyphens' do
  it 'should hyphenate text in paragraph if hyphens attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphens:

    This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
  end

  it 'should hyphenate text split across multiple lines' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphens:

    This story chronicles the
    inexplicable hazards and
    vicious beasts a team must
    conquer and vanquish.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
  end

  it 'should not hyphenate a hyphen' do
    input = (['domain-driven design'] * 6).join ' '
    pdf = to_pdf input, attribute_overrides: { 'hyphens' => '' }, analyze: true
    (expect pdf.lines[0]).to end_with '-'
  end

  it 'should hyphenate text in table cell in table head if hyphens attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphens:
    :pdf-page-size: A7

    [%header]
    |===
    |This story chronicles the inexplicable hazards and tremendously vicious beasts the team must conquer and vanquish.
    |===
    EOS

    lines = pdf.lines
    (expect lines.size).to be > 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[1]).to end_with ?\u00ad
    (expect pdf.text[0][:font_name]).to eql 'NotoSerif-Bold'
  end

  it 'should hyphenate text in table cell in table body if hyphens attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphens:

    |===
    |This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    |===
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
  end

  it 'should hyphenate text in a list item if hyphens attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphens:

    * This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
  end

  it 'should hyphenate formatted word' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphens:

    This story chronicles the inexplicable hazards and vicious beasts a team must conquer and *vanquish* on the journey to discover the true power of Open Source.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
    bold_texts = pdf.find_text font_name: 'NotoSerif-Bold'
    (expect bold_texts).to have_size 2
    (expect bold_texts[0][:string]).to eql %(van\u00ad)
    (expect bold_texts[1][:string]).to eql 'quish'
    (expect bold_texts[1][:y]).to be < bold_texts[0][:y]
  end

  it 'should not mangle formatting when hyphenating text' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font
      :hyphens:

      This story chronicles the inexplicable icon:biohazard@fas[] and vicious icon:paw@fas[] teams must conquer on the journey to discover the true power of Open Source.
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0]).to end_with ?\u00ad
      (expect lines[0].count ?\u00ad).to be 1
      (expect lines[0]).to include ?\uf780
      (expect lines[0]).to include ?\uf1b0
    end).to not_log_message
  end

  it 'should set hyphenation language based on value of hyphens attribute' do
    pdf = to_pdf <<~'EOS', analyze: true
    :hyphens: DE

    Mitwirkende sind immer willkommen.
    Neue Mitwirkende sind immer willkommen!
    Wenn Sie Fehler oder Auslassungen im Quellcode, in der Dokumentation oder im Inhalt der Website entdecken, zögern Sie bitte nicht, ein Problem zu melden oder eine Pull Request mit einem Fix zu öffnen.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
  end

  it 'should set hyphenation language based on value of lang attribute if value of hyphens attribute is empty' do
    pdf = to_pdf <<~'EOS', analyze: true
    :lang: DE
    :hyphens:

    Mitwirkende sind immer willkommen.
    Neue Mitwirkende sind immer willkommen!
    Wenn Sie Fehler oder Auslassungen im Quellcode, in der Dokumentation oder im Inhalt der Website entdecken, zögern Sie bitte nicht, ein Problem zu melden oder eine Pull Request mit einem Fix zu öffnen.
    EOS

    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
  end

  it 'should apply hyphenation when line is advanced to next page' do
    pdf = to_pdf <<~'EOS', pdf_theme: { prose_margin_top: 700 }, analyze: true
    = Document Title
    :hyphens:

    foobarfoobarfoobarfoobarfoobarfoobarfoobarfoobarfoobarfoobarfoobarfoobarfoobarfoobar paragraph
    EOS

    lines = pdf.lines pdf.find_text page_number: 2
    (expect lines).to have_size 2
    (expect lines[0]).to end_with %( para\u00ad)
    (expect lines[1]).to eql 'graph'
  end

  it 'should show visible hyphen at locate where word is split across lines', visual: true do
    to_file = to_pdf_file <<~'EOS', 'hyphens-word-break.pdf'
    :hyphens:

    This story chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish.
    EOS

    (expect to_file).to visually_match 'hyphens-word-break.pdf'
  end
end unless (Gem::Specification.stubs_for 'text-hyphen').empty?
