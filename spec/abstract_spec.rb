# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Abstract' do
  it 'should convert document with only abstract' do
    pdf = to_pdf <<~'EOS', analyze: true
    [abstract]
    This article is hot air.
    EOS

    abstract_text = (pdf.find_text 'This article is hot air.')[0]
    (expect abstract_text).not_to be_nil
    (expect abstract_text[:font_name]).to eql 'NotoSerif-BoldItalic'
  end

  it 'should outdent abstract title and body' do
    pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36, abstract_title_text_align: :left }, analyze: true
    = Document Title
    :doctype: book

    .Abstract
    [abstract]
    A presage of what is to come.

    == Chapter

    What came to pass.
    EOS

    abstract_title_text = (pdf.find_text 'Abstract')[0]
    (expect abstract_title_text[:x]).to eql 48.24
    abstract_content_text = (pdf.find_text 'A presage of what is to come.')[0]
    (expect abstract_content_text[:x]).to eql 48.24
    chapter_text = (pdf.find_text 'What came to pass.')[0]
    (expect chapter_text[:x]).to eql 84.24
  end

  it 'should indent first line of abstract if prose_text_indent key is set in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: { prose_text_indent: 18 }, analyze: true
    = Document Title

    [abstract]
    This document is configured to have indented paragraphs.
    This option is controlled by the prose_text_indent key in the theme.

    And on it goes.
    EOS

    (expect pdf.text[1][:string]).to start_with 'This document'
    (expect pdf.text[1][:x]).to be > pdf.text[2][:x]
    (expect pdf.text[3][:string]).to eql 'And on it goes.'
  end

  it 'should apply inner margin between inner paragraphs in abstract' do
    pdf = to_pdf <<~EOS, pdf_theme: { prose_margin_inner: 0 }, analyze: true
    = Document Title

    [abstract]
    --
    #{lorem_ipsum '2-sentences-2-paragraphs'}
    --

    And on it goes.
    EOS

    expected_line_spacing = pdf.text[1][:y] - pdf.text[2][:y]
    second_paragraph_text = pdf.find_unique_text %r/^Magna /
    (expect pdf.text[3]).to eql second_paragraph_text
    (expect pdf.text[2][:y] - second_paragraph_text[:y]).to eql expected_line_spacing
  end

  it 'should apply indent to inner paragraphs in abstract when prose_text_indent_inner is set' do
    pdf = to_pdf <<~EOS, pdf_theme: { prose_text_indent_inner: 18, prose_margin_inner: 0 }, analyze: true
    = Document Title

    [abstract]
    --
    #{lorem_ipsum '2-sentences-2-paragraphs'}
    --

    And on it goes.
    EOS

    text_left_margin = (pdf.find_unique_text 'And on it goes.')[:x]
    (expect pdf.text[1][:x]).to eql text_left_margin
    expected_line_spacing = pdf.text[1][:y] - pdf.text[2][:y]
    second_paragraph_text = pdf.find_unique_text %r/^Magna /
    (expect pdf.text[3]).to eql second_paragraph_text
    (expect pdf.text[2][:y] - second_paragraph_text[:y]).to eql expected_line_spacing
    (expect second_paragraph_text[:x]).to be > text_left_margin
  end

  it 'should support non-paragraph blocks inside abstract block' do
    input = <<~'EOS'
    = Document Title

    [abstract]
    --
    ____
    This too shall pass.
    ____
    --

    == Intro

    And so it begins.
    EOS

    pdf = to_pdf input, analyze: :line
    lines = pdf.lines
    (expect lines).to have_size 1

    pdf = to_pdf input, analyze: true
    quote_text = (pdf.find_text 'This too shall pass.')[0]
    (expect quote_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect quote_text[:font_color]).to eql '5C6266'
    (expect quote_text[:y]).to be < lines[0][:from][:y]
    (expect quote_text[:y]).to be > lines[0][:to][:y]
  end

  it 'should only apply bottom margin once when quote block is nested inside abstract block followed by more preamble' do
    pdf_theme = {
      base_line_height: 1,
      abstract_line_height: 1,
      abstract_font_size: 10.5,
      quote_padding: 0,
      quote_border_left_width: 0,
      quote_font_size: 10.5,
      heading_h2_font_size: 10.5,
      heading_margin_top: 0,
      heading_margin_bottom: 12,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title

    [abstract]
    --
    ____
    This quote is the abstract.
    ____
    --

    This is more preamble.

    == Section Title

    Now we are getting to the main event.
    EOS

    texts = pdf.text
    margins = []
    (1.upto texts.size - 2).each do |idx|
      margins << ((texts[idx][:y] - (texts[idx + 1].yield_self {|it| it[:y] + it[:font_size] })).round 2)
    end
    (expect margins).to have_size 3
    (expect margins.uniq).to have_size 1
    (expect margins[0]).to (be_within 1).of 16.0
  end

  it 'should decorate first line of abstract when abstract has multiple lines' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract]
    First line of abstract. +
    Second line of abstract.

    == Section

    content
    EOS

    abstract_text_line1 = pdf.find_text 'First line of abstract.'
    abstract_text_line2 = pdf.find_text 'Second line of abstract.'
    (expect abstract_text_line1).to have_size 1
    (expect abstract_text_line1[0][:order]).to be 2
    (expect abstract_text_line1[0][:font_name]).to include 'BoldItalic'
    (expect abstract_text_line2).to have_size 1
    (expect abstract_text_line2[0][:order]).to be 3
    (expect abstract_text_line2[0][:font_name]).not_to include 'BoldItalic'
  end

  it 'should decorate first line of first paragraph of abstract with multiple paragraphs' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract]
    --
    First line of abstract. +
    Second line of abstract.

    Second paragraph of abstract.
    --

    == Section

    content
    EOS

    first_line_text = pdf.find_unique_text 'First line of abstract.'
    (expect first_line_text[:font_name]).to end_with '-BoldItalic'
    second_paragraph_text = pdf.find_unique_text 'Second paragraph of abstract.'
    (expect second_paragraph_text[:font_name]).to end_with '-Italic'
  end

  it 'should apply text transform to first line of abstract and shrink it to fit', visual: true do
    pdf_theme = {
      abstract_font_color: 'AA0000',
      abstract_first_line_text_transform: 'uppercase',
    }
    input = <<~'EOS'
    = Document Title

    [abstract]
    This is the [.underline]#abstract#.
    This abstract contains enough content that it wraps to a second line.
    The text in the first line has been transformed to into uppercase for extra emphasis.

    This is the main content.
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    first_line_text, second_line_text, third_line_text = pdf.lines pdf.find_text font_color: 'AA0000'
    (expect first_line_text).to eql 'THIS IS THE ABSTRACT. THIS ABSTRACT CONTAINS ENOUGH CONTENT THAT IT WRAPS TO'
    (expect second_line_text).to start_with 'a second line.'
    (expect third_line_text).to start_with 'extra emphasis'
    start_texts = (pdf.find_text font_color: 'AA0000').uniq {|it| it[:y] }
    first_line_gap = start_texts[0][:y] - start_texts[1][:y]
    second_line_gap = start_texts[1][:y] - start_texts[2][:y]
    # NOTE: the transform throws off the gap slightly; something to investigate
    (expect first_line_gap).to (be_within 1).of second_line_gap

    to_file = to_pdf_file input, 'abstract-first-line-text-transform.pdf', pdf_theme: pdf_theme
    (expect to_file).to visually_match 'abstract-first-line-text-transform.pdf'
  end

  it 'should not crash when applying text transform to first line of abstract inside column box' do
    backend = nil
    create_class (Asciidoctor::Converter.for 'pdf') do
      register_for (backend = %(pdf#{object_id}).to_sym)
      def traverse node
        return super unless node.context == :document
        column_box [0, cursor], columns: 2, width: bounds.width, reflow_margins: true, spacer: 12 do
          super
        end
      end
    end

    pdf_theme = { abstract_font_color: '0000FF', abstract_first_line_text_transform: 'uppercase' }

    input = <<~'EOS'
    = Document Title

    [abstract]
    This *_story_* chronicles the inexplicable hazards and vicious beasts a team must conquer and vanquish on their journey to discovering the true power of Open Source.

    == Section Title
    EOS

    pdf = to_pdf input, backend: backend, pdf_theme: pdf_theme, analyze: true
    lines = pdf.lines (pdf.text.select {|it| it[:font_color] == '0000FF' })
    (expect lines[0]).to eql 'THIS STORY CHRONICLES THE'
    (expect lines[1]).to eql 'inexplicable hazards and vicious beasts'
  end

  it 'should use base font color if font color is not defined for abstract in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: { abstract_font_color: nil, base_font_color: '0000EE' }, analyze: true
    = Document Title

    [abstract]
    This is the abstract. +
    This is the second line.

    This is the main content.
    EOS

    abstract_first_line_text, abstract_second_line_text = pdf.find_text font_size: 13
    main_text = pdf.find_unique_text 'This is the main content.'
    (expect abstract_first_line_text[:font_color]).to eql main_text[:font_color]
    (expect abstract_second_line_text[:font_color]).to eql main_text[:font_color]
  end

  it 'should set font color on first line of abstract if specified in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: { abstract_font_color: '444444', abstract_first_line_font_color: 'AA0000' }, analyze: true
    = Document Title

    [abstract]
    First line of abstract. +
    Second line of abstract.

    == Section

    content
    EOS

    abstract_texts = pdf.find_text %r/line of abstract/
    (expect abstract_texts).to have_size 2
    first_line_text, second_line_text = abstract_texts
    (expect first_line_text[:font_color]).to eql 'AA0000'
    (expect second_line_text[:font_color]).to eql '444444'
  end

  it 'should not style first line of abstract if theme sets font style to normal' do
    pdf = to_pdf <<~'EOS', pdf_theme: { abstract_first_line_font_style: 'normal' }, analyze: true
    = Document Title

    [abstract]
    First line of abstract. +
    Second line of abstract.

    == Section

    content
    EOS

    abstract_texts = pdf.find_text %r/line of abstract/
    (expect abstract_texts).to have_size 2
    first_line_text, second_line_text = abstract_texts
    (expect first_line_text[:font_name]).to eql 'NotoSerif'
    (expect second_line_text[:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should style first line of abstract if theme sets font style to italic but abstract font style to normal' do
    pdf_theme = { abstract_font_style: 'normal', abstract_first_line_font_style: 'italic' }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title

    [abstract]
    First line of abstract. +
    Second line of abstract.

    == Section

    content
    EOS

    abstract_texts = pdf.find_text %r/line of abstract/
    (expect abstract_texts).to have_size 2
    first_line_text, second_line_text = abstract_texts
    (expect first_line_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect second_line_text[:font_name]).to eql 'NotoSerif'
  end

  it 'should style first line of abstract if theme sets font style to bold but abstract font style to normal' do
    pdf_theme = { abstract_font_style: 'normal', abstract_first_line_font_style: 'bold' }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title

    [abstract]
    First line of abstract. +
    Second line of abstract.

    == Section

    content
    EOS

    abstract_texts = pdf.find_text %r/line of abstract/
    (expect abstract_texts).to have_size 2
    first_line_text, second_line_text = abstract_texts
    (expect first_line_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect second_line_text[:font_name]).to eql 'NotoSerif'
  end

  it 'should style first line in abstract if theme sets font style to normal_italic and abstract font style to bold' do
    pdf_theme = { abstract_font_style: 'bold', abstract_first_line_font_style: 'normal_italic' }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title

    [abstract]
    First line in abstract. +
    Second line in abstract.

    == Section

    content
    EOS

    abstract_texts = pdf.find_text %r/line in abstract/
    (expect abstract_texts).to have_size 2
    first_line_text, second_line_text = abstract_texts
    (expect first_line_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect second_line_text[:font_name]).to eql 'NotoSerif-Bold'
  end

  it 'should allow theme to set text alignment of abstract' do
    pdf = to_pdf <<~'EOS', pdf_theme: { abstract_text_align: 'center' }, analyze: true
    = Document Title

    [abstract]
    This is the abstract.

    This is the main content.
    EOS

    abstract_text = pdf.find_unique_text 'This is the abstract.'
    main_text = pdf.find_unique_text 'This is the main content.'
    (expect abstract_text[:x]).to be > main_text[:x]
  end

  it 'should allow theme to set text alignment of abstract title' do
    pdf = to_pdf <<~'EOS', pdf_theme: { abstract_title_text_align: 'center' }, analyze: true
    = Document Title
    :doctype: book

    .Abstract
    [abstract]
    This is the abstract.

    == Chapter

    This is the main content.
    EOS

    abstract_text = pdf.find_unique_text 'This is the abstract.'
    abstract_title_text = pdf.find_unique_text 'Abstract'
    (expect abstract_title_text[:x]).to be > abstract_text[:x]
  end

  it 'should use base text align to align abstract title if theme does not specify alignment' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_text_align: 'center', abstract_title_text_align: nil }, analyze: true
    = Document Title
    :doctype: book

    .Abstract
    [abstract]
    This is the abstract.

    == Chapter

    [.text-left]
    This is the main content.
    EOS

    abstract_title_text = pdf.find_unique_text 'Abstract'
    main_text = pdf.find_unique_text 'This is the main content.'
    (expect abstract_title_text[:x]).to be > main_text[:x]
  end

  it 'should use consistent spacing between lines in abstract when theme uses AFM font' do
    pdf = to_pdf <<~'EOS', pdf_theme: { extends: 'base', abstract_first_line_font_color: 'AA0000' }, analyze: true
    = Document Title

    [abstract]
    First line of abstract. +
    Second line of abstract. +
    Third line of abstract.

    == Section

    content
    EOS

    abstract_text_line1 = (pdf.find_text 'First line of abstract.')[0]
    abstract_text_line2 = (pdf.find_text 'Second line of abstract.')[0]
    abstract_text_line3 = (pdf.find_text 'Third line of abstract.')[0]
    line1_line2_gap = abstract_text_line1[:y] - abstract_text_line2[:y]
    line2_line3_gap = abstract_text_line2[:y] - abstract_text_line3[:y]
    (expect abstract_text_line1[:font_color]).to eql 'AA0000'
    (expect line1_line2_gap).to eql line2_line3_gap
  end

  it 'should decorate first line of abstract when abstract has single line' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract]
    First and only line of abstract.

    == Section

    content
    EOS

    abstract_text = pdf.find_text 'First and only line of abstract.'
    (expect abstract_text).to have_size 1
    (expect abstract_text[0][:order]).to be 2
    (expect abstract_text[0][:font_name]).to include 'BoldItalic'
    (expect abstract_text[0][:font_color]).to eql '5C6266'
  end

  it 'should be able to disable first line decoration on abstract using theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: { abstract_first_line_font_style: nil }, analyze: true
    = Document Title

    [abstract]
    First and only line of abstract.

    == Section

    content
    EOS

    abstract_text = pdf.find_text 'First and only line of abstract.'
    (expect abstract_text).to have_size 1
    (expect abstract_text[0][:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should honor text alignment role on abstract paragraph' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract.text-right]
    Enter stage right.

    == Section

    content
    EOS

    halfway_point = (pdf.page 1)[:size][0] * 0.5
    abstract_text = pdf.find_text 'Enter stage right.'
    (expect abstract_text).to have_size 1
    (expect abstract_text[0][:x]).to be > halfway_point
  end

  it 'should honor text alignment role on nested abstract paragraph' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract]
    --
    [.text-right]
    Enter stage right.

    Mirror, stage left.
    --

    == Section

    content
    EOS

    halfway_point = (pdf.page 1)[:size][0] * 0.5
    abstract_text1 = pdf.find_text 'Enter stage right.'
    (expect abstract_text1).to have_size 1
    (expect abstract_text1[0][:x]).to be > halfway_point
    abstract_text2 = pdf.find_text 'Mirror, stage left.'
    (expect abstract_text2).to have_size 1
    (expect abstract_text2[0][:x]).to be < halfway_point
  end

  it 'should apply same line height to all paragraphs in abstract' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title

    [abstract]
    --
    paragraph 1, line 1 +
    paragraph 1, line 2

    paragraph 2, line 1 +
    paragraph 2, line 2
    --

    == Section

    content
    EOS

    p1_l1_text = (pdf.find_text 'paragraph 1, line 1')[0]
    p1_l2_text = (pdf.find_text 'paragraph 1, line 2')[0]
    p2_l1_text = (pdf.find_text 'paragraph 2, line 1')[0]
    p2_l2_text = (pdf.find_text 'paragraph 2, line 2')[0]

    (expect p2_l1_text[:y] - p2_l2_text[:y]).to eql p1_l1_text[:y] - p1_l2_text[:y]
  end

  it 'should apply margin below abstract when followed by other blocks in preamble' do
    pdf_theme = {
      base_line_height: 1,
      abstract_line_height: 1,
      abstract_font_size: 10.5,
      heading_h2_font_size: 10.5,
      heading_margin_top: 0,
      heading_margin_bottom: 12,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title

    [abstract]
    --
    This is the abstract.
    --

    This is more preamble.

    == Section Title

    Now we are getting to the main event.
    EOS

    texts = pdf.text
    margins = []
    (1.upto texts.size - 2).each do |idx|
      margins << ((texts[idx][:y] - (texts[idx + 1].yield_self {|it| it[:y] + it[:font_size] })).round 2)
    end
    (expect margins).to have_size 3
    (expect margins.uniq).to have_size 1
    (expect margins[0]).to (be_within 1).of 16.0
  end
end
