require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Footnote' do
  it 'should place footnotes at the end of each chapter when doctype is book' do
    pdf = to_pdf <<~'EOS', doctype: :book, attributes: { 'notitle' => '', 'nofooter' => '' }, analyze: true
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
    (expect text[6][:page_number]).to eql 1
    (expect text[6][:font_size]).to eql 8
    (expect (text.slice 6, 3).map {|it| [it[:y], it[:font_size]] }.uniq).to have_size 1
    # next chapter
    (expect text[9][:page_number]).to eql 2
  end

  it 'should place footnotes at the end of document when doctype is not book' do
    pdf = to_pdf <<~'EOS', attributes: { 'notitle' => '', 'nofooter' => '' }, analyze: true
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
    (expect (strings.slice(-3, 3)).join).to eql '[1] More about that thing.'
    (expect text[-1][:page_number]).to eql 2
    (expect text[-1][:font_size]).to eql 8
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
    if asciidoctor_1_5_7_or_better?
      pdf = to_pdf <<~'EOS', analyze: true
      You can download patches from the product page.footnote:sub[Only available if you have an active subscription.]

      If you have problems running the software, you can submit a support request.footnote:sub[]
      EOS
    else
      pdf = to_pdf <<~'EOS', analyze: true
      You can download patches from the product page.footnoteref:[sub,Only available if you have an active subscription.]

      If you have problems running the software, you can submit a support request.footnoteref:[sub]
      EOS
    end

    text = pdf.text
    p1 = (pdf.find_text %r/download/)[0]
    fn1 = (text.slice p1[:order], 3).reduce('') {|accum, it| accum += it[:string] }
    (expect fn1).to eql '[1]'
    p2 = (pdf.find_text %r/support request/)[0]
    fn2 = (text.slice p2[:order], 3).reduce('') {|accum, it| accum += it[:string] }
    (expect fn2).to eql '[1]'
    f1 = (pdf.find_text font_size: 8).reduce('') {|accum, it| accum += it[:string] }
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
    pdf = to_pdf <<~'EOS', attributes: { 'media' => 'print', 'nofooter' => '' }, analyze: true
    When in doubt, search.footnote:[Use a search engine like https://google.com[Google]]
    EOS

    lines = pdf.lines
    (expect lines[0]).to eql 'When in doubt, search.[1]'
    (expect lines[-1]).to eql '[1] Use a search engine like Google [https://google.com]'
  end
end
