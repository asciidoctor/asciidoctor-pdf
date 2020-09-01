# frozen_string_literal: true

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

  it 'should add text formatting styles to styles defined in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_font_style: 'bold' }, analyze: true
    == Get Started _Quickly_
    EOS

    text = pdf.text
    (expect text).to have_size 2
    (expect text[0][:font_name]).to eql 'NotoSerif-Bold'
    (expect text[1][:font_name]).to eql 'NotoSerif-BoldItalic'
  end

  it 'should allow theme to align all section titles' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_align: 'center' }, analyze: true
    == Drill

    content

    === Down

    content

    ==== Deep
    EOS

    midpoint = pdf.pages[0][:size][0] * 0.5
    content_left_margin = (pdf.find_text 'content')[0][:x]
    drill_text = pdf.find_unique_text 'Drill'
    down_text = pdf.find_unique_text 'Down'
    deep_text = pdf.find_unique_text 'Deep'
    (expect drill_text[:x]).to be > content_left_margin
    (expect down_text[:x]).to be > content_left_margin
    (expect deep_text[:x]).to be > content_left_margin
    (expect (drill_text[:x] + drill_text[:width] * 0.5).round 2).to eql midpoint
    (expect (down_text[:x] + down_text[:width] * 0.5).round 2).to eql midpoint
    (expect (deep_text[:x] + deep_text[:width] * 0.5).round 2).to eql midpoint
  end

  it 'should allow theme to align section title for specific level' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_h1_align: 'center' }, analyze: true
    = Document Title
    :notitle:
    :doctype: book

    = Part A

    == First Chapter

    content

    = Part B

    == Last Chapter

    content
    EOS

    midpoint = pdf.pages[0][:size][0] * 0.5
    left_content_margin = (pdf.find_text 'content')[0][:x]
    part_a_text = pdf.find_unique_text 'Part A'
    first_chapter_text = pdf.find_unique_text 'First Chapter'
    (expect part_a_text[:x]).to be > left_content_margin
    (expect (part_a_text[:x] + part_a_text[:width] * 0.5).round 2).to eql midpoint
    (expect first_chapter_text[:x]).to eql left_content_margin
  end

  it 'should not partition section title by default' do
    pdf = to_pdf <<~'EOS', analyze: true
    == Title: Subtitle
    EOS

    lines = pdf.lines
    (expect lines).to have_size 1
    (expect lines[0]).to eql 'Title: Subtitle'
  end

  it 'should partition section title if title-separator document attribute is set and present in title' do
    pdf = to_pdf <<~'EOS', analyze: true
    :title-separator: :

    == The Title: The Subtitle
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines).to eql ['The Title', 'The Subtitle']
    title_text = (pdf.find_text 'The Title')[0]
    subtitle_text = (pdf.find_text 'The Subtitle')[0]
    (expect subtitle_text[:font_size]).to be < title_text[:font_size]
    (expect subtitle_text[:font_color]).to eql '999999'
    (expect subtitle_text[:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should partition section title if separator block attribute is set and present in title' do
    pdf = to_pdf <<~'EOS', analyze: true
    [separator=:]
    == The Title: The Subtitle
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines).to eql ['The Title', 'The Subtitle']
    title_text = (pdf.find_text 'The Title')[0]
    subtitle_text = (pdf.find_text 'The Subtitle')[0]
    (expect subtitle_text[:font_size]).to be < title_text[:font_size]
    (expect subtitle_text[:font_color]).to eql '999999'
    (expect subtitle_text[:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should partition title on last occurrence of separator' do
    pdf = to_pdf <<~'EOS', analyze: true
    :title-separator: :

    == Foo: Bar: Baz
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines).to eql ['Foo: Bar', 'Baz']
  end

  it 'should not partition section title if separator is not followed by space' do
    pdf = to_pdf <<~'EOS', analyze: true
    [separator=:]
    == Title:Subtitle
    EOS

    lines = pdf.lines
    (expect lines).to have_size 1
    (expect lines[0]).to eql 'Title:Subtitle'
  end

  it 'should not partition section title if separator block attribute is empty' do
    pdf = to_pdf <<~'EOS', analyze: true
    :title-separator: :

    [separator=]
    == Title: Subtitle
    EOS

    lines = pdf.lines
    (expect lines).to have_size 1
    (expect lines[0]).to eql 'Title: Subtitle'
  end

  it 'should not add top margin to section title if it is positioned at the top of the page' do
    pdf = to_pdf '== Section Title', analyze: true
    y1 = (pdf.find_text 'Section Title')[0][:y]
    pdf = to_pdf '== Section Title', pdf_theme: { heading_margin_top: 50 }, analyze: true
    y2 = (pdf.find_text 'Section Title')[0][:y]
    (expect y1).to eql y2
  end

  it 'should add page top margin to section title if it is positioned at the top of the page' do
    pdf = to_pdf '== Section Title', analyze: true
    y1 = (pdf.find_text 'Section Title')[0][:y]
    pdf = to_pdf '== Section Title', pdf_theme: { heading_margin_page_top: 50 }, analyze: true
    y2 = (pdf.find_text 'Section Title')[0][:y]
    (expect y1).to be > y2
  end

  it 'should allow theme to specify different top margin for part titles' do
    pdf_theme = {
      heading_h1_font_size: 20,
      heading_h1_margin_page_top: 100,
      heading_h2_font_size: 20,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title
    :doctype: book

    = Part A

    == First Chapter

    content

    = Part B

    == Last Chapter

    content
    EOS

    part_a_text = pdf.find_unique_text 'Part A'
    first_chapter_text = pdf.find_unique_text 'First Chapter'
    (expect part_a_text[:y]).to eql first_chapter_text[:y] - 100.0
  end

  it 'should uppercase section titles if text_transform key in theme is set to uppercase' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_text_transform: 'uppercase' }, analyze: true
    = Document Title

    == Beginning

    == Middle

    == End
    EOS

    pdf.text.each do |text|
      (expect text[:string]).to eql text[:string].upcase
    end
  end

  it 'should not alter character references when text transform is uppercase' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_text_transform: 'uppercase' }, analyze: true
    == &lt;Tom &amp; Jerry&gt;
    EOS

    (expect pdf.text[0][:string]).to eql '<TOM & JERRY>'
  end

  it 'should underline section titles if text_decoration key in theme is set to underline' do
    pdf_theme = { heading_text_decoration: 'underline' }
    input = '== Section Title'
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
    lines = pdf.lines
    (expect lines).to have_size 1
    underline = lines[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text = pdf.text
    (expect text).to have_size 1
    underlined_text = text[0]
    (expect underline[:from][:x]).to eql underlined_text[:x]
    (expect underline[:from][:y]).to be_within(2).of(underlined_text[:y])
    (expect underlined_text[:font_color]).to eql underline[:color]
    (expect underline[:to][:x] - underline[:from][:x]).to be_within(2).of 140
  end

  it 'should be able to adjust color and width of text decoration' do
    pdf_theme = { heading_text_decoration: 'underline', heading_text_decoration_color: 'cccccc', heading_text_decoration_width: 0.5 }
    input = '== Section Title'
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
    lines = pdf.lines
    (expect lines).to have_size 1
    underline = lines[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text = pdf.text
    (expect text).to have_size 1
    underlined_text = text[0]
    (expect underlined_text[:font_color]).not_to eql underline[:color]
    (expect underline[:color]).to eql 'CCCCCC'
    (expect underline[:width]).to eql 0.5
  end

  it 'should be able to set text decoration properties per heading level' do
    pdf_theme = { heading_h3_text_decoration: 'underline', heading_h3_text_decoration_color: 'cccccc', heading_h3_text_decoration_width: 0.5 }
    input = <<~'EOS'
    == Plain Title

    === Decorated Title
    EOS
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
    lines = pdf.lines
    (expect lines).to have_size 1
    underline = lines[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    underlined_text = pdf.find_unique_text 'Decorated Title'
    (expect underlined_text[:font_color]).not_to eql underline[:color]
    (expect underline[:color]).to eql 'CCCCCC'
    (expect underline[:width]).to eql 0.5
    (expect underline[:from][:y]).to be < underlined_text[:y]
    (expect underline[:from][:y]).to be_within(2).of(underlined_text[:y])
  end

  it 'should support hexidecimal character reference in section title' do
    pdf = to_pdf <<~'EOS', analyze: true
    == &#xb5;Services
    EOS

    (expect pdf.text[0][:string]).to eql %(\u00b5Services)
  end

  it 'should not alter HTML tags when text transform is uppercase' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_text_transform: 'uppercase' }, analyze: true
    == _Quick_ Start
    EOS

    (expect pdf.text[0][:string]).to eql 'QUICK'
  end

  it 'should transform non-ASCII letters when text transform is uppercase' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_text_transform: 'uppercase' }, analyze: true
    == über étudier
    EOS

    (expect pdf.lines[0]).to eql 'ÜBER ÉTUDIER'
  end

  it 'should ignore letters in hexidecimal character reference in section title when transforming to uppercase' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_text_transform: 'uppercase' }, analyze: true
    == &#xb5;Services
    EOS

    (expect pdf.text[0][:string]).to eql %(\u00b5SERVICES)
  end

  it 'should not apply text transform if value of text_transform key is none' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_text_transform: 'uppercase', heading_h3_text_transform: 'none' }, analyze: true
    == Uppercase

    === Title Case
    EOS

    (expect pdf.find_text 'UPPERCASE').to have_size 1
    (expect pdf.find_text 'Title Case').to have_size 1
  end

  it 'should not crash if menu macro is used in section title' do
    pdf = to_pdf <<~'EOS', analyze: true
    :experimental:

    == The menu:File[] menu

    Describe the file menu.
    EOS

    (expect pdf.lines[0]).to eql 'The File menu'
  end

  it 'should not crash if kbd macro is used in section title' do
    pdf = to_pdf <<~'EOS', analyze: true
    :experimental:

    == The magic of kbd:[Ctrl,p]

    Describe the magic of paste.
    EOS

    (expect pdf.lines[0]).to eql %(The magic of Ctrl \u202f+\u202f p)
  end

  it 'should not crash if btn macro is used in section title' do
    pdf = to_pdf <<~'EOS', analyze: true
    :experimental:

    == The btn:[Save] button

    Describe the save button.
    EOS

    (expect pdf.lines[0]).to eql %(The [\u2009Save\u2009] button)
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
  end

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
    { 'chapter-signifier' => 'Ch' }.each do |attr_name, attr_val|
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

  it 'should add chapter signifier to chapter title if section numbering and toc are enabled and chapter-signifier attribute is set' do
    { 'chapter-signifier' => 'Ch' }.each do |attr_name, attr_val|
      pdf = to_pdf <<~EOS, analyze: true
      = Book Title
      :doctype: book
      :sectnums:
      :toc:
      :#{attr_name}: #{attr_val}

      == The Beginning

      == The End
      EOS

      chapter_titles = (pdf.find_text font_size: 22).select {|it| it[:page_number] >= 3 }.map {|it| it[:string] }
      (expect chapter_titles).to eql ['Ch 1. The Beginning', 'Ch 2. The End']
    end
  end

  it 'should not add chapter label to chapter title if section numbering is enabled and chapter-signifier attribute is empty' do
    %w(chapter-signifier).each do |attr_name|
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

  it 'should number sections in article when sectnums attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    :sectnums:

    == Beginning

    == Middle

    === Detail

    === More Detail

    == End
    EOS

    (expect pdf.find_unique_text '1. Beginning', font_size: 22).not_to be_nil
    (expect pdf.find_unique_text '2.1. Detail', font_size: 18).not_to be_nil
  end

  it 'should number subsection of appendix based on appendix letter' do
    pdf = to_pdf <<~'EOS', analyze: true
		= Book Title
		:doctype: book
		:sectnums:

		== Chapter

		content

		[appendix]
		= Appendix

		content

		=== Appendix Subsection

		content
    EOS

    (expect pdf.lines).to include 'A.1. Appendix Subsection'
  end

  it 'should treat level-0 special section as chapter in multipart book' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_h2_font_color: 'AA0000' }, analyze: true
    = Document Title
    :doctype: book

    = Part

    == Chapter

    content

    [appendix]
    = Details

    We let you know.
    EOS

    chapter_texts = pdf.find_text font_color: 'AA0000'
    (expect chapter_texts).to have_size 2
    chapter_text = chapter_texts[0]
    (expect chapter_text[:string]).to eql 'Chapter'
    (expect chapter_text[:page_number]).to be 3
    appendix_text = chapter_texts[1]
    (expect appendix_text[:string]).to eql 'Appendix A: Details'
    (expect appendix_text[:page_number]).to be 4
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
    (expect names).not_to have_key '_preface'

    text = (to_pdf input, analyze: true).text
    (expect text[1][:string]).to eql 'anonymous preface'
    (expect text[1][:font_size]).to be 13
  end

  # QUESTION: is this the right behavior? should the value default to Preface instead?
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
    (expect names).not_to have_key '_preface'

    text = (to_pdf input, analyze: true).text
    (expect text[1][:string]).to eql 'anonymous preface'
    (expect text[1][:font_size]).to be 13
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
    (expect names).to have_key '_prelude'
    (expect pdf.objects[names['_prelude']][3]).to eql (get_page_size pdf, 2)[1]

    text = (to_pdf input, analyze: true).text
    (expect text[1][:string]).to eql 'Prelude'
    (expect text[1][:font_size]).to be 22
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
    (expect section_b_text[:page_number]).to be 1
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
    (expect section_b_text[:page_number]).to be 2
    content_text = (pdf.find_text 'content')[0]
    (expect content_text[:page_number]).to be 2
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
    (expect section_b_text[:page_number]).to be 1
    content_text = (pdf.find_text 'content')[0]
    (expect content_text[:page_number]).to be 2
  end

  it 'should not add break before chapter if heading-chapter-break-before key in theme is auto' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_chapter_break_before: 'auto' }, analyze: true
    = Document Title
    :doctype: book

    == Chapter A

    == Chapter B
    EOS

    chapter_a_text = (pdf.find_text 'Chapter A')[0]
    chapter_b_text = (pdf.find_text 'Chapter B')[0]
    (expect chapter_a_text[:page_number]).to be 2
    (expect chapter_b_text[:page_number]).to be 2
  end

  it 'should not add break before part if heading-part-break-before key in theme is auto' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_part_break_before: 'auto', heading_chapter_break_before: 'auto' }, analyze: true
    = Document Title
    :doctype: book

    = Part I

    == Chapter in Part I

    = Part II

    == Chapter in Part II
    EOS

    part1_text = (pdf.find_text 'Part I')[0]
    part2_text = (pdf.find_text 'Part II')[0]
    (expect part1_text[:page_number]).to be 2
    (expect part2_text[:page_number]).to be 2
  end

  it 'should add break after part if heading-part-break-after key in theme is always' do
    pdf = to_pdf <<~'EOS', pdf_theme: { heading_part_break_after: 'always', heading_chapter_break_before: 'auto' }, analyze: true
    = Document Title
    :doctype: book

    = Part I

    == Chapter in Part I

    == Another Chapter in Part I

    = Part II

    == Chapter in Part II
    EOS

    part1_text = (pdf.find_text 'Part I')[0]
    part2_text = (pdf.find_text 'Part II')[0]
    chapter1_text = (pdf.find_text 'Chapter in Part I')[0]
    chapter2_text = (pdf.find_text 'Another Chapter in Part I')[0]
    (expect part1_text[:page_number]).to be 2
    (expect chapter1_text[:page_number]).to be 3
    (expect chapter2_text[:page_number]).to be 3
    (expect part2_text[:page_number]).to be 4
  end

  it 'should support abstract defined as special section' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    :toc:

    [abstract]
    == Abstract

    A presage of what is to come.

    == Body

    What came to pass.
    EOS

    abstract_title_text = (pdf.find_text 'Abstract')[0]
    (expect abstract_title_text[:x]).to be > 48.24
    abstract_content_text = (pdf.find_text 'A presage of what is to come.')[0]
    (expect abstract_content_text[:font_name]).to eql 'NotoSerif-BoldItalic'
    (expect abstract_content_text[:font_color]).to eql '5C6266'
    toc_entries = pdf.lines.select {|it| it.include? '. . .' }
    (expect toc_entries).to have_size 1
    (expect toc_entries[0]).to start_with 'Body'
  end

  context 'Section indent' do
    it 'should indent section body if section_indent is set to single value in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title

      == Section Title

      paragraph

      [.text-right]
      paragraph
      EOS

      section_text = (pdf.find_text 'Section Title')[0]
      paragraph_text = pdf.find_text 'paragraph'

      (expect section_text[:x]).to eql 48.24
      (expect paragraph_text[0][:x]).to eql 84.24
      (expect paragraph_text[1][:x].to_i).to be 458
    end

    it 'should indent section body if section_indent is set to array in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: [36, 0] }, analyze: true
      = Document Title

      == Section Title

      paragraph

      [.text-right]
      paragraph
      EOS

      section_text = (pdf.find_text 'Section Title')[0]
      paragraph_text = pdf.find_text 'paragraph'

      (expect section_text[:x]).to eql 48.24
      (expect paragraph_text[0][:x]).to eql 84.24
      (expect paragraph_text[1][:x].to_i).to eql (458 + 36)
    end

    it 'should indent toc entries if section_indent is set in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title
      :doctype: book
      :toc:

      == Chapter

      == Another Chapter
      EOS

      toc_texts = pdf.find_text page_number: 2
      toc_title_text = toc_texts.find {|it| it[:string] == 'Table of Contents' }
      (expect toc_title_text[:x]).to eql 48.24
      chapter_title_text = toc_texts.find {|it| it[:string] == 'Chapter' }
      (expect chapter_title_text[:x]).to eql 84.24
    end

    it 'should indent preamble if section_indent is set in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title

      preamble

      == Section

      content
      EOS

      preamble_text = (pdf.find_text 'preamble')[0]
      (expect preamble_text[:x]).to eql 84.24
      section_content_text = (pdf.find_text 'content')[0]
      (expect section_content_text[:x]).to eql 84.24
    end

    it 'should not reapply section indent to nested sections' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title
      :doctype: book
      :notitle:

      == Chapter

      chapter body

      === Section

      section body
      EOS

      chapter_title_text = (pdf.find_text 'Chapter')[0]
      section_title_text = (pdf.find_text 'Section')[0]
      (expect chapter_title_text[:x]).to eql 48.24
      (expect section_title_text[:x]).to eql 48.24

      chapter_body_text = (pdf.find_text 'chapter body')[0]
      section_body_text = (pdf.find_text 'section body')[0]
      (expect chapter_body_text[:x]).to eql 84.24
      (expect section_body_text[:x]).to eql 84.24
    end

    it 'should outdent discrete heading' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title

      == Section

      paragraph

      [discrete]
      === Discrete Heading

      paragraph

      === Nested Section

      paragraph

      [discrete]
      ==== Another Discrete Heading

      paragraph
      EOS

      discrete_heading_texts = pdf.find_text %r/Discrete/
      (expect discrete_heading_texts).to have_size 2
      (expect discrete_heading_texts[0][:x]).to eql 48.24
      (expect discrete_heading_texts[1][:x]).to eql 48.24
      paragraph_texts = pdf.find_text 'paragraph'
      (expect paragraph_texts.map {|it| it[:x] }.uniq).to eql [84.24]
    end

    it 'should not outdent discrete heading inside block' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      == Section

      ****
      sidebar content

      [discrete]
      == Discrete Heading
      ****
      EOS

      sidebar_content_text = (pdf.find_text 'sidebar content')[0]
      discrete_heading_text = (pdf.find_text 'Discrete Heading')[0]
      (expect sidebar_content_text[:x]).to eql discrete_heading_text[:x]
    end

    it 'should honor text alignment role on discrete heading' do
      pdf = to_pdf <<~'EOS', analyze: true
      [discrete]
      == Discrete Heading
      EOS
      left_x = (pdf.find_text 'Discrete Heading')[0][:x]

      pdf = to_pdf <<~'EOS', analyze: true
      [discrete.text-right]
      == Discrete Heading
      EOS
      right_x = (pdf.find_text 'Discrete Heading')[0][:x]

      (expect right_x).to be > left_x
    end

    it 'should outdent footnotes in article' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title

      == Section

      paragraph{blank}footnote:[About this paragraph]
      EOS

      paragraph_text = (pdf.find_text 'paragraph')[0]
      footnote_text_fragments = pdf.text.select {|it| it[:y] < paragraph_text[:y] }
      (expect footnote_text_fragments[0][:string]).to eql '['
      (expect footnote_text_fragments[0][:x]).to eql 48.24
    end

    it 'should outdent footnotes in book' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title
      :doctype: book

      == Chapter

      paragraph{blank}footnote:[About this paragraph]
      EOS

      paragraph_text = (pdf.find_text 'paragraph')[0]
      footnote_text_fragments = (pdf.find_text page_number: 2).select {|it| it[:y] < paragraph_text[:y] }
      (expect footnote_text_fragments[0][:string]).to eql '['
      (expect footnote_text_fragments[0][:x]).to eql 48.24
    end

    it 'should not indent body of index section' do
      pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
      = Document Title
      :doctype: book

      == Chapter

      ((paragraph))

      [index]
      == Index
      EOS

      index_page_texts = pdf.find_text page_number: 3
      index_title_text = index_page_texts.find {|it| it[:string] == 'Index' }
      (expect index_title_text[:x]).to eql 48.24
      category_text = index_page_texts.find {|it| it[:string] == 'P' }
      (expect category_text[:x]).to eql 48.24
    end
  end
end
