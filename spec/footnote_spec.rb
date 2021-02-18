# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Footnote' do
  it 'should place footnotes at the end of each chapter when doctype is book' do
    pdf = to_pdf <<~'EOS', doctype: :book, attribute_overrides: { 'notitle' => '' }, analyze: true
    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.
    EOS
    strings, text = pdf.strings, pdf.text
    (expect (strings.slice 2, 3).join).to eql '[1]'
    # superscript
    (expect text[2][:y]).to be > text[1][:y]
    (expect text[2][:font_size]).to be < text[1][:font_size]
    (expect text[3][:font_color]).to eql '428BCA'
    # superscript group
    (expect (text.slice 2, 3).map {|it| [it[:y], it[:font_size]] }.uniq).to have_size 1
    # footnote item
    (expect (strings.slice 6, 3).join).to eql '[1] More about that thing.'
    (expect text[6][:y]).to be < text[5][:y]
    (expect text[6][:y]).to be < 60
    (expect text[6][:page_number]).to be 1
    (expect text[6][:font_size]).to be 8
    (expect (text.slice 6, 3).map {|it| [it[:y], it[:font_size]] }.uniq).to have_size 1
    # next chapter
    (expect text[9][:page_number]).to be 2
  end

  it 'should reset footnote number per chapter' do
    pdf = to_pdf <<~'EOS', doctype: :book, attribute_overrides: { 'notitle' => '' }, analyze: true
    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.footnote:[What does it all mean?]
    EOS

    chapter_a_lines = pdf.lines pdf.find_text page_number: 1
    (expect chapter_a_lines).to include 'About this thing.[1] And so on.'
    (expect chapter_a_lines).to include '[1] More about that thing.'

    chapter_b_lines = pdf.lines pdf.find_text page_number: 2
    (expect chapter_b_lines).to include 'Yada yada yada.[1]'
    (expect chapter_b_lines).to include '[1] What does it all mean?'
  end

  it 'should add xreftext of chapter to footnote reference to footnote in previous chapter' do
    pdf = to_pdf <<~'EOS', doctype: :book, pdf_theme: { footnotes_font_color: 'AA0000' }, analyze: true
    = Document Title
    :notitle:
    :xrefstyle: short
    :sectnums:

    == A

    About this thing.footnote:fn1[More about that thing.] And so on.

    == B

    Yada yada yada.footnote:fn1[]
    EOS

    footnote_texts = pdf.find_text font_color: 'AA0000'
    (expect footnote_texts.map {|it| it[:page_number] }.uniq).to eql [1]

    chapter_a_lines = pdf.lines pdf.find_text page_number: 1
    (expect chapter_a_lines).to include 'About this thing.[1] And so on.'
    (expect chapter_a_lines).to include '[1] More about that thing.'

    chapter_b_lines = pdf.lines pdf.find_text page_number: 2
    (expect chapter_b_lines).to include 'Yada yada yada.[1 - Chapter 1]'
    (expect chapter_b_lines).not_to include '[1] More about that thing.'
  end

  it 'should not warn when adding label accessor to footnote' do
    old_verbose, $VERBOSE = $VERBOSE, 1
    warnings = []
    Warning.singleton_class.define_method :warn do |str|
      warnings << str
    end

    input = <<~'EOS'
    = Document Title
    :doctype: book
    :notitle:
    :nofooter:

    == Chapter A

    About this thing.footnote:fn1[More about that thing.] And so on.

    == Chapter B

    Yada yada yada.footnote:fn1[]
    EOS

    doc = Asciidoctor.convert input, backend: 'pdf', safe: :safe, to_file: (pdf_io = StringIO.new), standalone: true
    pdf_io.truncate 0
    doc.converter.write doc.convert, pdf_io
    pdf = EnhancedPDFTextInspector.analyze pdf_io
    lines = pdf.lines pdf.find_text page_number: 2
    (expect lines.join ?\n).to include '[1 - Chapter A]'
    (expect warnings).to be_empty
  ensure
    $VERBOSE = old_verbose
    Warning.singleton_class.send :remove_method, :warn
  end

  it 'should place footnotes at the end of document when doctype is not book' do
    pdf = to_pdf <<~'EOS', attributes_overrides: { 'notitle' => '' }, analyze: true
    == Section A

    About this thing.footnote:[More about that thing.] And so on.

    <<<

    == Section B

    Yada yada yada.
    EOS

    strings, text = pdf.strings, pdf.text
    (expect (strings.slice 2, 3).join).to eql '[1]'
    # superscript
    (expect text[2][:y]).to be > text[1][:y]
    (expect text[2][:font_size]).to be < text[1][:font_size]
    (expect text[3][:font_color]).to eql '428BCA'
    # superscript group
    (expect (text.slice 2, 3).map {|it| [it[:y], it[:font_size]] }.uniq).to have_size 1
    (expect text[2][:font_size]).to be < text[1][:font_size]
    # footnote item
    (expect (pdf.find_text 'Section B')[0][:order]).to be < (pdf.find_text '] More about that thing.')[0][:order]
    (expect strings.slice(-3, 3).join).to eql '[1] More about that thing.'
    (expect text[-1][:page_number]).to be 2
    (expect text[-1][:font_size]).to be 8
    (expect text[-1][:y]).to be < 60
  end

  it 'should allow footnote to be externalized so it can be used multiple times' do
    pdf = to_pdf <<~'EOS', analyze: true
    :fn-disclaimer: footnote:disclaimer[Opinions are my own.]

    A bold statement.{fn-disclaimer}

    Another audacious statement.{fn-disclaimer}
    EOS

    expected_lines = <<~'EOS'.lines.map(&:chomp)
    A bold statement.[1]
    Another audacious statement.[1]
    [1] Opinions are my own.
    EOS

    (expect pdf.lines).to eql expected_lines
    footnote_text = pdf.find_unique_text %r/Opinions/
    (expect footnote_text[:y]).to be < 60
  end

  it 'should show unresolved footnote reference in red text' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      text.footnote:foo[]
      EOS

      foo_text = pdf.find_unique_text '[foo]'
      (expect foo_text).not_to be_nil
      (expect foo_text[:font_color]).to eql 'FF0000'
      (expect foo_text[:font_size]).to be < pdf.text[0][:font_size]
      (expect foo_text[:y]).to be > pdf.text[0][:y]
    end).to log_message severity: :WARN, message: 'invalid footnote reference: foo'
  end

  it 'should allow theme to configure color of unresolved footnote reference using unresolved role' do
    (expect do
      pdf = to_pdf <<~'EOS', pdf_theme: { role_unresolved_font_color: 'AA0000' }, analyze: true
      text.footnote:foo[]
      EOS

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
      pdf = to_pdf <<~'EOS', (opts.merge analyze: true)
      before fn:foo[] after
      EOS
      (expect pdf.lines).to eql ['before after']
    end).to log_message severity: :WARN, message: 'unknown footnote type: :unknown'
  end

  it 'should not crash if footnote is defined in section title with autogenerated ID' do
    pdf = to_pdf <<~'EOS', analyze: true
    == Section Titlefootnote:[Footnote about this section title.]
    EOS

    (expect pdf.lines[-1]).to eql '[1] Footnote about this section title.'
  end

  it 'should be able to use footnotes_line_spacing key in theme to control spacing between footnotes' do
    pdf_theme = {
      base_line_height: 1,
      base_font_size: 10,
      footnotes_font_size: 10,
      footnotes_item_spacing: 3,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    line a{empty}footnote:[Footnote on line a] +
    line b{empty}footnote:[Footnote on line b]
    EOS

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
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    line a{empty}footnote:[Footnote on line a] +
    line b{empty}footnote:[Footnote on line b]
    EOS

    line_a_text = (pdf.find_text 'line a')[0]
    line_b_text = (pdf.find_text 'line b')[0]
    fn_a_text = (pdf.find_text %r/Footnote on line a$/)[0]
    fn_b_text = (pdf.find_text %r/Footnote on line b$/)[0]

    (expect (line_a_text[:y] - line_b_text[:y]).round 2).to eql ((fn_a_text[:y] - fn_b_text[:y]).round 2)
  end

  it 'should add title to footnotes block if footnotes-title is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :footnotes-title: Footnotes

    main content.footnote:[This is a footnote, just so you know.]
    EOS

    footnotes_title_text = (pdf.find_text 'Footnotes')[0]
    (expect footnotes_title_text).not_to be_nil
    (expect footnotes_title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect footnotes_title_text[:y]).to be < (pdf.find_text 'main content.')[0][:y]
  end

  it 'should create bidirectional links between footnote ref and def' do
    pdf = to_pdf <<~'EOS', doctype: :book, attribute_overrides: { 'notitle' => '' }
    = Document Title

    == Chapter A

    About this thing.footnote:[More about that thing.] And so on.
    EOS
    annotations = (get_annotations pdf, 1).sort_by {|it| it[:Rect][1] }.reverse
    (expect annotations).to have_size 2
    footnote_label_y = annotations[0][:Rect][3]
    footnote_item_y = annotations[1][:Rect][3]
    names = get_names pdf
    (expect footnote_label_y - pdf.objects[names['_footnoteref_1']][3]).to be < 1
    (expect pdf.objects[names['_footnotedef_1']][3]).to eql footnote_item_y
  end

  it 'should render footnotes in table cell that are directly adjacent to text' do
    pdf = to_pdf <<~'EOS', analyze: true
    |===
    |``German``footnote:[Other non-English languages may be supported in the future depending on demand.]
    | 80footnote:[Width and Length is overridden by the actual terminal or window size, if available.]
    |===
    EOS

    (expect pdf.lines.slice 0, 2).to eql ['German[1]', '80[2]']
  end

  it 'should use number of target footnote in footnote reference' do
    pdf = to_pdf <<~'EOS', analyze: true
    You can download patches from the product page.footnote:sub[Only available if you have an active subscription.]

    If you have problems running the software, you can submit a support request.footnote:sub[]
    EOS

    text = pdf.text
    p1 = (pdf.find_text %r/download/)[0]
    fn1 = (text.slice p1[:order], 3).reduce('') {|accum, it| accum + it[:string] }
    (expect fn1).to eql '[1]'
    p2 = (pdf.find_text %r/support request/)[0]
    fn2 = (text.slice p2[:order], 3).reduce('') {|accum, it| accum + it[:string] }
    (expect fn2).to eql '[1]'
    f1 = (pdf.find_text font_size: 8).reduce('') {|accum, it| accum + it[:string] }
    (expect f1).to eql '[1] Only available if you have an active subscription.'
  end

  it 'should not duplicate footnotes that are included in keep together content' do
    pdf = to_pdf <<~'EOS', analyze: true
    ****
    ____
    Make it rain.footnote:[money]
    ____
    ****

    Make it snow.footnote:[dollar bills]
    EOS

    combined_text = pdf.strings.join
    (expect combined_text).to include 'Make it rain.[1]'
    (expect combined_text).to include '[1] money'
    (expect combined_text).to include 'Make it snow.[2]'
    (expect combined_text).to include '[2] dollar bills'
    (expect combined_text.scan '[1]').to have_size 2
    (expect combined_text.scan '[2]').to have_size 2
    (expect combined_text.scan '[3]').to be_empty
  end

  it 'should not duplicate footnotes included in the desc of a horizontal dlist' do
    pdf = to_pdf <<~'EOS', analyze: true
    [horizontal]
    ctrl-r::
    Make it rain.footnote:[money]

    ctrl-d::
    Make it snow.footnote:[dollar bills]
    EOS

    lines = pdf.lines pdf.text
    (expect lines).to eql ['ctrl-r Make it rain.[1]', 'ctrl-d Make it snow.[2]', '[1] money', '[2] dollar bills']
  end

  it 'should allow a bibliography ref to be used inside the text of a footnote' do
    pdf = to_pdf <<~'EOS', analyze: true
    There are lots of things to know.footnote:[Be sure to read <<wells>> to learn about it.]

    [bibliography]
    == Bibliography

    * [[[wells]]] Ashley Wells. 'Stuff About Stuff'. Publishistas. 2010.
    EOS

    lines = pdf.lines
    (expect lines[0]).to eql 'There are lots of things to know.[1]'
    (expect lines[-1]).to eql '[1] Be sure to read [wells] to learn about it.'
  end

  it 'should allow a link to be used in footnote when media is print' do
    pdf = to_pdf <<~'EOS', attribute_overrides: { 'media' => 'print' }, analyze: true
    When in doubt, search.footnote:[Use a search engine like https://google.com[Google]]
    EOS

    lines = pdf.lines
    (expect lines[0]).to eql 'When in doubt, search.[1]'
    (expect lines[-1]).to eql '[1] Use a search engine like Google [https://google.com]'
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
    foo{empty}footnote:[Note about foo.]
    EOS

    foo_text = (pdf.find_text 'foo')[0]
    foo_text_end = foo_text[:x] + foo_text[:width]
    footnote_ref_start = (pdf.find_text '[')[0][:x]
    (expect footnote_ref_start).to eql foo_text_end
  end

  it 'should show missing footnote reference as ID in red text' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      bla bla bla.footnote:no-such-id[]
      EOS
      (expect pdf.lines).to eql ['bla bla bla.[no-such-id]']
      annotation_text = pdf.find_unique_text font_color: 'FF0000'
      (expect annotation_text).not_to be_nil
      (expect annotation_text[:string]).to eql '[no-such-id]'
      (expect annotation_text[:font_size]).to be < (pdf.find_unique_text 'bla bla bla.')[:font_size]
    end).to log_message severity: :WARN, message: 'invalid footnote reference: no-such-id'
  end
end
