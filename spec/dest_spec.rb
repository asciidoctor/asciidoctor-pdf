# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Dest' do
  it 'should not define a dest named __anchor-top if document has no body pages' do
    pdf = to_pdf <<~'END'
    = Document Title
    :doctype: book
    END
    (expect get_names pdf).to be_empty
  end

  it 'should define a dest named __anchor-top at top of the first body page' do
    pdf = to_pdf <<~'END'
    = Document Title
    :doctype: book
    :toc:

    preamble

    == Chapter

    content
    END

    (expect (top_dest = get_dest pdf, '__anchor-top')).not_to be_nil
    (expect (top_dest[:page_number])).to be 3
    _, page_height = get_page_size pdf, top_dest[:page_number]
    (expect top_dest[:y]).to eql page_height
  end

  it 'should define a dest named toc at the top of the first toc page' do
    pdf = to_pdf <<~'END'
    = Document Title
    :doctype: book
    :toc:

    == Chapter
    END

    (expect (toc_dest = get_dest pdf, 'toc')).not_to be_nil
    (expect toc_dest[:page_number]).to be 2
    _, page_height = get_page_size pdf, toc_dest[:page_number]
    (expect toc_dest[:y]).to eql page_height
  end

  it 'should define a dest named toc at the location where the macro toc starts' do
    pdf = to_pdf <<~'END'
    = Document Title
    :toc: macro

    content before the toc

    toc::[]

    == Chapter

    == Another Chapter
    END

    (expect (toc_dest = get_dest pdf, 'toc')).not_to be_nil
    (expect (toc_dest[:page_number])).to be 1
    _, page_height = get_page_size pdf, toc_dest[:page_number]
    (expect toc_dest[:y]).to be < page_height
  end

  it 'should use the toc macro ID as the name of the dest for the macro toc' do
    pdf = to_pdf <<~'END'
    = Document Title
    :toc: macro

    content before the toc

    [#macro-toc]
    toc::[]

    == Chapter

    == Another Chapter
    END

    (expect get_names pdf).to have_key 'macro-toc'
  end

  it 'should define a dest at the top of a chapter page' do
    pdf = to_pdf <<~'END'
    = Document Title
    :doctype: book

    == Chapter
    END

    (expect (chapter_dest = get_dest pdf, '_chapter')).not_to be_nil
    (expect (chapter_dest[:page_number])).to be 2
    _, page_height = get_page_size pdf, chapter_dest[:page_number]
    (expect chapter_dest[:y]).to eql page_height
  end

  it 'should define a dest at the top of a part page' do
    pdf = to_pdf <<~'END'
    = Document Title
    :doctype: book

    = Part 1

    == Chapter

    content
    END

    (expect (part_dest = get_dest pdf, '_part_1')).not_to be_nil
    (expect (part_dest[:page_number])).to be 2
    _, page_height = get_page_size pdf, part_dest[:page_number]
    (expect part_dest[:y]).to eql page_height
  end

  it 'should define a dest at the top of page for section if section is at top of page' do
    pdf = to_pdf <<~'END'
    = Document Title

    content

    <<<

    == Section

    content
    END

    (expect (sect_dest = get_dest pdf, '_section')).not_to be_nil
    (expect (sect_dest[:page_number])).to be 2
    _, page_height = get_page_size pdf, sect_dest[:page_number]
    (expect sect_dest[:y]).to eql page_height
  end

  it 'should define a dest at the top of content area if page does not start with a section' do
    pdf_theme = { page_margin: 15 }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme
    [#p1]
    content
    END

    (expect (para_dest = get_dest pdf, 'p1')).not_to be_nil
    (expect (para_dest[:page_number])).to be 1
    _, page_height = get_page_size pdf, para_dest[:page_number]
    (expect para_dest[:y]).to eql page_height - 15
  end

  it 'should register dest for every block that has an ID' do
    ['', 'abstract', 'example', 'open', 'sidebar', 'quote', 'verse', 'listing', 'literal', 'NOTE'].each do |style|
      pdf = to_pdf <<~END
      [#{style}#disclaimer]
      All views expressed are my own.
      END

      (expect get_names pdf).to have_key 'disclaimer'
    end
  end

  it 'should register dest for table that has an ID' do
    pdf = to_pdf <<~'END'
    [#props]
    |===
    | Name | Value

    | Foo | Bar
    |===
    END

    (expect get_names pdf).to have_key 'props'
  end

  it 'should register dest for media macro that has an ID' do
    {
      image: 'tux.png',
      svg: 'green-bar.svg',
      video: 'webcast.mp4',
      audio: 'podcast.mp3',
    }.each do |macro_name, target|
      pdf = to_pdf <<~END
      [#media]
      #{macro_name == :svg ? 'image' : macro_name.to_s}::#{target}[]
      END

      (expect get_names pdf).to have_key 'media'
    end
  end

  it 'should register dest for unordered list that has an ID' do
    pdf = to_pdf <<~'END'
    [#takeaways]
    * one
    * two
    END

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for ordered list that has an ID' do
    pdf = to_pdf <<~'END'
    [#takeaways]
    . one
    . two
    END

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for description list that has an ID' do
    pdf = to_pdf <<~'END'
    [#takeaways]
    reuse:: try to avoid binning it in the first place
    recycle:: if you do bin it, make sure the material gets reused
    END

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for callout list that has an ID' do
    pdf = to_pdf <<~'END'
    ----
    require 'asciidoctor-pdf' // <1>

    Asciidoctor.convert_file 'doc.adoc', backend: 'pdf', safe: :safe // <2>
    ----
    [#details]
    <1> requires the library
    <2> converts the document to PDF
    END

    (expect get_names pdf).to have_key 'details'
  end

  it 'should register dest for each section with implicit ID' do
    pdf = to_pdf <<~'END'
    == Fee

    === Fi

    ==== Fo

    ===== Fum
    END

    names = get_names pdf
    (expect names).to have_key '_fee'
    (expect names).to have_key '_fi'
    (expect names).to have_key '_fo'
    (expect names).to have_key '_fum'
  end

  it 'should register dest for each section with explicit ID' do
    pdf = to_pdf <<~'END'
    [#s-fee]
    == Fee

    [#s-fi]
    === Fi

    [#s-fo]
    ==== Fo

    [#s-fum]
    ===== Fum
    END

    names = get_names pdf
    (expect names).to have_key 's-fee'
    (expect names).to have_key 's-fi'
    (expect names).to have_key 's-fo'
    (expect names).to have_key 's-fum'
  end

  it 'should not register dest with auto-generated name for each section if sectids are disabled' do
    pdf = to_pdf <<~'END'
    :!sectids:

    == Fee

    === Fi

    ==== Fo

    ===== Fum
    END

    names = get_names pdf
    names.delete '__anchor-top'
    (expect names).to have_size 4
    names.each_key do |name|
      (expect name).to start_with '__anchor-'
    end
  end

  it 'should register dest for a discrete heading with an implicit ID' do
    pdf = to_pdf <<~'END'
    [discrete]
    == Bundler

    Use this procedure if you're using Bundler.
    END

    (expect get_names pdf).to have_key '_bundler'
  end

  it 'should not register dest for a discrete heading when sectids are disabled' do
    pdf = to_pdf <<~'END'
    :!sectids:

    [discrete]
    == Bundler

    Use this procedure if you're using Bundler.
    END

    names = get_names pdf
    names.delete '__anchor-top'
    (expect names).to be_empty
  end

  it 'should register dest for a discrete heading with an explicit ID' do
    pdf = to_pdf <<~'END'
    [discrete#bundler]
    == Bundler

    Use this procedure if you're using Bundler.
    END

    (expect get_names pdf).to have_key 'bundler'
  end

  it 'should register dest for a link with an ID' do
    pdf = to_pdf <<~'END'
    see <<link,link>>

    <<<

    https://asciidoctor.org[Asciidoctor,id=link]
    END

    (expect (link_dest = get_dest pdf, 'link')).not_to be_nil
    (expect link_dest[:page_number]).to be 2
  end

  it 'should hex encode name for ID that contains non-ASCII characters' do
    pdf = to_pdf '== Über Étudier'
    hex_encoded_id = %(0x#{('_über_étudier'.unpack 'H*')[0]})
    names = (get_names pdf).keys.reject {|k| k == '__anchor-top' }
    (expect names).to have_size 1
    name = names[0]
    (expect name).to eql hex_encoded_id
  end

  it 'should define a dest at the location of an inline anchor' do
    ['[[details]]details', '[#details]#details#'].each do |details|
      pdf = to_pdf <<~END
      Here's the intro.

      <<<

      Here are all the #{details}.
      END

      (expect (phrase_dest = get_dest pdf, 'details')).not_to be_nil
      (expect phrase_dest[:page_number]).to be 2
    end
  end

  it 'should keep anchor with text if text is advanced to next page' do
    pdf = to_pdf <<~END
    jump to <<anchor>>

    #{(['paragraph'] * 25).join %(\n\n)}

    #{(['paragraph'] * 16).join ' '} [#anchor]#supercalifragilisticexpialidocious#
    END

    (expect (phrase_dest = get_dest pdf, 'anchor')).not_to be_nil
    (expect phrase_dest[:page_number]).to be 2
    (expect (pdf.page phrase_dest[:page_number]).text).to eql 'supercalifragilisticexpialidocious'
  end

  it 'should not allocate space for anchor if font is missing glyph for null character' do
    pdf_theme = {
      extends: 'default',
      font_catalog: {
        'Missing Null' => {
          'normal' => (fixture_file 'mplus1mn-regular-ascii.ttf'),
        },
      },
      base_font_family: 'Missing Null',
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    foo [#bar]#bar# #baz#

    foo bar #baz#
    END

    baz_texts = pdf.find_text 'baz'
    (expect baz_texts).to have_size 2
    (expect baz_texts[0][:x]).to eql baz_texts[1][:x]
  end
end
