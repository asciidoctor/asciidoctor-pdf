require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Footnotes' do
  it 'should place footnotes at the end of each chapter when doctype is book' do
    pdf = to_pdf <<~'EOS', doctype: 'book', attributes: 'notitle nofooter', analyze: :text
    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.
    EOS

    strings, text = pdf.strings, pdf.text
    (expect (strings.slice 2, 3).join).to eql '[1]'
    # superscript
    (expect text[2][:y]).to be > text[1][:y]
    (expect text[2][:font_size]).to be < text[1][:font_size]
    (expect text[3][:font_color]).to eql '428BCA'
    # superscript group
    (expect (text.slice 2, 3).map {|it| [it[:y], it[:font_size]] }.uniq.size).to be 1
    # footnote item
    (expect (strings.slice 6, 3).join).to eql '[1] More about that thing.'
    (expect text[6][:y]).to be < text[5][:y]
    (expect text[6][:page_number]).to eql 1
    (expect text[6][:font_size]).to eql 8
    (expect (text.slice 6, 3).map {|it| [it[:y], it[:font_size]] }.uniq.size).to eql 1
    # next chapter
    (expect text[9][:page_number]).to eql 2
  end

  it 'should place footnotes at the end of document when doctype is not book' do
    pdf = to_pdf <<~'EOS', attributes: 'notitle nofooter', analyze: :text
    == Section A

    About this thing.footnote:[More about that thing.] And so on.

    <<<

    == Section B

    Yada yada yada.
    EOS

    strings, text = pdf.strings, pdf.text
    (expect (strings.slice 2, 3).join).to eql '[1]'
    # superscript
    (expect text[2][:y]).to be > text[1][:y]
    (expect text[2][:font_size]).to be < text[1][:font_size]
    (expect text[3][:font_color]).to eql '428BCA'
    # superscript group
    (expect (text.slice 2, 3).map {|it| [it[:y], it[:font_size]] }.uniq.size).to be 1
    (expect text[2][:font_size]).to be < text[1][:font_size]
    # footnote item
    (expect (pdf.find_text 'Section B')[0][:order]).to be < (pdf.find_text '] More about that thing.')[0][:order]
    (expect (strings.slice -3, 3).join).to eql '[1] More about that thing.'
    (expect text[-1][:page_number]).to eql 2
    (expect text[-1][:font_size]).to eql 8
  end
end
