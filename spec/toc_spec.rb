# frozen_string_literal: true

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
      (expect pdf.find_text 'Document Title', page_number: 1).not_to be_empty
      (expect pdf.find_text 'Table of Contents', page_number: 2).not_to be_empty
      (expect pdf.find_text '1', page_number: 2).not_to be_empty
      (expect pdf.find_text '2', page_number: 2).not_to be_empty
      (expect pdf.find_text '3', page_number: 2).not_to be_empty
      (expect pdf.find_text 'Introduction', page_number: 3).not_to be_empty
    end

    it 'should space items in toc evently even if title is entirely monospace' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title
      :toc:

      == Beginning

      == `Middle`

      == End
      EOS
      (expect pdf.find_text 'Table of Contents', page_number: 2).not_to be_empty
      beginning_pagenum_text = (pdf.find_text '1', page_number: 2)[0]
      middle_pagenum_text = (pdf.find_text '2', page_number: 2)[0]
      end_pagenum_text = (pdf.find_text '3', page_number: 2)[0]
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
        (expect pdf.pages[2][:strings]).to include 'Preface' if attrs.include? 'preface-title'
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

    it 'should not show any section titles when toclevels is less than 0' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title
      :toc:
      :toclevels: -1

      = Part One

      == Chapter A

      = Part Two

      == Chapter B
      EOS
      (expect pdf.pages).to have_size 6
      toc_lines = pdf.lines pdf.find_text page_number: 2
      (expect toc_lines).to eql ['Table of Contents']
    end

    it 'should allow section to override toclevels for descendant sections' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :toc:
      :toclevels: 3

      == Chapter

      === Chapter Section

      ==== Chapter Subsection

      [appendix,toclevels=1]
      == Lorem Ipsum

      === Appendix Section

      ==== Appendix Subsection
      EOS

      (expect pdf.find_text page_number: 2, string: 'Chapter').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Chapter Section').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Chapter Subsection').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Appendix A: Lorem Ipsum').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Appendix Section').to have_size 0
    end

    it 'should allow section to remove itself from toc by setting toclevels to less than section level' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :toc:
      :toclevels: 3

      == Chapter

      === Chapter Section

      ==== Chapter Subsection

      [appendix,toclevels=0]
      == Lorem Ipsum

      === Appendix Section

      ==== Appendix Subsection
      EOS

      (expect pdf.find_text page_number: 2, string: 'Chapter').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Chapter Section').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Chapter Subsection').to have_size 1
      (expect pdf.find_text page_number: 2, string: 'Appendix A: Lorem Ipsum').to have_size 0
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

    it 'should render all TOC entries when computing extent of TOC when sectids is unset' do
      input = <<~EOS
      = Document Title
      :doctype: book
      :pdf-page-size: A5
      :toc:
      :!sectids:

      the preface

      #{30.times.map {|idx| %(== Chapter #{idx + 1}) }.join ?\n}
      EOS

      pdf = to_pdf input, analyze: true
      preface_text = pdf.find_unique_text 'the preface'
      last_toc_entry_text = (pdf.find_text 'Chapter 30')[0]
      (expect preface_text[:page_number]).to be > last_toc_entry_text[:page_number]
    end

    it 'should render descendants of section without ID when computing extent of TOC' do
      input = <<~EOS
      = Document Title
      :doctype: book
      :pdf-page-size: A5
      :toc:

      the preface

      :!sectids:
      == Chapter 1
      :sectids:

      #{5.times.map {|idx| %(=== Section #{idx + 1}) }.join ?\n}

      #{21.times.map {|idx| %(== Chapter #{idx + 2}) }.join ?\n}
      EOS

      pdf = to_pdf input, analyze: true
      preface_text = pdf.find_unique_text 'the preface'
      last_toc_entry_text = (pdf.find_text 'Chapter 22')[0]
      (expect preface_text[:page_number]).to be > last_toc_entry_text[:page_number]
    end

    it 'should insert toc after preamble if toc attribute is preamble' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :toc: preamble

      This is the preamble.

      == Introduction

      content

      == Conclusion

      content
      EOS

      toc_title_text = pdf.find_unique_text 'Table of Contents'
      (expect toc_title_text[:page_number]).to be 1
      introduction_title_text = pdf.find_unique_text 'Introduction', font_name: 'NotoSerif-Bold'
      (expect introduction_title_text[:y]).to be < toc_title_text[:y]
      introduction_toc_text = pdf.find_unique_text 'Introduction', font_name: 'NotoSerif'
      (expect introduction_toc_text[:y]).to be > introduction_title_text[:y]
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
      (expect toc_title_text[:page_number]).to be 4

      pdf = to_pdf input
      outline = extract_outline pdf
      (expect outline).to have_size 5
      (expect outline.map {|it| it[:title] }).to eql ['Document Title', 'Introduction', 'Table of Contents', 'Main', 'Conclusion']
      toc_dest = outline[2][:dest]
      (expect toc_dest[:pagenum]).to be 4
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
      (expect chapter_entry_children).to have_size 3
      toc_entry = chapter_entry_children[1]
      (expect toc_entry[:title]).to eql 'Table of Contents'
      (expect toc_entry[:dest][:label]).to eql '2'
    end

    it 'should not toc at default location if document has no sections' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :toc:

      No sections here.

      No sections here either.

      Fin.
      EOS

      (expect pdf.lines).to eql ['Document Title', 'No sections here.', 'No sections here either.', 'Fin.']
      p1_text = pdf.find_unique_text 'No sections here.'
      p2_text = pdf.find_unique_text 'No sections here either.'
      p3_text = pdf.find_unique_text 'Fin.'
      (expect (p1_text[:y] - p2_text[:y]).round 2).to eql ((p2_text[:y] - p3_text[:y]).round 2)
    end

    it 'should not insert toc at default location if converter overrides get_entries_for_toc and value is empty' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def get_entries_for_toc _node
          []
        end
      end

      pdf = to_pdf <<~'EOS', backend: backend, analyze: true
      = Document Title
      :toc:

      == Beginning

      content

      == End

      content
      EOS

      (expect (pdf.find_unique_text 'Table of Contents')).to be_nil
      (expect (pdf.find_text 'Beginning')).to have_size 1
    end

    it 'should not insert toc at location of toc macro if document has no sections' do
      pdf = to_pdf <<~'EOS', analyze: true
      :toc: macro

      No sections here.

      toc::[]

      No sections here either.

      Fin.
      EOS

      (expect pdf.lines).to eql ['No sections here.', 'No sections here either.', 'Fin.']
      p1_text = pdf.find_unique_text 'No sections here.'
      p2_text = pdf.find_unique_text 'No sections here either.'
      p3_text = pdf.find_unique_text 'Fin.'
      (expect (p1_text[:y] - p2_text[:y]).round 2).to eql ((p2_text[:y] - p3_text[:y]).round 2)
    end

    it 'should not insert toc at location of toc macro if converter overrides get_entries_for_toc and value is empty' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def get_entries_for_toc _node
          []
        end
      end

      pdf = to_pdf <<~'EOS', backend: backend, analyze: true
      = Document Title
      :toc: macro

      == Beginning

      content

      toc::[]

      == End

      content
      EOS

      (expect (pdf.find_unique_text 'Table of Contents')).to be_nil
      (expect (pdf.find_text 'Beginning')).to have_size 1
    end

    it 'should only insert macro toc at location of first toc macro' do
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

      toc::[]

      == Conclusion

      #{lorem}
      EOS

      pdf = to_pdf input, analyze: true
      (expect pdf.pages).to have_size 6
      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      (expect toc_title_text[:page_number]).to be 4
      toc_lines = pdf.lines pdf.find_text page_number: 4
      (expect toc_lines).to have_size 4
      ['Table of Contents', 'Introduction', 'Main', 'Conclusion'].each_with_index do |title, idx|
        (expect toc_lines[idx]).to start_with title
      end
    end

    it 'should not insert toc at location of toc macro if toc attribute is not set' do
      pdf = to_pdf <<~'EOS', analyze: true
      == Before

      toc::[]

      == After
      EOS

      (expect pdf.lines).to eql %w(Before After)
    end

    it 'should not insert toc at location of toc macro if toc-placement attribute is set but not toc attribute' do
      pdf = to_pdf <<~'EOS', analyze: true
      :toc-placement: macro

      == Before

      toc::[]

      == After
      EOS

      (expect pdf.lines).to eql %w(Before After)
    end

    it 'should not insert toc at location of toc macro if value of toc attribute is not macro' do
      pdf = to_pdf <<~'EOS', analyze: true
      :doctype: book
      :toc:

      == Chapter

      toc::[]

      text
      EOS

      (expect pdf.find_unique_text 'Table of Contents').not_to be_nil
      (expect pdf.lines pdf.find_text page_number: 2).to eql %w(Chapter text)
    end

    it 'should not start new page for toc in book if already at top of page' do
      pdf = to_pdf <<~EOS, analyze: true
      = Document Title
      :doctype: book
      :toc: macro

      == First Chapter

      #{(['filler'] * 26).join %(\n\n)}

      toc::[]

      == Last Chapter

      Fin.
      EOS

      (expect pdf.pages).to have_size 4
      toc_heading_text = pdf.find_unique_text 'Table of Contents'
      (expect toc_heading_text[:page_number]).to be 3
    end

    it 'should add top margin specified by theme to toc contents when toc has a title' do
      input = <<~'EOS'
      = Document Title
      :toc:

      == Section A

      === Subsection

      == Section B
      EOS

      toc_top_without_margin_top = ((to_pdf input, analyze: true).find_text 'Section A')[0][:y]
      toc_top_with_margin_top = ((to_pdf input, pdf_theme: { toc_margin_top: 50 }, analyze: true).find_text 'Section A')[0][:y]
      (expect toc_top_without_margin_top - toc_top_with_margin_top).to eql 50.0
    end

    it 'should add top margin specified by theme to toc contents when toc has no title and not at page top' do
      input = <<~'EOS'
      = Document Title
      :toc:
      :!toc-title:

      == Section A

      === Subsection

      == Section B
      EOS

      toc_top_without_margin_top = ((to_pdf input, analyze: true).find_text 'Section A')[0][:y]
      toc_top_with_margin_top = ((to_pdf input, pdf_theme: { toc_margin_top: 50 }, analyze: true).find_text 'Section A')[0][:y]
      (expect toc_top_without_margin_top - toc_top_with_margin_top).to eql 50.0
    end

    it 'should not add top margin specified by theme to toc contents when toc contents is at top of page' do
      input = <<~'EOS'
      = Document Title
      :doctype: book
      :toc:
      :!toc-title:

      == Section A

      === Subsection

      == Section B
      EOS

      toc_top_without_margin_top = ((to_pdf input, analyze: true).find_text 'Section A')[0][:y]
      toc_top_with_margin_top = ((to_pdf input, pdf_theme: { toc_margin_top: 50 }, analyze: true).find_text 'Section A')[0][:y]
      (expect toc_top_without_margin_top).to eql toc_top_with_margin_top
    end

    it 'should start preamble toc on recto page for prepress book' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :media: prepress
      :toc: preamble

      In a land far away...

      == First Chapter

      There was a hero...

      == Last Chapter

      Fin.
      EOS

      (expect pdf.pages).to have_size 9
      toc_heading_text = pdf.find_unique_text 'Table of Contents'
      (expect toc_heading_text[:page_number]).to be 5
    end

    it 'should start macro toc on recto page for prepress book' do
      pdf = to_pdf <<~EOS, analyze: true
      = Document Title
      :doctype: book
      :media: prepress
      :toc: macro

      == First Chapter

      #{(['filler'] * 26).join %(\n\n)}

      toc::[]

      == Last Chapter

      Fin.
      EOS

      (expect pdf.pages).to have_size 7
      toc_heading_text = pdf.find_unique_text 'Table of Contents'
      (expect toc_heading_text[:page_number]).to be 5
    end

    it 'should not advance toc to recto page for prepress book when nonfacing option is specified on macro' do
      pdf = to_pdf <<~EOS, analyze: true
      = Document Title
      :doctype: book
      :media: prepress
      :toc: macro

      == First Chapter

      #{(['filler'] * 26).join %(\n\n)}

      toc::[opts=nonfacing]

      == Last Chapter

      Fin.
      EOS

      (expect pdf.pages).to have_size 5
      toc_heading_text = pdf.find_unique_text 'Table of Contents'
      (expect toc_heading_text[:page_number]).to be 4
    end

    it 'should not advance toc in preamble to recto page for prepress book when nonfacing option is specified on macro' do
      pdf = to_pdf <<~EOS, analyze: true
      = Document Title
      :doctype: book
      :media: prepress
      :toc: macro

      [%nonfacing]
      toc::[]

      == First Chapter

      Début.

      == Last Chapter

      Fin.
      EOS

      (expect pdf.pages).to have_size 5
      toc_heading_text = pdf.find_unique_text 'Table of Contents'
      (expect toc_heading_text[:page_number]).to be 2
    end

    it 'should disable running content periphery on toc page if noheader or nofooter option is set on macro' do
      pdf_theme = {
        header_height: 30,
        header_font_color: 'FF0000',
        header_recto_right_content: 'Page {page-number}',
        header_verso_right_content: 'Page {page-number}',
        footer_font_color: '0000FF',
        footer_recto_right_content: 'Page {page-number}',
        footer_verso_right_content: 'Page {page-number}',
      }

      sections = (1..37).map {|num| %(== Section #{num}) }.join %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :toc: macro

      == First Chapter

      #{sections}

      [%noheader%nofooter]
      toc::[]

      == Last Chapter
      EOS

      toc_text = (pdf.find_text 'Table of Contents')[0]
      (expect toc_text).not_to be_nil
      toc_page_number = toc_text[:page_number]
      last_chapter_text = (pdf.find_text 'Last Chapter')[-1]
      last_chapter_page_number = last_chapter_text[:page_number]
      toc_page_number.upto last_chapter_page_number do |page_number|
        header_texts = (pdf.find_text font_color: 'FF0000', page_number: page_number)
        footer_texts = (pdf.find_text font_color: '0000FF', page_number: page_number)
        if page_number < last_chapter_page_number
          (expect header_texts).to be_empty
          (expect footer_texts).to be_empty
        else
          (expect header_texts).not_to be_empty
          (expect footer_texts).not_to be_empty
        end
      end
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

    it 'should not attempt to create dots if number of dots is less than 0' do
      section_title = (%w(verylongsectiontitle) * 5).join
      pdf = to_pdf <<~EOS, doctype: :book, analyze: true
      :toc:
      :toc-max-pagenum-digits: 0

      == #{section_title}
      EOS

      toc_lines = pdf.lines pdf.find_text page_number: 1
      (expect toc_lines).to have_size 2
      (expect toc_lines[0]).to eql 'Table of Contents'
      (expect toc_lines[1]).to eql %(#{section_title}\u00a01)
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

    it 'should line up dots and page number with wrapped line when section title gets split across a page boundary' do
      sections = (1..37).map {|num| %(\n\n== Section #{num}) }.join
      pdf = to_pdf <<~EOS, doctype: :book, analyze: true
      = Document Title
      :toc:
      #{sections}

      == This is a unbelievably long section title that probably shouldn't be a section title at all but here we are

      content
      EOS

      page_2_lines = pdf.lines pdf.find_text page_number: 2
      (expect page_2_lines).to include 'Table of Contents'
      (expect page_2_lines[-1]).to end_with 'but here'
      page_3_lines = pdf.lines pdf.find_text page_number: 3
      (expect page_3_lines).to have_size 1
      (expect page_3_lines[0]).to match %r/we are ?(\. )+ ?\u00a038$/
    end

    it 'should not crash if last fragment in toc entry is not rendered' do
      (expect do
        pdf = to_pdf <<~EOS, analyze: true
        = Document Title
        :notitle:
        :!toc-title:
        :toc:
        :doctype: book

        == Chapter

        == #{(['foo bar'] * 12).join ' '} foo +++<span><br></span>+++
        EOS

        toc_lines = pdf.lines pdf.find_text page_number: 1
        (expect toc_lines).to have_size 2
        (expect toc_lines[1]).to end_with %(foo . . \u00a02)
      end).to not_raise_exception
    end

    it 'should not crash if last fragment in toc entry that wraps is not rendered' do
      (expect do
        pdf = to_pdf <<~EOS, analyze: true
        = Document Title
        :notitle:
        :!toc-title:
        :toc:
        :doctype: book

        == Chapter

        == #{(['foo bar'] * 24).join ' '} foo foo +++<span><br></span>+++
        EOS

        toc_lines = pdf.lines pdf.find_text page_number: 1
        (expect toc_lines).to have_size 3
        (expect toc_lines[2]).to end_with %(foo . . \u00a02)
      end).to not_raise_exception
    end

    it 'should not crash if theme does not specify toc_indent' do
      (expect do
        pdf = to_pdf <<~'EOS', attributes: { 'pdf-theme' => (fixture_file 'custom-theme.yml') }, analyze: true
        = Document Title
        :toc:

        == Section
        EOS

        toc_text = pdf.find_unique_text %r/Table of Contents/
        (expect toc_text).not_to be_nil
        (expect toc_text[:font_name]).to eql 'Times-Roman'
      end).to not_raise_exception
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

    it 'should allow theme to control font size of dot leader' do
      pdf = to_pdf <<~'EOS', pdf_theme: { toc_dot_leader_font_size: '0.5em' }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Foo

      == Bar
      EOS

      reference_text = pdf.find_unique_text 'Foo', page_number: 2
      dot_leader_texts = pdf.find_text %r/(?:\. )+/, page_number: 2
      (expect dot_leader_texts).not_to be_empty
      dot_leader_texts.each do |text|
        (expect text[:font_size]).to eql (reference_text[:font_size] * 0.5)
      end
    end

    it 'should allow theme to control font style of dot leader' do
      pdf = to_pdf <<~'EOS', pdf_theme: { toc_dot_leader_font_style: 'bold' }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Foo
      EOS

      dot_leader_text = pdf.find_unique_text %r/(?:\. )+/
      (expect dot_leader_text[:font_name]).to eql 'NotoSerif-Bold'
    end

    it 'should allow theme to disable dot leader by setting content to empty string' do
      pdf = to_pdf <<~'EOS', pdf_theme: { toc_dot_leader_content: '' }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Foo

      == Bar

      == Baz
      EOS

      toc_lines = (pdf.lines pdf.find_text page_number: 2).join ?\n
      (expect toc_lines).to include 'Foo'
      (expect toc_lines).to include 'Bar'
      (expect toc_lines).to include 'Baz'
      (expect toc_lines).not_to include '.'
    end

    it 'should allow theme to disable dot leader by setting levels to none' do
      pdf = to_pdf <<~'EOS', pdf_theme: { toc_dot_leader_levels: 'none' }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Foo

      == Bar

      == Baz
      EOS

      toc_lines = (pdf.lines pdf.find_text page_number: 2).join ?\n
      (expect toc_lines).to include 'Foo'
      (expect toc_lines).to include 'Bar'
      (expect toc_lines).to include 'Baz'
      (expect toc_lines).not_to include '.'
    end

    it 'should allow theme to disable dot leader for nested levels' do
      pdf = to_pdf <<~'EOS', pdf_theme: { toc_dot_leader_levels: 1 }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Foo

      === Foo Subsection

      == Bar

      === Bar Subsection

      == Baz

      === Baz Subsection
      EOS

      toc_lines = pdf.lines.select {|it| it.include? 'Subsection' }.join ?\n
      (expect toc_lines).to include 'Foo Subsection'
      (expect toc_lines).to include 'Bar Subsection'
      (expect toc_lines).to include 'Baz Subsection'
      (expect toc_lines).not_to include '.'
    end

    it 'should allow theme to enable dot leader per level' do
      pdf = to_pdf <<~'EOS', pdf_theme: { toc_dot_leader_levels: '1 3' }, analyze: true
      = Book Title
      :doctype: book
      :toc:
      :toclevels: 3

      == Foo Top

      === Foo Subsection

      ==== Foo Deep

      == Bar Top

      === Bar Subsection

      ==== Bar Deep

      == Baz Top

      === Baz Subsection

      ==== Baz Deep
      EOS

      lines = pdf.lines

      main_section_toc_lines = lines.select {|it| it.include? 'Top' }.join ?\n
      (expect main_section_toc_lines).to include 'Foo Top'
      (expect main_section_toc_lines).to include 'Bar Top'
      (expect main_section_toc_lines).to include 'Baz Top'
      (expect main_section_toc_lines).to include '.'

      subsection_toc_lines = lines.select {|it| it.include? 'Subsection' }.join ?\n
      (expect subsection_toc_lines).to include 'Foo Subsection'
      (expect subsection_toc_lines).to include 'Bar Subsection'
      (expect subsection_toc_lines).to include 'Baz Subsection'
      (expect subsection_toc_lines).not_to include '.'

      deep_section_toc_lines = lines.select {|it| it.include? 'Deep' }.join ?\n
      (expect deep_section_toc_lines).to include 'Foo Deep'
      (expect deep_section_toc_lines).to include 'Bar Deep'
      (expect deep_section_toc_lines).to include 'Baz Deep'
      (expect deep_section_toc_lines).to include '.'
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
      (expect lines[1]).to start_with 'I: P1'
      (expect lines[3]).to start_with 'II: P2'
      (expect pdf.find_text 'Part I: P1').to have_size 1
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
      (expect pdf.find_text 'Table of Contents', page_number: 1).to have_size 1
      (expect pdf.find_text 'Introduction', page_number: 1).to have_size 2
      doctitle_text = (pdf.find_text 'Document Title')[0]
      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      toc_bottom_text = (pdf.find_text '2')[0]
      content_top_text = (pdf.find_text 'Preamble')[0]
      (expect doctitle_text[:y]).to be > toc_title_text[:y]
      (expect toc_title_text[:y]).to be > content_top_text[:y]
      (expect toc_bottom_text[:y]).to be > content_top_text[:y]
      # NOTE: assert there's no excess gap between end of toc and start of content
      (expect toc_bottom_text[:y] - content_top_text[:y]).to be < 35
    end

    it 'should insert toc at top of first page if toc is set and document has no doctitle' do
      pdf = to_pdf <<~'EOS', analyze: true
      :toc:

      == Section A

      == Section B
      EOS

      toc_title_text = (pdf.find_text 'Table of Contents')[0]
      sect_a_text = (pdf.find_text 'Section A', font_size: 22)[0]
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
        idx_content_top = idx if candidate[:string] == 'Section 1' && candidate[:font_size] == 22
      end
      (expect text[idx_toc_bottom][:y]).to be > text[idx_content_top][:y]
      # NOTE: assert there's no excess gap between end of toc and start of content
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

    it 'should not force page break after toc when title-page attribute is set and toc-break-after is auto' do
      pdf = to_pdf <<~'EOS', pdf_theme: { toc_break_after: 'auto' }, analyze: true
      = Document Title
      :title-page:
      :toc:

      == Introduction

      == Main

      == Conclusion
      EOS
      (expect pdf.pages).to have_size 2
      (expect pdf.find_unique_text 'Document Title', page_number: 1).not_to be_nil
      (expect pdf.find_unique_text 'Table of Contents', page_number: 2).not_to be_nil
      (expect pdf.find_unique_text 'Introduction', page_number: 2, font_name: 'NotoSerif-Bold').not_to be_nil
      (expect pdf.find_unique_text 'Conclusion', page_number: 2, font_name: 'NotoSerif-Bold').not_to be_nil
      (expect (pdf.find_unique_text 'Introduction', page_number: 2, font_name: 'NotoSerif-Bold')[:y]).to be <
        (pdf.find_unique_text 'Conclusion', page_number: 2, font_name: 'NotoSerif')[:y]
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
      (expect pdf.find_text 'Table of Contents', page_number: 1).to have_size 1
      (expect pdf.find_text 'Introduction', page_number: 1).to have_size 2
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
      (expect toc_dest[:pagenum]).to be 1
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
      (expect section_entry_children).to have_size 3
      toc_entry = section_entry_children[1]
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
    pdf_theme = {
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
    to_file = to_pdf_file <<~'EOS', 'toc-running-content-font-color.pdf', pdf_theme: pdf_theme
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

  it 'should use same font color for text and dot leader if dot leader font color is unspecified' do
    pdf_theme = {
      extends: 'base',
      toc_font_color: '4a4a4a',
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title
    Author Name
    :doctype: book
    :toc:

    == Intro

    text

    == Conclusion

    text
    EOS

    intro_entry_font_color = (pdf.find_unique_text 'Intro', page_number: 2)[:font_color]
    dot_leader_font_color = (pdf.find_text page_number: 2).select {|it| it[:string].start_with? '.' }.map {|it| it[:font_color] }.uniq[0]
    (expect dot_leader_font_color).to eql intro_entry_font_color
  end

  it 'should not apply bold to italic text if headings are bold in theme' do
    pdf_theme = {
      toc_font_style: 'bold',
    }

    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    = Document Title
    :doctype: book
    :toc:

    == Get Started _Quickly_
    EOS

    get_started_text = (pdf.find_text page_number: 2, string: /^Get Started/)[0]
    quickly_text = (pdf.find_text page_number: 2, string: 'Quickly')[0]
    (expect get_started_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect quickly_text[:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should allow theme to specify text decoration for entries in toc' do
    pdf_theme = {
      toc_text_decoration: 'underline',
    }
    input = <<~'EOS'
    = Document Title
    :toc:
    :title-page:

    == Underline Me
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
    lines = pdf.lines
    (expect lines).to have_size 1
    toc_entry_underline = lines[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    toc_entry_text = (pdf.find_text page_number: 2, string: 'Underline Me')[0]
    (expect toc_entry_underline[:from][:x]).to eql toc_entry_text[:x]
    (expect toc_entry_underline[:from][:y]).to be_within(2).of(toc_entry_text[:y])
    (expect toc_entry_underline[:color]).to eql toc_entry_text[:font_color]
  end

  it 'should allow theme to specify color and width of text decoration for entries in toc' do
    pdf_theme = {
      toc_text_decoration: 'underline',
      toc_text_decoration_color: 'cccccc',
      toc_text_decoration_width: 0.5,
    }
    input = <<~'EOS'
    = Document Title
    :toc:
    :title-page:

    == Underline Me
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
    lines = pdf.lines
    (expect lines).to have_size 1
    toc_entry_underline = lines[0]
    (expect toc_entry_underline[:color]).to eql 'CCCCCC'
    (expect toc_entry_underline[:width]).to eql 0.5
  end

  it 'should use fallback value to align toc title if alignment not specified in theme' do
    [
      {
        toc_title_text_align: 'center',
        heading_h2_text_align: 'left',
        heading_text_align: 'left',
      },
      {
        toc_title_text_align: nil,
        heading_h2_text_align: 'center',
        heading_text_align: 'left',
      },
      {
        toc_title_text_align: nil,
        heading_h2_text_align: nil,
        heading_text_align: 'center',
      },
      {
        toc_title_text_align: nil,
        heading_h2_text_align: nil,
        heading_text_align: nil,
        base_text_align: 'center',
      },
    ].each do |pdf_theme|
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :toc:
      :doctype: book

      == Section A

      == Section B
      EOS
      toc_title_text = pdf.find_unique_text 'Table of Contents'
      (expect toc_title_text[:x]).to be > 48.24
    end
  end

  it 'should allow theme to specify text decoration per heading level in toc' do
    pdf_theme = {
      toc_h3_text_decoration: 'underline',
      toc_h3_text_decoration_color: 'cccccc',
      toc_h3_text_decoration_width: 0.5,
    }
    input = <<~'EOS'
    = Document Title
    :toc:
    :title-page:

    == Plain Title

    === Decorated Title
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
    lines = pdf.lines
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    underlined_toc_entry_text = pdf.find_unique_text 'Decorated Title', page_number: 2
    (expect lines).to have_size 1
    toc_entry_underline = lines[0]
    (expect toc_entry_underline[:color]).to eql 'CCCCCC'
    (expect toc_entry_underline[:width]).to eql 0.5
    (expect toc_entry_underline[:from][:y]).to be < underlined_toc_entry_text[:y]
    (expect toc_entry_underline[:from][:y]).to be_within(2).of(underlined_toc_entry_text[:y])
  end

  it 'should allow theme to specify text transform for entries in toc' do
    pdf_theme = {
      toc_text_transform: 'uppercase',
    }
    input = <<~'EOS'
    = Document Title
    :doctype: book
    :toc:

    == Transform Me
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    toc_lines = pdf.lines pdf.find_text page_number: 2
    (expect toc_lines.join ?\n).to include 'TRANSFORM ME'
  end

  it 'should decode character references in toc entries' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    :toc:

    == Paper Clips &#x2116;&nbsp;4
    EOS

    (expect pdf.find_text %(Paper Clips \u2116\u00a04)).to have_size 2
  end

  it 'should not crash if section title is empty' do
    pdf = to_pdf <<~'EOS', analyze: true
    :toc:

    == {empty}

    content
    EOS

    (expect pdf.text).to have_size 2
    (expect pdf.find_unique_text 'content').not_to be_nil
    (expect pdf.find_unique_text 'Table of Contents').not_to be_nil
  end

  it 'should allocate correct number of pages for toc if line numbers cause lines to wrap' do
    chapter_title = %(\n\n== A long chapter title that wraps to a second line in the toc when the page number exceeds one digit)

    input = <<~EOS
    = Document Title
    :doctype: book
    :toc:
    :nofooter:
    #{chapter_title * 38}
    EOS

    pdf = to_pdf input, analyze: true
    last_pagenum_text = (pdf.find_text '38')[0]
    first_chapter_text = (pdf.find_text font_name: 'NotoSerif-Bold', font_size: 22, string: /^A long chapter title/)[0]
    (expect first_chapter_text[:page_number]).to be last_pagenum_text[:page_number].next
  end

  it 'should render image at end of section title in toc entry' do
    pdf = to_pdf <<~'EOS', analyze: :image
    = Document Title
    :doctype: book
    :toc:

    == Chapter image:tux.png[,16]
    EOS

    images = pdf.images
    (expect images).to have_size 2
    (expect images[0][:page_number]).to be 2
    (expect images[1][:page_number]).to be 3
    (expect images[0][:data]).to eql images[1][:data]
    (expect images[0][:width]).to eql images[1][:width]
  end

  it 'should allow extended converter to insert extra page before toc' do
    backend = nil
    create_class (Asciidoctor::Converter.for 'pdf') do
      register_for (backend = %(pdf#{object_id}).to_sym)
      def ink_toc doc, num_levels, toc_page_number, start_cursor, num_front_matter_pages = 0
        go_to_page toc_page_number unless (page_number == toc_page_number) || scratch?
        unless scratch?
          theme_font :heading, level: 2 do
            ink_heading 'Extra', level: 2
          end
          go_to_page page_number + 1
        end
        offset = 1
        toc_page_numbers = super doc, num_levels, (toc_page_number + offset), start_cursor, num_front_matter_pages
        scratch? ? ((toc_page_numbers.begin - offset)..toc_page_numbers.end) : toc_page_numbers
      end
    end

    input = <<~'EOS'
    = Document Title
    :doctype: book
    :toc:

    == Chapter A

    == Chapter B
    EOS

    pdf = to_pdf input, backend: backend, analyze: true
    (expect pdf.pages).to have_size 5
    [['Extra', 2], ['Table of Contents', 3], ['Chapter A', 4]].each do |title, pnum|
      title_text = (pdf.find_text title)[-1]
      (expect title_text[:page_number]).to eql pnum
    end
    (expect (pdf.find_text 'Chapter A')[0][:page_number]).to eql 3
    (expect (pdf.find_text 'Chapter B')[0][:page_number]).to eql 3
  end

  it 'should allow extended converter to insert extra entries into TOC' do
    backend = nil
    create_class (Asciidoctor::Converter.for 'pdf') do
      register_for (backend = %(pdf#{object_id}).to_sym)
      def get_entries_for_toc node
        return super if node.context == :document
        node.blocks.select(&:id)
      end
    end

    input = <<~'EOS'
    = Document Title
    :doctype: book
    :toc:

    == Chapter A

    .Check for Ruby
    [#check-for-ruby]
    ****
    Run `ruby -v` to check if you have Ruby installed.
    ****

    <<<

    === Section

    == Chapter B

    [#screenshot,reftext=Screenshot]
    image::tux.png[]

    === Another Section
    EOS

    pdf = to_pdf input, backend: backend, analyze: true
    (expect pdf.pages).to have_size 5
    toc_text = (pdf.find_text page_number: 2).reject {|it| it[:string] == 'Table of Contents' }
    toc_lines = pdf.lines toc_text
    [['Chapter A', 1], ['Check for Ruby', 1], ['Section', 2], ['Chapter B', 3], ['Screenshot', 3], ['Another Section', 3]].each_with_index do |(title, pnum), idx|
      line = toc_lines[idx]
      (expect line).to start_with title
      (expect line).to end_with pnum.to_s
    end

    pdf = to_pdf input, backend: backend
    annots = get_annotations pdf, 2
    (expect annots.select {|it| it[:Dest] == 'check-for-ruby' }).to have_size 2
    (expect annots.select {|it| it[:Dest] == 'screenshot' }).to have_size 2
  end

  it 'should allow extended converter to insert chapter per TOC' do
    source_file = doc_file 'modules/extend/examples/pdf-converter-chapter-toc.rb'
    source_lines = (File.readlines source_file).select {|l| l == ?\n || (l.start_with? ' ') }
    ext_class = create_class Asciidoctor::Converter.for 'pdf'
    backend = %(pdf#{ext_class.object_id})
    source_lines[0] = %(  register_for '#{backend}'\n)
    ext_class.class_eval source_lines.join, source_file
    pdf = to_pdf <<~'EOS', backend: backend, analyze: true
    = Document Title
    :doctype: book
    :toc:
    :toclevels: 1
    :chapter-toc:
    :chapter-toclevels: 2

    == Chapter Title

    === First Section

    ==== Subsection

    <<<

    === Last Section

    == Another Chapter
    EOS

    toc_text = pdf.find_text page_number: 2
    toc_lines = toc_text
      .sort_by {|it| -it[:y] }
      .group_by {|it| it[:y] }
      .map {|_, it| it.sort_by {|fragment| fragment[:order] }.map {|fragment| fragment[:string] }.join }
    (expect toc_lines).to have_size 3
    (expect toc_lines[0]).to eql 'Table of Contents'
    (expect toc_lines[1]).to start_with 'Chapter Title'
    (expect toc_lines[1]).to end_with '1'
    (expect toc_lines[2]).to start_with 'Another Chapter'
    (expect toc_lines[2]).to end_with '3'

    ch1_text = pdf.find_text page_number: 3
    ch1_lines = ch1_text
      .sort_by {|it| -it[:y] }
      .group_by {|it| it[:y] }
      .map {|_, it| it.sort_by {|fragment| fragment[:order] }.map {|fragment| fragment[:string] }.join }
    (expect ch1_lines).to have_size 6
    (expect ch1_lines[0]).to eql 'Chapter Title'
    (expect ch1_lines[1]).to start_with 'First Section'
    (expect ch1_lines[1]).to end_with '1'
    (expect ch1_lines[2]).to start_with 'Subsection'
    (expect ch1_lines[2]).to end_with '1'
    (expect ch1_lines[3]).to start_with 'Last Section'
    (expect ch1_lines[3]).to end_with '2'
    (expect ch1_lines[4]).to eql 'First Section'
    (expect ch1_lines[5]).to eql 'Subsection'
  end
end
