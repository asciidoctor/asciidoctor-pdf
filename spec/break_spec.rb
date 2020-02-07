# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Break' do
  context 'Line Breaks' do
    it 'should place text on separate line after explicit line break' do
      pdf = to_pdf <<~'EOS', analyze: true
      foo +
      bar +
      baz
      EOS

      (expect pdf.lines).to eql %w(foo bar baz)
    end

    it 'should preserve newlines in paragraph with hardbreaks option' do
      pdf = to_pdf <<~'EOS', analyze: true
      [%hardbreaks]
      foo
      bar
      baz
      EOS

      (expect pdf.lines).to eql %w(foo bar baz)
    end
  end

  context 'Thematic Breaks' do
    it 'should draw line for thematic break' do
      input = <<~'EOS'
      before

      '''

      after
      EOS

      pdf = to_pdf input, analyze: true

      before_text = (pdf.find_text 'before')[0]
      after_text = (pdf.find_text 'after')[0]

      pdf = to_pdf input, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      line = lines[0]
      (expect line[:color]).to eql 'EEEEEE'
      (expect line[:width]).to eql 0.5
      (expect line[:from][:x]).to be < line[:to][:x]
      (expect line[:from][:y]).to eql line[:to][:y]
      (expect line[:from][:y]).to be < before_text[:y]
      (expect line[:from][:y]).to be > after_text[:y]
    end
  end

  context 'Page Breaks' do
    it 'should advance to next page after page break' do
      pdf = to_pdf <<~'EOS', analyze: :page
      foo

      <<<

      bar
      EOS

      (expect pdf.pages).to have_size 2
      (expect pdf.pages[0][:strings]).to include 'foo'
      (expect pdf.pages[1][:strings]).to include 'bar'
    end

    it 'should not advance to next page if at start of document' do
      pdf = to_pdf <<~'EOS', analyze: :page
      <<<

      foo
      EOS

      (expect pdf.pages).to have_size 1
    end

    it 'should not advance to next page if preceding content forced a new page to be started' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Book Title
      :doctype: book

      = Part

      <<<

      == Chapter
      EOS

      part_text = (pdf.find_text 'Part')[0]
      (expect part_text[:page_number]).to be 2
      chapter_text = (pdf.find_text 'Chapter')[0]
      (expect chapter_text[:page_number]).to be 3
    end

    it 'should not advance to next page if preceding content advanced page' do
      pdf = to_pdf <<~EOS, analyze: true
      ....
      #{(['filler'] * 50).join ?\n}
      ....

      start of page
      EOS

      start_of_page_text = (pdf.find_text 'start of page')[0]
      (expect start_of_page_text[:page_number]).to be 2
    end

    it 'should not leave blank page at the end of document' do
      input = <<~'EOS'
      foo

      <<<
      EOS

      [
        {},
        { page_background_color: 'eeeeee' },
        { page_background_image: %(image:#{fixture_file 'square.svg'}[]) },
      ].each do |theme_overrides|
        pdf = to_pdf input, pdf_theme: theme_overrides, analyze: :page
        (expect pdf.pages).to have_size 1
      end
    end

    it 'should change layout if page break specifies page-layout attribute' do
      pdf = to_pdf <<~'EOS', analyze: true
      portrait

      [page-layout=landscape]
      <<<

      landscape
      EOS

      text = pdf.text
      (expect text).to have_size 2
      (expect text[0].values_at :string, :page_number, :x, :y).to eql ['portrait', 1, 48.24, 793.926]
      (expect text[1].values_at :string, :page_number, :x, :y).to eql ['landscape', 2, 48.24, 547.316]
    end

    it 'should change layout if page break specifies layout role' do
      pdf = to_pdf <<~'EOS', analyze: true
      portrait

      [.landscape]
      <<<

      landscape
      EOS

      text = pdf.text
      (expect text).to have_size 2
      (expect text[0].values_at :string, :page_number, :x, :y).to eql ['portrait', 1, 48.24, 793.926]
      (expect text[1].values_at :string, :page_number, :x, :y).to eql ['landscape', 2, 48.24, 547.316]
    end

    it 'should switch layout each time page break specifies layout role' do
      pdf = to_pdf <<~'EOS', analyze: true
      portrait

      [.landscape]
      <<<

      landscape

      [.portrait]
      <<<

      portrait

      [.landscape]
      <<<

      landscape
      EOS

      portrait_text = pdf.find_text 'portrait'
      (expect portrait_text).to have_size 2
      portrait_text.each do |text|
        page = pdf.page text[:page_number]
        (expect page[:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
      end

      landscape_text = pdf.find_text 'landscape'
      (expect landscape_text).to have_size 2
      landscape_text.each do |text|
        page = pdf.page text[:page_number]
        (expect page[:size]).to eql PDF::Core::PageGeometry::SIZES['A4'].reverse
      end
    end

    it 'should switch layout specified by page break even when it falls at a natural page break' do
      pdf = to_pdf <<~EOS, analyze: true
      portrait

      [.landscape]
      <<<

      #{%(landscape +\n) * 31}landscape

      [.portrait]
      <<<

      portrait
      EOS

      (expect (pdf.page 3)[:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
    end
  end
end
