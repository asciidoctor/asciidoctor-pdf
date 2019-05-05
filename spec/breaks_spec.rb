require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Breaks' do
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
  end
end
