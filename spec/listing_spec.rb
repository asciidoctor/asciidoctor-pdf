# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Listing' do
  it 'should move block to next page if it will fit to avoid splitting it' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['paragraph'] * 20).join (?\n * 2)}

    ----
    #{(['listing'] * 20).join ?\n}
    ----
    EOS

    listing_page_numbers = (pdf.find_text 'listing').map {|it| it[:page_number] }.uniq
    (expect listing_page_numbers).to eql [2]
  end

  it 'should split block if it cannot fit on a whole page' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['paragraph'] * 20).join (?\n * 2)}

    ----
    #{(['listing'] * 60).join ?\n}
    ----
    EOS

    (expect pdf.pages).to have_size 2
    listing_texts = pdf.find_text 'listing'
    (expect listing_texts[0][:page_number]).to be 1
    (expect listing_texts[-1][:page_number]).to be 2
  end

  it 'should use dashed border to indicate where block is split across a page boundary', visual: true do
    to_file = to_pdf_file <<~EOS, 'listing-page-split.pdf'
    ----
    #{(['listing'] * 60).join ?\n}
    ----

    ----
    #{(['more listing'] * 2).join ?\n}
    ----
    EOS

    (expect to_file).to visually_match 'listing-page-split.pdf'
  end

  it 'should resize font size to prevent wrapping if autofit option is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    [%autofit]
    ----
    theme = ThemeLoader.load_theme theme_name, (theme_dir = (doc.attr 'pdf-themesdir') || (doc.attr 'pdf-stylesdir'))
    ----
    EOS

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size]).to be < build_pdf_theme.code_font_size
  end

  it 'should not resize font size more than minimum font size' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_size_min: 8 }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    EOS

    (expect pdf.text).to have_size 2
    (expect pdf.text[0][:font_size]).to be 8
  end

  it 'should allow autofit to shrink text as much as it needs if the minimum font size is 0' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_size_min: 0 }, analyze: true
    [%autofit]
    ----
    +--------------------------------------+----------------------------------------------------+-----------------------------------------------------+
    | id                                   | name                                               | subnets                                             |
    +--------------------------------------+----------------------------------------------------+-----------------------------------------------------+
    ----
    EOS

    expected_line = '+--------------------------------------+----------------------------------------------------+-----------------------------------------------------+'
    lines = pdf.lines
    (expect lines).to have_size 3
    (expect lines[0]).to eql expected_line
    (expect lines[2]).to eql expected_line
  end

  it 'should guard indentation using no-break space character' do
    pdf = to_pdf <<~EOS, analyze: true
    ----
    flush
      indented
    flush
    ----
    EOS

    (expect pdf.lines).to eql ['flush', %(\u00a0 indented), 'flush']
  end

  it 'should expand tabs if tabsize attribute is not specified' do
    pdf = to_pdf <<~EOS, analyze: true
    ----
    flush
      lead space
    \tlead tab
    \tlead tab\tcolumn tab
      lead space\tcolumn tab
    flush\t\t\tcolumn tab
    ----
    EOS

    expected_lines = [
      'flush',
      %(\u00a0 lead space),
      %(\u00a0   lead tab),
      %(\u00a0   lead tab    column tab),
      %(\u00a0 lead space    column tab),
      'flush           column tab',
    ]

    (expect pdf.lines).to eql expected_lines
  end

  it 'should expand tabs if tabsize is specified as block attribute' do
    pdf = to_pdf <<~EOS, analyze: true
    [tabsize=4]
    ----
    flush
      lead space
    \tlead tab
    \tlead tab\tcolumn tab
      lead space\tcolumn tab
    flush\t\t\tcolumn tab
    ----
    EOS

    expected_lines = [
      'flush',
      %(\u00a0 lead space),
      %(\u00a0   lead tab),
      %(\u00a0   lead tab    column tab),
      %(\u00a0 lead space    column tab),
      'flush           column tab',
    ]

    (expect pdf.lines).to eql expected_lines
  end

  it 'should expand tabs if tabsize is specified as document attribute' do
    pdf = to_pdf <<~EOS, analyze: true
    :tabsize: 4

    ----
    flush
      lead space
    \tlead tab
    \tlead tab\tcolumn tab
      lead space\tcolumn tab
    flush\t\t\tcolumn tab
    ----
    EOS

    expected_lines = [
      'flush',
      %(\u00a0 lead space),
      %(\u00a0   lead tab),
      %(\u00a0   lead tab    column tab),
      %(\u00a0 lead space    column tab),
      'flush           column tab',
    ]

    (expect pdf.lines).to eql expected_lines
  end

  it 'should allow theme to override caption for code blocks' do
    pdf_theme = {
      caption_font_color: '0000ff',
      code_caption_font_style: 'bold',
    }

    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    .Title
    ----
    content
    ----
    EOS

    title_text = (pdf.find_text 'Title')[0]
    (expect title_text[:font_color]).to eql '0000FF'
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
  end

  it 'should apply inline formatting if quotes subs is enabled' do
    pdf = to_pdf <<~'EOS', analyze: true
    [subs=+quotes]
    ----
    _1_ skipped
    *99* passing
    ----
    EOS

    italic_text = (pdf.find_text '1')[0]
    (expect italic_text[:font_name]).to eql 'mplus1mn-italic'
    bold_text = (pdf.find_text '99')[0]
    (expect bold_text[:font_name]).to eql 'mplus1mn-bold'
  end

  it 'should honor font family set on conum category in theme for conum in listing block' do
    pdf = to_pdf <<~EOS, pdf_theme: { code_font_family: 'Courier' }, analyze: true
    ----
    fe <1>
    fi <2>
    fo <3>
    ----
    EOS

    lines = pdf.lines
    (expect lines[0]).to end_with ' ①'
    (expect lines[1]).to end_with ' ②'
    (expect lines[2]).to end_with ' ③'
    conum_text = (pdf.find_text '①')[0]
    (expect conum_text[:font_name]).not_to eql 'Courier'
  end
end
