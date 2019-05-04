require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Page Breaks' do
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
