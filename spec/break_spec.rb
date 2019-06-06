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
      (expect pdf.widths.size).to eql 1
      (expect pdf.points.size).to eql 2
      (expect pdf.widths[0]).to eql 0.5
      (expect pdf.points[0][1]).to be < before_text[:y]
      (expect pdf.points[0][1]).to be > after_text[:y]
    end
  end

  context 'Page Breaks' do
    it 'should advance to next page after page break' do
      pdf = to_pdf <<~'EOS', analyze: :page
      foo

      <<<

      bar
      EOS

      (expect pdf.pages.size).to eql 2
      (expect pdf.pages[0][:strings]).to include 'foo'
      (expect pdf.pages[1][:strings]).to include 'bar'
    end

    it 'should not advance to next page if already at top of page' do
      pdf = to_pdf <<~'EOS', analyze: :page
      <<<

      foo
      EOS

      (expect pdf.pages.size).to eql 1
    end

    it 'should not leave blank page at the end of document' do
      pdf = to_pdf <<~'EOS', analyze: :page
      foo

      <<<
      EOS

      (expect pdf.pages.size).to eql 1
    end

    it 'should change layout if page break specifies page-layout attribute' do
      pdf = to_pdf <<~'EOS', analyze: true
      portrait

      [page-layout=landscape]
      <<<

      landscape
      EOS

      text = pdf.text
      (expect text.size).to eql 2
      (expect text[0].values_at :string, :page_number, :x, :y).to eq ['portrait', 1, 48.24, 793.926]
      (expect text[1].values_at :string, :page_number, :x, :y).to eq ['landscape', 2, 48.24, 547.316]
    end

    it 'should change layout if page break specifies layout role' do
      pdf = to_pdf <<~'EOS', analyze: true
      portrait

      [.landscape]
      <<<

      landscape
      EOS

      text = pdf.text
      (expect text.size).to eql 2
      (expect text[0].values_at :string, :page_number, :x, :y).to eq ['portrait', 1, 48.24, 793.926]
      (expect text[1].values_at :string, :page_number, :x, :y).to eq ['landscape', 2, 48.24, 547.316]
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
      (expect portrait_text.size).to eql 2
      portrait_text.each do |text|
        page = pdf.page text[:page_number]
        (expect page[:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
      end

      landscape_text = pdf.find_text 'landscape'
      (expect landscape_text.size).to eql 2
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
