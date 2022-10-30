# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Footnote' do
  it 'should place footnotes at the end of each chapter when doctype is book' do
    pdf = to_pdf <<~'END', doctype: :book, attribute_overrides: { 'notitle' => '' }, analyze: true
    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.
    END
    strings, text = pdf.strings, pdf.text
    (expect strings[2]).to eql '[1]'
    # superscript
    (expect text[2][:y]).to be > text[1][:y]
    (expect text[2][:y]).to be > text[3][:y]
    (expect text[2][:font_size]).to be < text[1][:font_size]
    (expect text[2][:font_color]).to eql '428BCA'
    # footnote item
    (expect (strings.slice 4, 2).join).to eql '1. More about that thing.'
    (expect text[4][:y]).to be < text[3][:y]
    (expect text[4][:y]).to be < 60
    (expect text[4][:font_name]).to eql 'NotoSerif-Bold'
    (expect text[4][:page_number]).to be 1
    (expect text[4][:font_size]).to be 8
    (expect (text.slice 4, 2).uniq {|it| [it[:y], it[:font_size]] }).to have_size 1
    # next chapter
    (expect text[6][:page_number]).to be 2
  end

  it 'should reset footnote number per chapter' do
    pdf = to_pdf <<~'END', doctype: :book, attribute_overrides: { 'notitle' => '' }, analyze: true
    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.footnote:[What does it all mean?]
    END

    chapter_a_lines = pdf.lines pdf.find_text page_number: 1
    (expect chapter_a_lines).to include 'About this thing.[1] And so on.'
    (expect chapter_a_lines).to include '1. More about that thing.'

    chapter_b_lines = pdf.lines pdf.find_text page_number: 2
    (expect chapter_b_lines).to include 'Yada yada yada.[1]'
    (expect chapter_b_lines).to include '1. What does it all mean?'
  end

  it 'should add xreftext of chapter to footnote reference to footnote in previous chapter' do
    pdf = to_pdf <<~'END', doctype: :book, pdf_theme: { footnotes_font_color: 'AA0000' }, analyze: true
    = Document Title
    :notitle:
    :xrefstyle: short
    :sectnums:

    == A

    About this thing.footnote:fn1[More about that thing.] And so on.

    == B

    Yada yada yada.footnote:fn1[]
    END

    footnote_texts = pdf.find_text font_color: 'AA0000'
    (expect footnote_texts.map {|it| it[:page_number] }.uniq).to eql [1]

    chapter_a_lines = pdf.lines pdf.find_text page_number: 1
    (expect chapter_a_lines).to include 'About this thing.[1] And so on.'
    (expect chapter_a_lines).to include '1. More about that thing.'

    chapter_b_lines = pdf.lines pdf.find_text page_number: 2
    (expect chapter_b_lines).to include 'Yada yada yada.[1 - Chapter 1]'
    (expect chapter_b_lines).not_to include '1. More about that thing.'
  end

  it 'should not warn when adding label accessor to footnote' do
    old_verbose, $VERBOSE = $VERBOSE, 1
    warnings = []
    Warning.singleton_class.define_method :warn do |str|
      warnings << str
    end

    input = <<~'END'
    = Document Title
    :doctype: book
    :notitle:
    :nofooter:

    == Chapter A

    About this thing.footnote:fn1[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.footnote:fn1[]
    END

    doc = Asciidoctor.convert input, backend: 'pdf', safe: :safe, to_file: (pdf_io = StringIO.new), standalone: true
    pdf_io.truncate 0
    doc.converter.write doc.convert, pdf_io
    pdf = TextInspector.analyze pdf_io
    lines = pdf.lines pdf.find_text page_number: 2
    (expect lines.join ?\n).to include '[1 - Chapter A]'
    (expect warnings).to be_empty
  ensure
    $VERBOSE = old_verbose
    Warning.singleton_class.send :remove_method, :warn
  end

  it 'should place footnotes at the end of document when doctype is not book' do
    pdf = to_pdf <<~'END', attributes_overrides: { 'notitle' => '' }, analyze: true
    == Section A

    About this thing.footnote:[More about that thing.] And so on.

    <<<

    == Section B

    Yada yada yada.
    END

    strings, text = pdf.strings, pdf.text
    (expect strings[2]).to eql '[1]'
    # superscript
    (expect text[6][:y]).to be < text[5][:y]
    (expect text[2][:font_size]).to be < text[1][:font_size]
    (expect text[2][:font_size]).to be < text[3][:font_size]
    (expect text[2][:font_color]).to eql '428BCA'
    # footnote item
    (expect (pdf.find_text 'Section B')[0][:order]).to be < (pdf.find_unique_text %r/More about that thing/)[:order]
    (expect strings.slice(-2, 2).join).to eql '1. More about that thing.'
    (expect text[-1][:page_number]).to be 2
    (expect text[-1][:font_size]).to be 8
    (expect text[-1][:y]).to be < 60
  end

  it 'should place footnotes at bottom of page if start on following page' do
    pdf = with_content_spacer 10, 700 do |spacer_path|
      to_pdf <<~END, pdf_theme: { page_margin: 50 }, analyze: true
      image::#{spacer_path}[]

      About this thing.footnote:[More about this thing.]
      About that thing.footnote:[More about that thing.]
      And so on.
      END
    end

    (expect pdf.pages).to have_size 2
    last_text = pdf.find_unique_text %r/And so on/
    (expect last_text[:page_number]).to be 1
    first_footnote = pdf.find_unique_text %r/More about this thing/
    (expect first_footnote[:page_number]).to be 2
    last_page_texts = pdf.find_text page_number: 2
    footnotes_height = (last_page_texts[0][:y] + last_page_texts[0][:font_size]) - last_page_texts[-1][:y]
    (expect first_footnote[:y]).to be < (footnotes_height + 50)
  end

  it 'should put footnotes directly below last block if footnotes_margin_top is 0' do
    pdf_theme = { footnotes_margin_top: 0 }
    input = <<~'END'
    About this thing.footnote:[More about this thing.]

    ****
    sidebar
    ****
    END

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
      .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
    (expect pdf.pages).to have_size 1
    footnote_text = pdf.find_unique_text %r/More about /
    footnote_text_top = footnote_text[:y] + footnote_text[:font_size]
    content_bottom_y = horizontal_lines[-1][:from][:y]
    (expect content_bottom_y - footnote_text_top).to be > 12.0
    (expect content_bottom_y - footnote_text_top).to be < 14.0
  end

  it 'should push footnotes to bottom of page if footnotes_margin_top is auto' do
    pdf_theme = { page_margin: 36, footnotes_margin_top: 'auto', footnotes_item_spacing: 0 }
    input = <<~'END'
    About this thing.footnote:[More about this thing.]

    more content
    END

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    footnote_text = pdf.find_unique_text %r/More about /
    (expect footnote_text[:y]).to (be_within 3).of 36
  end

  it 'should put footnotes beyond margin below last block of content' do
    pdf_theme = { sidebar_background_color: 'transparent' }
    input = <<~'END'
    About this thing.footnote:[More about this thing.]

    image::tall.svg[pdfwidth=76.98mm]

    ****
    sidebar
    ****
    END

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
      .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
    (expect pdf.pages).to have_size 1
    footnote_text = pdf.find_unique_text %r/More about /
    footnote_text_top = footnote_text[:y] + footnote_text[:font_size]
    content_bottom_y = horizontal_lines[-1][:from][:y]
    (expect content_bottom_y - footnote_text_top).to be > 12.0
    (expect content_bottom_y - footnote_text_top).to be < 14.0
  end

  it 'should not allow footnotes to collapse margin below last block of content' do
    pdf = to_pdf <<~'END', analyze: true
    About this thing.footnote:[More about this thing.]

    image::tall.svg[pdfwidth=80mm]

    Some other content.
    END

    (expect pdf.pages).to have_size 2
    main_text = pdf.find_unique_text %r/^About /
    footnote_text = pdf.find_unique_text %r/More about /
    (expect main_text[:page_number]).to eql 1
    (expect footnote_text[:page_number]).to eql 2
  end

  it 'should not move footnotes down if height exceeds height of page' do
    footnotes = ['footnote:[Lots more about this thing.]'] * 50
    pdf = to_pdf <<~END, analyze: true
    About this thing.#{footnotes}
    END

    (expect pdf.pages).to have_size 2
    main_text = (pdf.find_text %r/About this thing\./)[0]
    first_footnote_text = (pdf.find_text %r/Lots more/)[0]
    delta = main_text[:y] - first_footnote_text[:y]
    (expect delta).to be < 60
  end

  it 'should allow footnote to be externalized so it can be used multiple times' do
    pdf = to_pdf <<~'END', analyze: true
    :fn-disclaimer: footnote:disclaimer[Opinions are my own.]

    A bold statement.{fn-disclaimer}

    Another audacious statement.{fn-disclaimer}
    END

    if (Gem::Version.new Asciidoctor::VERSION) < (Gem::Version.new '2.0.11')
      expected_lines = <<~'END'.lines.map(&:chomp)
      A bold statement.[1]
      Another audacious statement.[2]
      1. Opinions are my own.
      2. Opinions are my own.
      END
      footnote_text = (pdf.find_text %r/Opinions/)[-1]
    else
      expected_lines = <<~'END'.lines.map(&:chomp)
      A bold statement.[1]
      Another audacious statement.[1]
      1. Opinions are my own.
      END
      footnote_text = pdf.find_unique_text %r/Opinions/
    end

    (expect pdf.lines).to eql expected_lines
    (expect footnote_text[:y]).to be < 60
  end

  it 'should keep footnote label with previous adjacent text' do
    pdf = to_pdf <<~'END', analyze: true
    The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. Go.footnote:a[This is note A.]
    END

    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[1]).to eql 'Go.[1]'
    (expect lines[2]).to eql '1. This is note A.'
  end

  it 'should not keep footnote label with previous text if separated by a space' do
    pdf = to_pdf <<~'END', analyze: true
    The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. Go. footnote:a[This is note A.]
    END

    text = pdf.text
    (expect text[1][:string]).to start_with '['
    (expect text[0][:y] - text[1][:y]).to be > 10
    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[0]).to end_with 'Go.'
    (expect lines[1]).to eql '[1]'
    (expect lines[2]).to eql '1. This is note A.'
  end

  it 'should keep footnote label with previous text when line wraps to next page' do
    pdf = to_pdf <<~'END', analyze: true
    image::tall.svg[pdfwidth=85mm]

    The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. Go.footnote:a[This is note A.]
    END

    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[1]).to eql 'Go.[1]'
    (expect lines[2]).to eql '1. This is note A.'
    (expect (pdf.find_unique_text 'Go.')[:page_number]).to eql 2
    (expect (pdf.find_unique_text %r/This is note A/)[:page_number]).to eql 2
  end

  it 'should keep formatted footnote label with previous text' do
    expected_y = ((to_pdf <<~'END', analyze: true).find_unique_text '[1]')[:y]
    The +
    Go.^[1]^
    END

    pdf = to_pdf <<~'END', pdf_theme: { mark_border_offset: 0 }, analyze: true
    The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. Go.#footnote:a[This is note A.]#
    END

    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[1]).to eql 'Go.[1]'
    (expect lines[2]).to eql '1. This is note A.'
    (expect (pdf.find_text %r/\[/)[0][:y]).to eql expected_y
  end

  it 'should support text formatting in a footnote' do
    pdf = to_pdf <<~'END', analyze: true
    You can download patches from the product page.footnote:[Only available if you have an _active_ subscription.]
    END

    (expect pdf.lines[-1]).to eql '1. Only available if you have an active subscription.'
    active_text = pdf.find_unique_text 'active'
    (expect active_text[:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should support text formatting in an externalized footnote' do
    pdf = to_pdf <<~'END', analyze: true
    :fn-disclaimer: pass:q[footnote:disclaimer[Only available if you have an _active_ subscription.]]

    You will receive notifications of all product updates.{fn-disclaimer}

    You can download patches from the product page.{fn-disclaimer}
    END

    if (Gem::Version.new Asciidoctor::VERSION) < (Gem::Version.new '2.0.11')
      expected_lines = <<~'END'.lines.map(&:chomp)
      You will receive notifications of all product updates.[1]
      You can download patches from the product page.[2]
      1. Only available if you have an active subscription.
      2. Only available if you have an active subscription.
      END
      active_text = (pdf.find_text 'active')[-1]
    else
      expected_lines = <<~'END'.lines.map(&:chomp)
      You will receive notifications of all product updates.[1]
      You can download patches from the product page.[1]
      1. Only available if you have an active subscription.
      END
      active_text = pdf.find_unique_text 'active'
    end

    (expect pdf.lines).to eql expected_lines
    (expect active_text[:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should show unresolved footnote reference in red text' do
    (expect do
      pdf = to_pdf <<~'END', analyze: true
      text.footnote:foo[]
      END

      foo_text = pdf.find_unique_text '[foo]'
      (expect foo_text).not_to be_nil
      (expect foo_text[:font_color]).to eql 'FF0000'
      (expect foo_text[:font_size]).to be < pdf.text[0][:font_size]
      (expect foo_text[:y]).to be > pdf.text[0][:y]
    end).to log_message severity: :WARN, message: 'invalid footnote reference: foo'
  end

  it 'should allow theme to configure color of unresolved footnote reference using unresolved role' do
    (expect do
      pdf = to_pdf <<~'END', pdf_theme: { role_unresolved_font_color: 'AA0000' }, analyze: true
      text.footnote:foo[]
      END

      foo_text = pdf.find_unique_text '[foo]'
      (expect foo_text).not_to be_nil
      (expect foo_text[:font_color]).to eql 'AA0000'
      (expect foo_text[:font_size]).to be < pdf.text[0][:font_size]
      (expect foo_text[:y]).to be > pdf.text[0][:y]
    end).to log_message severity: :WARN, message: 'invalid footnote reference: foo'
  end

  it 'should show warning if footnote type is unknown' do
    fn_inline_macro_impl = proc do
      named 'fn'
      process do |parent, target|
        create_inline parent, :footnote, target, type: :unknown
      end
    end
    opts = { extension_registry: Asciidoctor::Extensions.create { inline_macro(&fn_inline_macro_impl) } }
    (expect do
      pdf = to_pdf <<~'END', (opts.merge analyze: true)
      before fn:foo[] after
      END
      (expect pdf.lines).to eql ['before after']
    end).to log_message severity: :WARN, message: 'unknown footnote type: :unknown'
  end

  it 'should not crash if footnote is defined in section title with autogenerated ID' do
    pdf = to_pdf <<~'END', analyze: true
    == Section Titlefootnote:[Footnote about this section title.]
    END

    (expect pdf.lines[-1]).to eql '1. Footnote about this section title.'
  end

  it 'should be able to use footnotes_line_spacing key in theme to control spacing between footnotes' do
    pdf_theme = {
      base_line_height: 1,
      base_font_size: 10,
      footnotes_font_size: 10,
      footnotes_item_spacing: 3,
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    line a{empty}footnote:[Footnote on line a] +
    line b{empty}footnote:[Footnote on line b]
    END

    line_a_text = (pdf.find_text 'line a')[0]
    line_b_text = (pdf.find_text 'line b')[0]
    fn_a_text = (pdf.find_text %r/Footnote on line a$/)[0]
    fn_b_text = (pdf.find_text %r/Footnote on line b$/)[0]

    (expect ((line_a_text[:y] - line_b_text[:y]).round 2) + 3).to eql ((fn_a_text[:y] - fn_b_text[:y]).round 2)
  end

  it 'should not add spacing between footnote items if footnotes_item_spacing key is nil in theme' do
    pdf_theme = {
      base_line_height: 1,
      base_font_size: 10,
      footnotes_font_size: 10,
      footnotes_item_spacing: nil,
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    line a{empty}footnote:[Footnote on line a] +
    line b{empty}footnote:[Footnote on line b]
    END

    line_a_text = (pdf.find_text 'line a')[0]
    line_b_text = (pdf.find_text 'line b')[0]
    fn_a_text = (pdf.find_text %r/Footnote on line a$/)[0]
    fn_b_text = (pdf.find_text %r/Footnote on line b$/)[0]

    (expect (line_a_text[:y] - line_b_text[:y]).round 2).to eql ((fn_a_text[:y] - fn_b_text[:y]).round 2)
  end

  it 'should add title to footnotes block if footnotes-title is set' do
    pdf = to_pdf <<~'END', analyze: true
    :footnotes-title: Footnotes

    main content.footnote:[This is a footnote, just so you know.]
    END

    footnotes_title_text = (pdf.find_text 'Footnotes')[0]
    (expect footnotes_title_text).not_to be_nil
    (expect footnotes_title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect footnotes_title_text[:y]).to be < (pdf.find_text 'main content.')[0][:y]
  end

  it 'should allow theme to control style of footnotes title' do
    pdf_theme = {
      footnotes_caption_font_style: 'bold',
      footnotes_caption_font_size: '24',
      footnotes_caption_font_color: '222222',
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    :footnotes-title: Footnotes

    main content.footnote:[This is a footnote, just so you know.]
    END

    footnotes_title_text = (pdf.find_text 'Footnotes')[0]
    (expect footnotes_title_text).not_to be_nil
    (expect footnotes_title_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect footnotes_title_text[:font_size]).to eql 24
    (expect footnotes_title_text[:font_color]).to eql '222222'
  end

  it 'should create bidirectional links between footnote ref and def' do
    pdf = to_pdf <<~'END', doctype: :book, attribute_overrides: { 'notitle' => '' }
    = Document Title

    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.
    END
    annotations = (get_annotations pdf, 1).sort_by {|it| it[:Rect][1] }.reverse
    (expect annotations).to have_size 2
    footnote_label_y = annotations[0][:Rect][3]
    footnote_item_y = annotations[1][:Rect][3]
    (expect (footnoteref_dest = get_dest pdf, '_footnoteref_1')).not_to be_nil
    (expect footnote_label_y - footnoteref_dest[:y]).to be < 1
    (expect (footnotedef_dest = get_dest pdf, '_footnotedef_1')).not_to be_nil
    (expect footnotedef_dest[:y]).to eql footnote_item_y
  end

  it 'should render footnotes in table cell that are directly adjacent to text' do
    pdf = to_pdf <<~'END', analyze: true
    |===
    |``German``footnote:[Other non-English languages may be supported in the future depending on demand.]
    | 80footnote:[Width and Length is overridden by the actual terminal or window size, if available.]
    |===
    END

    (expect pdf.lines.slice 0, 2).to eql ['German[1]', '80[2]']
  end

  it 'should use number of target footnote in footnote reference' do
    pdf = to_pdf <<~'END', analyze: true
    You can download patches from the product page.footnote:sub[Only available if you have an active subscription.]

    If you have problems running the software, you can submit a support request.footnote:sub[]
    END

    text = pdf.text
    p1 = pdf.find_unique_text %r/download/
    fn1 = text[p1[:order]][:string]
    (expect fn1).to eql '[1]'
    p2 = pdf.find_unique_text %r/support request/
    fn2 = text[p2[:order]][:string]
    (expect fn2).to eql '[1]'
    f1 = (pdf.find_text font_size: 8).reduce('') {|accum, it| accum + it[:string] }
    (expect f1).to eql '1. Only available if you have an active subscription.'
  end

  it 'should not duplicate footnotes that are included in unbreakable blocks' do
    pdf = to_pdf <<~'END', analyze: true
    Here we go.

    [%unbreakable]
    ****
    [%unbreakable]
    ____
    Make it rain.footnote:[money]
    ____
    ****

    Make it snow.footnote:[dollar bills]
    END

    combined_text = pdf.strings.join
    (expect combined_text).to include 'Make it rain.[1]'
    (expect combined_text).to include '1. money'
    (expect combined_text).to include 'Make it snow.[2]'
    (expect combined_text).to include '2. dollar bills'
    (expect combined_text.scan '1').to have_size 2
    (expect combined_text.scan '2').to have_size 2
    (expect combined_text.scan '3').to be_empty
  end

  it 'should not duplicate footnotes included in the desc of a horizontal dlist' do
    pdf = to_pdf <<~'END', analyze: true
    [horizontal]
    ctrl-r::
    Make it rain.footnote:[money]

    ctrl-d::
    Make it snow.footnote:[dollar bills]
    END

    lines = pdf.lines pdf.text
    (expect lines).to eql ['ctrl-r Make it rain.[1]', 'ctrl-d Make it snow.[2]', '1. money', '2. dollar bills']
  end

  it 'should allow a bibliography ref to be used inside the text of a footnote' do
    pdf = to_pdf <<~'END', analyze: true
    There are lots of things to know.footnote:[Be sure to read <<wells>> to learn about it.]

    [bibliography]
    == Bibliography

    * [[[wells]]] Ashley Wells. 'Stuff About Stuff'. Publishistas. 2010.
    END

    lines = pdf.lines
    (expect lines[0]).to eql 'There are lots of things to know.[1]'
    (expect lines[-1]).to eql '1. Be sure to read [wells] to learn about it.'
  end

  it 'should allow a link to be used in footnote when media is print' do
    pdf = to_pdf <<~'END', attribute_overrides: { 'media' => 'print' }, analyze: true
    When in doubt, search.footnote:[Use a search engine like https://google.com[Google]]
    END

    lines = pdf.lines
    (expect lines[0]).to eql 'When in doubt, search.[1]'
    (expect lines[-1]).to eql '1. Use a search engine like Google [https://google.com]'
  end

  it 'should not allocate space for anchor if font is missing glyph for null character' do
    pdf_theme = {
      extends: 'default',
      font_catalog: {
        'Missing Null' => {
          'normal' => (fixture_file 'mplus1mn-regular-ascii.ttf'),
          'bold' => (fixture_file 'mplus1mn-regular-ascii.ttf'),
        },
      },
      base_font_family: 'Missing Null',
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    foo{empty}footnote:[Note about foo.]
    END

    foo_text = pdf.find_unique_text 'foo'
    foo_text_end = foo_text[:x] + foo_text[:width]
    footnote_ref_start = (pdf.find_unique_text '[1]')[:x]
    (expect footnote_ref_start).to eql foo_text_end
  end

  it 'should show missing footnote reference as ID in red text' do
    (expect do
      pdf = to_pdf <<~'END', analyze: true
      bla bla bla.footnote:no-such-id[]
      END
      (expect pdf.lines).to eql ['bla bla bla.[no-such-id]']
      annotation_text = pdf.find_unique_text font_color: 'FF0000'
      (expect annotation_text).not_to be_nil
      (expect annotation_text[:string]).to eql '[no-such-id]'
      (expect annotation_text[:font_size]).to be < (pdf.find_unique_text 'bla bla bla.')[:font_size]
    end).to log_message severity: :WARN, message: 'invalid footnote reference: no-such-id'
  end
end
