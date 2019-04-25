require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Sections' do
  it 'should apply font size according to section level' do
    pdf = to_pdf <<~'EOS', analyze: :text
    = Document Title

    == Level 1

    === Level 2

    section content

    == Back To Level 1
    EOS

    (expect pdf.strings).to eql ['Document Title', 'Level 1', 'Level 2', 'section content', 'Back To Level 1']
    (expect pdf.text.map {|it| it[:font_size] }).to eql [27, 22, 18, 10.5, 22]
  end

  it 'should promote anonymous preface in book doctype to preface section if preface-title attribute is set' do
    input = <<~'EOS'
    = Book Title
    :doctype: book
    :preface-title: Prelude

    anonymous preface

    == First Chapter

    chapter content
    EOS

    pdf = to_pdf input
    names = get_names pdf
    (expect names.keys).to include '_prelude'
    (expect pdf.objects[names['_prelude']][3]).to eql (get_page_size pdf, 2)[1]

    text = (to_pdf input, analyze: :text).text
    (expect text[1][:string]).to eql 'Prelude'
    (expect text[1][:font_size]).to eql 22
    (expect text[2][:string]).to eql 'anonymous preface'
    (expect text[2][:font_size]).to eql 10.5
  end
end
