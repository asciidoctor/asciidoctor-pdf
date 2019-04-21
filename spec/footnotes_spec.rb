require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Footnotes' do
  it 'should place footnotes at the end of each chapter when doctype is book' do
    pdf = to_pdf <<~'EOS', doctype: 'book', attributes: 'notitle nofooter', analyze: :text
    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.
    EOS

    strings = pdf.strings
    positions = pdf.positions
    font_settings = pdf.font_settings
    (expect (strings.slice 2, 3).join).to eql '[1]'
    # superscript
    (expect positions[3][1]).to be > positions[2][1]
    # superscript group
    (expect (positions.slice 3, 3).map {|p| p[1] }.uniq.size).to be 1
    (expect (font_settings.slice 2, 3).map {|f| f[:size] }.uniq.size).to be 1
    (expect font_settings[2][:size]).to be < font_settings[1][:size]
    # footnote item
    (expect (strings.slice 6, 3).join).to eql '[1] More about that thing.'
    (expect positions[8][1]).to be < positions[6][1]
    (expect positions[8][2]).to eql 1
    (expect (positions.slice 8, 3).map {|p| p[1] }.uniq.size).to eql 1
    (expect font_settings[6][:size]).to eql 8
    # next chapter
    (expect positions[11][2]).to eql 2
  end

  it 'should place footnotes at the end of document when doctype is not book' do
    pdf = to_pdf <<~'EOS', attributes: 'notitle nofooter', analyze: :text
    == Section A

    About this thing.footnote:[More about that thing.] And so on.

    <<<

    == Section B

    Yada yada yada.
    EOS

    strings = pdf.strings
    positions = pdf.positions
    font_settings = pdf.font_settings
    (expect (strings.slice 2, 3).join).to eql '[1]'
    # superscript
    (expect positions[3][1]).to be > positions[2][1]
    # superscript group
    (expect (positions.slice 3, 3).map {|p| p[1] }.uniq.size).to be 1
    (expect (font_settings.slice 2, 3).map {|f| f[:size] }.uniq.size).to be 1
    (expect font_settings[2][:size]).to be < font_settings[1][:size]
    # footnote item
    (expect strings.index 'Section B').to be < (strings.index '] More about that thing.')
    (expect (strings.slice -3, 3).join).to eql '[1] More about that thing.'
    (expect positions[-1][2]).to eql 2
    (expect font_settings[-1][:size]).to eql 8
  end
end
