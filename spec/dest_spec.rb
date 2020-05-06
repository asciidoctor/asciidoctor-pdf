# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Dest' do
  it 'should define a dest named __anchor-top at top of the first body page' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book
    :toc:

    preamble

    == Chapter

    content
    EOS

    names = get_names pdf
    (expect names).to have_key '__anchor-top'
    top_dest = pdf.objects[names['__anchor-top']]
    top_page_num = get_page_number pdf, top_dest[0]
    top_y = top_dest[3]
    (expect top_page_num).to be 3
    _, page_height = get_page_size pdf, top_page_num
    (expect top_y).to eql page_height
  end

  it 'should define a dest named toc at the top of the first toc page' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book
    :toc:

    == Chapter
    EOS

    names = get_names pdf
    (expect names).to have_key 'toc'
    toc_dest = pdf.objects[names['toc']]
    toc_page_num = get_page_number pdf, toc_dest[0]
    toc_y = toc_dest[3]
    (expect toc_page_num).to be 2
    _, page_height = get_page_size pdf, toc_page_num
    (expect toc_y).to eql page_height
  end

  it 'should define a dest named toc at the location where the macro toc starts' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :toc: macro

    content before the toc

    toc::[]

    == Chapter

    == Another Chapter
    EOS

    names = get_names pdf
    (expect names).to have_key 'toc'
    toc_dest = pdf.objects[names['toc']]
    toc_page_num = get_page_number pdf, toc_dest[0]
    toc_y = toc_dest[3]
    (expect toc_page_num).to be 1
    _, page_height = get_page_size pdf, toc_page_num
    (expect toc_y).to be < page_height
  end

  it 'should use the toc macro ID as the name of the dest for the macro toc' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :toc: macro

    content before the toc

    [#macro-toc]
    toc::[]

    == Chapter

    == Another Chapter
    EOS

    names = get_names pdf
    (expect names).to have_key 'macro-toc'
  end

  it 'should register dest for every block that has an ID' do
    ['', 'abstract', 'example', 'open', 'sidebar', 'quote', 'verse', 'listing', 'literal', 'NOTE'].each do |style|
      pdf = to_pdf <<~EOS
      [#{style}#disclaimer]
      All views expressed are my own.
      EOS

      names = get_names pdf
      (expect names).to have_key 'disclaimer'
    end
  end

  it 'should register dest for table that has an ID' do
    pdf = to_pdf <<~'EOS'
    [#props]
    |===
    | Name | Value

    | Foo | Bar
    |===
    EOS

    names = get_names pdf
    (expect names).to have_key 'props'
  end

  it 'should register dest for media macro that has an ID' do
    {
      image: 'tux.png',
      svg: 'green-bar.svg',
      video: 'webcast.mp4',
      audio: 'podcast.mp3',
    }.each do |macro_name, target|
      pdf = to_pdf <<~EOS
      [#media]
      #{macro_name == :svg ? 'image' : macro_name.to_s}::#{target}[]
      EOS

      names = get_names pdf
      (expect names).to have_key 'media'
    end
  end

  it 'should register dest for unordered list that has an ID' do
    pdf = to_pdf <<~'EOS'
    [#takeaways]
    * one
    * two
    EOS

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for ordered list that has an ID' do
    pdf = to_pdf <<~'EOS'
    [#takeaways]
    . one
    . two
    EOS

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for description list that has an ID' do
    pdf = to_pdf <<~'EOS'
    [#takeaways]
    reuse:: try to avoid binning it in the first place
    recycle:: if you do bin it, make sure the material gets reused
    EOS

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for callout list that has an ID' do
    pdf = to_pdf <<~'EOS'
    ----
    require 'asciidoctor-pdf' // <1>

    Asciidoctor.convert_file 'doc.adoc', backend: 'pdf', safe: :safe // <2>
    ----
    [#details]
    <1> requires the library
    <2> converts the document to PDF
    EOS

    (expect get_names pdf).to have_key 'details'
  end

  it 'should register dest for each section with implicit ID' do
    pdf = to_pdf <<~'EOS'
    == Fee

    === Fi

    ==== Fo

    ===== Fum
    EOS

    names = get_names pdf
    (expect names).to have_key '_fee'
    (expect names).to have_key '_fi'
    (expect names).to have_key '_fo'
    (expect names).to have_key '_fum'
  end

  it 'should register dest for each section with explicit ID' do
    pdf = to_pdf <<~'EOS'
    [#s-fee]
    == Fee

    [#s-fi]
    === Fi

    [#s-fo]
    ==== Fo

    [#s-fum]
    ===== Fum
    EOS

    names = get_names pdf
    (expect names).to have_key 's-fee'
    (expect names).to have_key 's-fi'
    (expect names).to have_key 's-fo'
    (expect names).to have_key 's-fum'
  end

  it 'should register dest for a discrete heading with an ID' do
    pdf = to_pdf <<~'EOS'
    [#bundler]
    == Bundler

    Use this procedure if you're using Bundler.
    EOS

    (expect get_names pdf).to have_key 'bundler'
  end

  it 'should hex encode name for ID that contains non-ASCII characters' do
    pdf = to_pdf '== Über Étudier'
    hex_encoded_id = %(0x#{('_über_étudier'.unpack 'H*')[0]})
    names = (get_names pdf).keys.reject {|k| k == '__anchor-top' }
    (expect names).to have_size 1
    name = names[0]
    (expect name).to eql hex_encoded_id
  end if RUBY_VERSION >= '2.4.0'

  it 'should define a dest at the location of an inline anchor' do
    ['[[details]]details', '[#details]#details#'].each do |details|
      pdf = to_pdf <<~EOS
      Here's the intro.

      <<<

      Here are all the #{details}.
      EOS

      names = get_names pdf
      (expect names).to have_key 'details'
      details_dest = pdf.objects[names['details']]
      details_dest_pagenum = get_page_number pdf, details_dest[0]
      (expect details_dest_pagenum).to be 2
    end
  end

  it 'should keep anchor with text if text is advanced to next page' do
    pdf = to_pdf <<~EOS
    jump to <<anchor>>

    #{(['paragraph'] * 25).join %(\n\n)}

    #{(['paragraph'] * 16).join ' '} [#anchor]#supercalifragilisticexpialidocious#
    EOS

    names = get_names pdf
    (expect names).to have_key 'anchor'
    anchor_dest = pdf.objects[names['anchor']]
    anchor_dest_pagenum = get_page_number pdf, anchor_dest[0]
    (expect anchor_dest_pagenum).to be 2
    (expect (pdf.page 2).text).to eql 'supercalifragilisticexpialidocious'
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

    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    foo [#bar]#bar# #baz#

    foo bar #baz#
    EOS

    baz_texts = pdf.find_text 'baz'
    (expect baz_texts).to have_size 2
    (expect baz_texts[0][:x]).to eql baz_texts[1][:x]
  end
end
