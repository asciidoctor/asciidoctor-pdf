require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - TOC' do
  context 'book' do
    it 'should not generate toc by default' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 4
      (expect pdf.find_text 'Table of Contents').to be_empty
    end

    it 'should insert toc between title page and first page of body when toc is set' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title
      :toc:

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 5
      (expect pdf.find_text string: 'Document Title', page_number: 1).not_to be_empty
      (expect pdf.find_text string: 'Table of Contents', page_number: 2).not_to be_empty
      (expect pdf.find_text string: '1', page_number: 2).not_to be_empty
      (expect pdf.find_text string: '2', page_number: 2).not_to be_empty
      (expect pdf.find_text string: '3', page_number: 2).not_to be_empty
      (expect pdf.find_text string: 'Introduction', page_number: 3).not_to be_empty
    end

    it 'should space items in toc evently even if title is entirely monospace' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title
      :toc:

      == Beginning

      == `Middle`

      == End
      EOS
      (expect pdf.find_text string: 'Table of Contents', page_number: 2).not_to be_empty
      beginning_pagenum_text = (pdf.find_text string: '1', page_number: 2)[0]
      middle_pagenum_text = (pdf.find_text string: '2', page_number: 2)[0]
      end_pagenum_text = (pdf.find_text string: '3', page_number: 2)[0]
      beginning_to_middle_spacing = (beginning_pagenum_text[:y] - middle_pagenum_text[:y]).round 2
      middle_to_end_spacing = (middle_pagenum_text[:y] - end_pagenum_text[:y]).round 2
      (expect beginning_to_middle_spacing).to eql middle_to_end_spacing
    end

    it 'should only include preface in toc if preface-title is set' do
      input = <<~'EOS'
      = Document Title

      [preface]
      This is the preface.

      == Chapter 1

      And away we go!
      EOS

      [{ 'toc' => '' }, { 'toc' => '', 'preface-title' => 'Preface' }].each do |attrs|
        pdf = to_pdf input, doctype: :book, attributes: attrs, analyze: :page
        (expect pdf.pages).to have_size 4
        (expect pdf.pages[0][:strings]).to include 'Document Title'
        (expect pdf.pages[1][:strings]).to include 'Table of Contents'
        if attrs.include? 'preface-title'
          (expect pdf.pages[1][:strings]).to include 'Preface'
          (expect pdf.pages[1][:strings]).to include '1'
        else
          (expect pdf.pages[1][:strings]).not_to include 'Preface'
          (expect pdf.pages[1][:strings]).not_to include '1'
        end
        (expect pdf.pages[1][:strings]).to include 'Chapter 1'
        (expect pdf.pages[1][:strings]).to include '2'
        if attrs.include? 'preface-title'
          (expect pdf.pages[2][:strings]).to include 'Preface'
        end
        (expect pdf.pages[2][:strings]).to include 'This is the preface.'
        (expect pdf.pages[3][:strings]).to include 'Chapter 1'
      end
    end

    it 'should output toc with depth specified by toclevels' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :toc:
      :toclevels: 1

      == Level 1

      === Level 2

      ==== Level 3
      EOS
      (expect pdf.pages).to have_size 3
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include 'Level 1'
      (expect pdf.pages[1][:strings]).not_to include 'Level 2'
      (expect pdf.pages[1][:strings]).not_to include 'Level 3'
      (expect pdf.pages[2][:strings]).to include 'Level 1'
    end

    it 'should only show parts in toc if toclevels attribute is 0' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :toc:
      :toclevels: 0

      = Part One

      == Chapter A

      = Part Two

      == Chapter B
      EOS
      (expect pdf.pages).to have_size 6
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include 'Part One'
      (expect pdf.pages[1][:strings]).to include 'Part Two'
      (expect pdf.pages[1][:strings]).not_to include 'Chapter A'
      (expect pdf.pages[1][:strings]).not_to include 'Chapter B'
    end

    it 'should reserve enough pages for toc if it spans more than one page' do
      sections = (1..40).map {|num| %(\n\n=== Section #{num}) }
      pdf = to_pdf <<~EOS, doctype: :book, analyze: :page
      = Document Title
      :toc:

      == Chapter 1#{sections.join}
      EOS
      (expect pdf.pages).to have_size 6
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[3][:strings]).to include 'Chapter 1'
    end

    it 'should insert toc at location of toc macro if toc attribute is macro' do
      lorem = ['lorem ipsum'] * 10 * %(\n\n)
      input = <<~EOS
      = Document Title
      :doctype: book
      :toc: macro

      Preamble

      == Introduction

      #{lorem}

      toc::[]

      == Main

      #{lorem}

      == Conclusion

      #{lorem}
      EOS
      pdf = to_pdf input, analyze: true
      (expect pdf.pages).to have_size 6
      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      (expect toc_title_text[:page_number]).to eql 4

      pdf = to_pdf input
      outline = extract_outline pdf
      (expect outline).to have_size 5
      (expect outline.map {|it| it[:title] }).to eql ['Document Title', 'Introduction', 'Table of Contents', 'Main', 'Conclusion']
      toc_dest = outline[2][:dest]
      (expect toc_dest[:pagenum]).to eql 4
      (expect toc_dest[:label]).to eql '3'
      (expect toc_dest[:y]).to be > 800
    end

    it 'should insert macro toc in outline as sibling of section in which it is contained' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book
      :toc: macro

      == Chapter

      === Section

      toc::[]

      === Another Section
      EOS

      outline = extract_outline pdf
      chapter_entry = outline[1]
      (expect chapter_entry).not_to be_nil
      (expect chapter_entry[:title]).to eql 'Chapter'
      chapter_entry_children = chapter_entry[:children]
      (expect chapter_entry[:children]).to have_size 3
      toc_entry = chapter_entry[:children][1]
      (expect toc_entry[:title]).to eql 'Table of Contents'
      (expect toc_entry[:dest][:label]).to eql '2'
    end

    it 'should not add toc title to page or outline if toc-title is unset' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book
      :toc:
      :!toc-title:

      == Beginning

      == Middle

      == End
      EOS

      (expect pdf.pages).to have_size 5
      (expect pdf.pages[1].text).to start_with 'Beginning'

      outline = extract_outline pdf
      (expect outline).to have_size 4
      (expect outline[0][:title]).to eql 'Document Title'
      (expect outline[1][:title]).to eql 'Beginning'
    end

    it 'should line up dots and page number with wrapped line' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title
      :toc:

      == This Here is an Absurdly Long Section Title That Exceeds the Length of a Single Line and Therefore Wraps

      content
      EOS

      toc_text = pdf.find_text page_number: 2
      (expect toc_text.size).to be > 1
      (expect toc_text[1][:string]).to eql 'This Here is an Absurdly Long Section Title That Exceeds the Length of a Single Line and'
      (expect toc_text[2][:string]).to eql 'Therefore Wraps'
      (expect toc_text[1][:x]).to eql toc_text[2][:x]
      dot_leader_text = (pdf.find_text page_number: 2).select {|it| it[:string].start_with? '.' }
      (expect dot_leader_text).not_to be_empty
      (expect dot_leader_text[0][:y]).to be < toc_text[1][:y]
      page_number_text = pdf.find_text page_number: 2, string: '1'
      (expect page_number_text).to have_size 1
    end

    it 'should allow hanging indent to be applied to lines that wrap' do
      pdf = to_pdf <<~'EOS', doctype: :book, pdf_theme: { toc_hanging_indent: 36 }, analyze: true
      = Document Title
      :toc:

      == This Here is an Absurdly Long Section Title That Exceeds the Length of a Single Line and Therefore Wraps

      content
      EOS

      toc_text = pdf.find_text page_number: 2
      (expect toc_text.size).to be > 1
      (expect toc_text[1][:string]).to eql 'This Here is an Absurdly Long Section Title That Exceeds the Length of a Single Line and'
      (expect toc_text[2][:string]).to eql 'Therefore Wraps'
      (expect toc_text[2][:x]).to be > toc_text[1][:x]
      dot_leader_text = (pdf.find_text page_number: 2).select {|it| it[:string].start_with? '.' }
      (expect dot_leader_text).not_to be_empty
      (expect dot_leader_text[0][:y]).to be < toc_text[1][:y]
      page_number_text = pdf.find_text page_number: 2, string: '1'
      (expect page_number_text).to have_size 1
    end

    it 'should not use part or chapter signifier in toc' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Book Title
      :doctype: book
      :sectnums:
      :partnums:
      :toc:

      = P1

      == C1

      = P2

      == C2
      EOS

      lines = pdf.lines pdf.find_text page_number: 2
      (expect lines).to have_size 5
      (expect lines[0]).to eql 'Table of Contents'
      if asciidoctor_2_or_better?
        (expect lines[1]).to start_with 'I: P1'
        (expect lines[3]).to start_with 'II: P2'
        (expect pdf.find_text 'Part I: P1').to have_size 1
      else
        (expect lines[1]).to start_with 'P1'
        (expect lines[3]).to start_with 'P2'
        (expect pdf.find_text 'P1').to have_size 2
      end
      (expect lines[2]).to start_with '1. C1'
      (expect lines[4]).to start_with '2. C2'
      (expect pdf.find_text 'Chapter 1. C1').to have_size 1
    end

    it 'should reserve enough room for toc when page number forces section title in toc to wrap' do
      pdf = to_pdf <<~EOS, analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      #{(['== Chapter'] * 9).join ?\n}

      == This is a very long section title that wraps in the table of contents when the page number is added

      #{(['== Chapter'] * 27).join ?\n}

      == Last Chapter
      EOS

      (expect pdf.find_text page_number: 2, string: 'Last Chapter').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Chapter').to be_empty
    end
  end

  context 'article' do
    it 'should not generate toc by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.find_text 'Table of Contents').to be_empty
    end

    it 'should insert toc between document title and content when toc is set' do
      lorem = ['lorem ipsum'] * 10 * %(\n\n)
      input = <<~EOS
      = Document Title
      :toc:

      Preamble

      == Introduction

      #{lorem}

      == Main

      #{lorem}

      == Conclusion

      #{lorem}
      EOS
      pdf = to_pdf input, analyze: true
      (expect pdf.pages).to have_size 2
      (expect pdf.find_text string: 'Table of Contents', page_number: 1).to have_size 1
      (expect pdf.find_text string: 'Introduction', page_number: 1).to have_size 2
      doctitle_text = (pdf.find_text 'Document Title')[0]
      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      toc_bottom_text = (pdf.find_text '2')[0]
      content_top_text = (pdf.find_text 'Preamble')[0]
      (expect doctitle_text[:y]).to be > toc_title_text[:y]
      (expect toc_title_text[:y]).to be > content_top_text[:y]
      (expect toc_bottom_text[:y]).to be > content_top_text[:y]
      # NOTE assert there's no excess gap between end of toc and start of content
      (expect toc_bottom_text[:y] - content_top_text[:y]).to be < 35
    end

    it 'should insert toc at top of first page if toc is set and document has no doctitle' do
      pdf = to_pdf <<~'EOS', analyze: true
      :toc:

      == Section A

      == Section B
      EOS

      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      sect_a_text = (pdf.find_text string: 'Section A', font_size: 22)[0]
      (expect toc_title_text[:y]).to be > sect_a_text[:y]
    end

    it 'should reserve enough pages for toc if it spans more than one page' do
      sections = (1..40).map {|num| %(\n\n== Section #{num}) }
      input = <<~EOS
      = Document Title
      :toc:

      #{sections.join}
      EOS
      pdf = to_pdf input, analyze: :page
      (expect pdf.pages).to have_size 4
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[0][:strings]).to include 'Table of Contents'
      (expect pdf.pages[0][:strings]).not_to include 'Section 40'
      (expect pdf.pages[1][:strings]).to include 'Section 40'
      (expect pdf.pages[1][:strings]).to include 'Section 1'
      pdf = to_pdf input, analyze: true
      text = pdf.text
      idx_toc_bottom = nil
      idx_content_top = nil
      text.each_with_index do |candidate, idx|
        idx_toc_bottom = idx if candidate[:string] == 'Section 40' && candidate[:font_size] == 10.5
      end
      text.each_with_index do |candidate, idx|
        idx_content_top = idx if candidate[:string] == 'Section 1' && candidate[:font_size] == 22
      end
      (expect text[idx_toc_bottom][:y]).to be > text[idx_content_top][:y]
      # NOTE assert there's no excess gap between end of toc and start of content
      (expect text[idx_toc_bottom][:y] - text[idx_content_top][:y]).to be < 50
    end

    it 'should insert toc between title page and first page of body when toc and title-page are set' do
      pdf = to_pdf <<~'EOS', analyze: :page
      = Document Title
      :toc:
      :title-page:

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 3
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'Table of Contents'
      (expect pdf.pages[1][:strings]).to include '1'
      (expect pdf.pages[1][:strings]).not_to include '2'
      (expect pdf.pages[2][:strings]).to include 'Introduction'
    end

    it 'should insert toc at location of toc macro if toc attribute is macro' do
      lorem = ['lorem ipsum'] * 10 * %(\n\n)
      input = <<~EOS
      = Document Title
      :toc: macro

      Preamble

      == Introduction

      #{lorem}

      toc::[]

      == Main

      #{lorem}

      == Conclusion

      #{lorem}
      EOS
      pdf = to_pdf input, analyze: true
      (expect pdf.pages).to have_size 2
      (expect pdf.find_text string: 'Table of Contents', page_number: 1).to have_size 1
      (expect pdf.find_text string: 'Introduction', page_number: 1).to have_size 2
      doctitle_text = (pdf.find_text 'Document Title')[0]
      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      toc_bottom_text = (pdf.find_text '2')[0]
      content_top_text = (pdf.find_text 'Preamble')[0]
      intro_title_text = (pdf.find_text 'Introduction')[0]
      (expect doctitle_text[:y]).to be > toc_title_text[:y]
      (expect toc_title_text[:y]).to be < content_top_text[:y]
      (expect toc_bottom_text[:y]).to be < content_top_text[:y]
      (expect toc_title_text[:y]).to be < intro_title_text[:y]

      pdf = to_pdf input
      outline = extract_outline pdf
      (expect outline).to have_size 5
      (expect outline.map {|it| it[:title] }).to eql ['Document Title', 'Introduction', 'Table of Contents', 'Main', 'Conclusion']
      toc_dest = outline[2][:dest]
      (expect toc_dest[:pagenum]).to eql 1
      (expect toc_dest[:label]).to eql '1'
      (expect toc_dest[:y]).to be < 800
    end

    it 'should insert macro toc in outline as sibling of section in which it is contained' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :toc: macro

      == Section

      === Subsection

      toc::[]

      === Another Subsection
      EOS

      outline = extract_outline pdf
      section_entry = outline[1]
      (expect section_entry).not_to be_nil
      (expect section_entry[:title]).to eql 'Section'
      section_entry_children = section_entry[:children]
      (expect section_entry[:children]).to have_size 3
      toc_entry = section_entry[:children][1]
      (expect toc_entry[:title]).to eql 'Table of Contents'
      (expect toc_entry[:dest][:label]).to eql '1'
    end

    it 'should insert macro toc in outline before other sections if macro proceeds sections' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :toc: macro

      toc::[]

      == Section

      === Subsection

      === Another Subsection
      EOS

      outline = extract_outline pdf
      toc_entry = outline[1]
      (expect toc_entry[:title]).to eql 'Table of Contents'
      (expect toc_entry[:dest][:label]).to eql '1'
    end
  end

  it 'should apply consistent font color to running content when base font color is unset', visual: true do
    theme_overrides = {
      extends: 'base',
      base_font_color: nil,
      header_height: 36,
      header_font_color: '0000FF',
      header_columns: '0% =100% 0%',
      header_recto_center_content: 'header text',
      header_verso_center_content: 'header text',
      toc_dot_leader_font_color: 'CCCCCC',
      running_content_start_at: 'toc',
    }
    to_file = to_pdf_file <<~'EOS', 'toc-running-content-font-color.pdf', pdf_theme: theme_overrides
    = Document Title
    Author Name
    :doctype: book
    :toc:

    == A

    text

    == B

    text
    EOS

    (expect to_file).to visually_match 'toc-running-content-font-color.pdf'
  end

  it 'should decode character references in toc entries' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    :toc:

    == Paper Clips &#x2116;&nbsp;4
    EOS

    (expect pdf.find_text %(Paper Clips \u2116\u00a04)).to have_size 2
  end
end
