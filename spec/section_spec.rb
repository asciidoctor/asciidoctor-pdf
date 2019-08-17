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

  it 'should uppercase section titles if text_transform key in theme is set to uppercase' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_text_transform: :uppercase }, analyze: true
    = Document Title

    == Beginning

    == Middle

    == End
    EOS

    pdf.text.each do |text|
      (expect text[:string]).to eql text[:string].upcase
    end
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

  it 'should add part signifier and part number to part if part numbering is enabled' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Book Title
    :doctype: book
    :sectnums:
    :partnums:

    = A

    == Foo

    = B

    == Bar
    EOS

    titles = (pdf.find_text font_size: 27).map {|it| it[:string] }.reject {|it| it == 'Book Title' }
    (expect titles).to eql ['Part I: A', 'Part II: B']
  end if asciidoctor_2_or_better?

  it 'should use specified part signifier if part numbering is enabled and part-signifier attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Book Title
    :doctype: book
    :sectnums:
    :partnums:
    :part-signifier: P

    = A

    == Foo

    = B

    == Bar
    EOS

    titles = (pdf.find_text font_size: 27).map {|it| it[:string] }.reject {|it| it == 'Book Title' }
    (expect titles).to eql ['P I: A', 'P II: B']
  end if asciidoctor_2_or_better?

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

  it 'should not force title of empty section to next page if it fits on page' do
    pdf = to_pdf <<~EOS, analyze: true
    == Section A

    [%hardbreaks]
    #{(['filler'] * 41).join ?\n}

    == Section B
    EOS

    section_b_text = (pdf.find_text 'Section B')[0]
    (expect section_b_text[:page_number]).to eql 1
  end

  it 'should force section title to next page to keep with first line of section content' do
    pdf = to_pdf <<~EOS, analyze: true
    == Section A

    [%hardbreaks]
    #{(['filler'] * 41).join ?\n}

    == Section B

    content
    EOS

    section_b_text = (pdf.find_text 'Section B')[0]
    (expect section_b_text[:page_number]).to eql 2
    content_text = (pdf.find_text 'content')[0]
    (expect content_text[:page_number]).to eql 2
  end

  it 'should not force section title to next page to keep with content if heading_min_height_after is zero' do
    pdf = to_pdf <<~EOS, pdf_theme: { heading_min_height_after: 0 }, analyze: true
    == Section A

    [%hardbreaks]
    #{(['filler'] * 41).join ?\n}

    == Section B

    content
    EOS

    section_b_text = (pdf.find_text 'Section B')[0]
    (expect section_b_text[:page_number]).to eql 1
    content_text = (pdf.find_text 'content')[0]
    (expect content_text[:page_number]).to eql 2
  end

  it 'should not add break before chapter if break-before key in theme is auto' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_chapter_break_before: 'auto' }, analyze: true
    = Document Title
    :doctype: book

    == Chapter A

    == Chapter B
    EOS

    chapter_a_text = (pdf.find_text 'Chapter A')[0]
    chapter_b_text = (pdf.find_text 'Chapter B')[0]
    (expect chapter_a_text[:page_number]).to eql 2
    (expect chapter_b_text[:page_number]).to eql 2
  end

  it 'should not add break before part if break-before key in theme is auto' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_part_break_before: 'auto', heading_chapter_break_before: 'auto' }, analyze: true
    = Document Title
    :doctype: book

    = Part I

    == Chapter in Part I

    = Part II

    == Chapter in Part II
    EOS

    part_1_text = (pdf.find_text 'Part I')[0]
    part_2_text = (pdf.find_text 'Part II')[0]
    (expect part_1_text[:page_number]).to eql 2
    (expect part_2_text[:page_number]).to eql 2
  end

  it 'should add break after part if break-after key in theme is always' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_part_break_after: 'always', heading_chapter_break_before: 'auto' }, analyze: true
    = Document Title
    :doctype: book

    = Part I

    == Chapter in Part I

    == Another Chapter in Part I

    = Part II

    == Chapter in Part II
    EOS

    part_1_text = (pdf.find_text 'Part I')[0]
    part_2_text = (pdf.find_text 'Part II')[0]
    chapter_1_text = (pdf.find_text 'Chapter in Part I')[0]
    chapter_2_text = (pdf.find_text 'Another Chapter in Part I')[0]
    (expect part_1_text[:page_number]).to eql 2
    (expect chapter_1_text[:page_number]).to eql 3
    (expect chapter_2_text[:page_number]).to eql 3
    (expect part_2_text[:page_number]).to eql 4
  end
end
