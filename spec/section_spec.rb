require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Section' do
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

  it 'should add destination for each section' do
    pdf = to_pdf <<~'EOS'
    = Document Title

    == Level 1

    === Level 2

    ==== Level 3

    ===== Level 4
    EOS

    names = get_names pdf
    (expect names).to include '_level_1'
    (expect names).to include '_level_2'
    (expect names).to include '_level_3'
    (expect names).to include '_level_4'
  end

  it 'should add default chapter signifier to chapter title if section numbering is enabled' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Book Title
    :doctype: book
    :sectnums:

    == The Beginning

    == The End
    EOS

    chapter_titles = (pdf.find_text font_size: 22).map {|it| it[:string] }
    (expect chapter_titles).to eql ['Chapter 1. The Beginning', 'Chapter 2. The End']
  end

  it 'should add chapter signifier to chapter title if section numbering is enabled and chapter-signifier attribute is set' do
    # NOTE chapter-label is the legacy name
    { 'chapter-label' => 'Ch', 'chapter-signifier' => 'Ch' }.each do |attr_name, attr_val|
      pdf = to_pdf <<~EOS, analyze: true
      = Book Title
      :doctype: book
      :sectnums:
      :#{attr_name}: #{attr_val}

      == The Beginning

      == The End
      EOS

      chapter_titles = (pdf.find_text font_size: 22).map {|it| it[:string] }
      (expect chapter_titles).to eql ['Ch 1. The Beginning', 'Ch 2. The End']
    end
  end

  it 'should not add chapter label to chapter title if section numbering is enabled and chapter-signifier attribute is empty' do
    # NOTE chapter-label is the legacy name
    %w(chapter-label chapter-signifier).each do |attr_name|
      pdf = to_pdf <<~EOS, analyze: true
      = Book Title
      :doctype: book
      :sectnums:
      :#{attr_name}:

      == The Beginning

      == The End
      EOS

      chapter_titles = (pdf.find_text font_size: 22).map {|it| it[:string] }
      (expect chapter_titles).to eql ['1. The Beginning', '2. The End']
    end
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
