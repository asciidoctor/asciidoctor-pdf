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
    (expect listing_texts[0][:page_number]).to eql 1
    (expect listing_texts[-1][:page_number]).to eql 2
  end

  it 'should use dashed border to indicate where block is split across a page boundary', integration: true do
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
    (expect pdf.text[0][:font_size]).to eql 8
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

  it 'should replace tabs with spaces if tabsize is specified as block attribute' do
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

  it 'should replace tabs with spaces if tabsize is specified as document attribute' do
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
end
