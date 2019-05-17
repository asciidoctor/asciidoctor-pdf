require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Sections' do
  it 'should apply font size according to section level' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    == Level 1

    === Level 2

    section content

    == Back To Level 1
    EOS

    expected_text = [
      ['Document Title', 27],
      ['Level 1', 22],
      ['Level 2', 18],
      ['section content', 10.5],
      ['Back To Level 1', 22],
    ]
    (expect pdf.text.map {|it| it.values_at :string, :font_size }).to eql expected_text
  end

  it 'should render section titles in bold by default' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    == Level 1

    === Level 2

    section content

    == Back To Level 1
    EOS

    expected_text = [
      ['Document Title', 'NotoSerif-Bold'],
      ['Level 1', 'NotoSerif-Bold'],
      ['Level 2', 'NotoSerif-Bold'],
      ['section content', 'NotoSerif'],
      ['Back To Level 1', 'NotoSerif-Bold'],
    ]
    (expect pdf.text.map {|it| it.values_at :string, :font_name }).to eql expected_text
  end

  it 'should not promote anonymous preface in book doctype to preface section if preface-title attribute is not set' do
    input = <<~'EOS'
    = Book Title
    :doctype: book

    anonymous preface

    == First Chapter

    chapter content
    EOS

    pdf = to_pdf input
    names = get_names pdf
    (expect names.keys).not_to include '_preface'

    text = (to_pdf input, analyze: true).text
    (expect text[1][:string]).to eql 'anonymous preface'
    (expect text[1][:font_size]).to eql 13
  end

  # QUESTION is this the right behavior? should the value default to Preface instead?
  it 'should not promote anonymous preface in book doctype to preface section if preface-title attribute is empty' do
    input = <<~'EOS'
    = Book Title
    :doctype: book
    :preface-title:

    anonymous preface

    == First Chapter

    chapter content
    EOS

    pdf = to_pdf input
    names = get_names pdf
    (expect names.keys).not_to include '_preface'

    text = (to_pdf input, analyze: true).text
    (expect text[1][:string]).to eql 'anonymous preface'
    (expect text[1][:font_size]).to eql 13
  end

  it 'should promote anonymous preface in book doctype to preface section if preface-title attribute is non-empty' do
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

    text = (to_pdf input, analyze: true).text
    (expect text[1][:string]).to eql 'Prelude'
    (expect text[1][:font_size]).to eql 22
    (expect text[2][:string]).to eql 'anonymous preface'
    (expect text[2][:font_size]).to eql 10.5
  end
end
