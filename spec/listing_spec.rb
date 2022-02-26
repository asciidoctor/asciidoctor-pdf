# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Listing' do
  it 'should render empty block if listing block is empty' do
    pdf_theme = {
      code_line_height: 1,
      code_padding: 0,
      code_border_width: 1,
      code_border_radius: 0,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
    ----
    ----
    EOS

    lines = pdf.lines
    (expect lines).to have_size 4
    (expect lines[1][:from][:y] - lines[1][:to][:y]).to be <= 1
  end

  it 'should move unbreakable block shorter than page to next page to avoid splitting it' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['paragraph'] * 20).join (?\n * 2)}

    [%unbreakable]
    ----
    #{(['listing'] * 20).join ?\n}
    ----
    EOS

    listing_page_numbers = (pdf.find_text 'listing').map {|it| it[:page_number] }.uniq
    (expect listing_page_numbers).to eql [2]
  end

  it 'should keep anchor together with block when block is moved to next page' do
    pdf = to_pdf <<~EOS
    #{(['paragraph'] * 20).join (?\n * 2)}

    [#listing-1%unbreakable]
    ----
    #{(['listing'] * 20).join ?\n}
    ----
    EOS

    (expect (pdf.page 1).text).not_to include 'listing'
    (expect (pdf.page 2).text).to include 'listing'
    (expect (dest = get_dest pdf, 'listing-1')).not_to be_nil
    (expect dest[:page_number]).to be 2
    (expect dest[:y]).to eql 805.89
  end

  it 'should place anchor below top margin of block' do
    input = <<~'EOS'
    paragraph

    [#listing-1]
    ----
    listing
    ----
    EOS

    pdf_theme = { block_margin_top: 10 }

    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    pdf = to_pdf input, pdf_theme: pdf_theme
    (expect (dest = get_dest pdf, 'listing-1')).not_to be_nil
    (expect dest[:page_number]).to be 1
    (expect dest[:y]).to eql lines[0][:from][:y]
  end

  it 'should place anchor at top of block if advanced to next page' do
    input = <<~EOS
    paragraph

    [#listing-1%unbreakable]
    ----
    #{(['filler'] * 25).join %(\n\n)}
    ----
    EOS

    pdf_theme = { block_margin_top: 10 }

    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    pdf = to_pdf input, pdf_theme: pdf_theme
    (expect (dest = get_dest pdf, 'listing-1')).not_to be_nil
    (expect dest[:page_number]).to be 2
    (expect dest[:y]).to eql lines[0][:from][:y]
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

  it 'should resize font to prevent wrapping if autofit option is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    [%autofit]
    ----
    @themesdir = ::File.expand_path theme.__dir__ || (doc.attr 'pdf-themesdir') || ::Dir.pwd
    ----
    EOS

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size]).to be < build_pdf_theme.code_font_size
  end

  it 'should not resize font if not necessary' do
    pdf = to_pdf <<~'EOS', analyze: true
    [%autofit]
    ----
    puts 'Hello, World!'
    ----
    EOS

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size]).to eql 11
  end

  it 'should not resize font more than base minimum font size' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_size_min: 8 }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    EOS

    (expect pdf.text).to have_size 2
    (expect pdf.text[0][:font_size]).to be 8
  end

  it 'should not resize font more than code minimum font size' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_size_min: 0, code_font_size_min: 8 }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    EOS

    (expect pdf.text).to have_size 2
    (expect pdf.text[0][:font_size]).to be 8
  end

  it 'should allow autofit to shrink text as much as it needs if the minimum font size is 0 or nil' do
    [0, nil].each do |size|
      pdf = to_pdf <<~'EOS', pdf_theme: { base_font_size_min: size }, analyze: true
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
  end

  it 'should use base font color if font color is not specified' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_color: 'AA0000', code_font_color: nil }, analyze: true
    before

    ----
    in the mix
    ----
    EOS

    before_text = pdf.find_unique_text 'before'
    (expect before_text[:font_color]).to eql 'AA0000'

    code_text = pdf.find_unique_text 'in the mix'
    (expect code_text[:font_color]).to eql 'AA0000'
  end

  it 'should allow theme to set different padding per side when autofit is enabled' do
    pdf_theme = {
      code_border_radius: 0,
      code_padding: [5, 10, 15, 20],
      code_background_color: nil,
    }

    input = <<~EOS
    [%autofit]
    ----
    downloading#{(%w(.) * 100).join}
    done
    ----
    EOS

    text = (to_pdf input, pdf_theme: pdf_theme, analyze: true).text
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines

    (expect text).to have_size 2

    left = lines[0][:from][:x]
    top = lines[0][:to][:y]
    bottom = lines[1][:to][:y]
    (expect text[0][:x]).to eql (left + 20.0).round 2
    (expect text[0][:y] + text[0][:font_size]).to be_within(2).of(top - 5)
    (expect text[1][:y]).to be_within(5).of(bottom + 15)
  end

  it 'should guard indentation using no-break space character' do
    pdf = to_pdf <<~'EOS', analyze: true
    ----
    flush
      indented
    flush
    ----
    EOS

    (expect pdf.lines).to eql ['flush', %(\u00a0 indented), 'flush']
  end

  it 'should guard indentation using no-break space character if string starts with indented line' do
    pdf = to_pdf <<~'EOS', analyze: true
    ----
      indented
    flush
      indented
    ----
    EOS

    (expect pdf.lines).to eql [%(\u00a0 indented), 'flush', %(\u00a0 indented)]
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
    lines = pdf.text
    line_gaps = 1.upto(lines.size - 1).map {|idx| (lines[idx - 1][:y] - lines[idx][:y]).round 2 }
    (expect line_gaps[-1]).to eql line_gaps[-2] * 2
    (expect line_gaps[-2]).to eql line_gaps[-3]
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
    lines = pdf.text
    line_gaps = 1.upto(lines.size - 1).map {|idx| (lines[idx - 1][:y] - lines[idx][:y]).round 2 }
    (expect line_gaps[-1]).to eql line_gaps[-2] * 2
    (expect line_gaps[-2]).to eql line_gaps[-3]
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
    lines = pdf.text
    line_gaps = 1.upto(lines.size - 1).map {|idx| (lines[idx - 1][:y] - lines[idx][:y]).round 2 }
    (expect line_gaps[-1]).to eql line_gaps[-2] * 2
    (expect line_gaps[-2]).to eql line_gaps[-3]
  end

  it 'should add numbered label to block title if listing-caption attribute is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :listing-caption: Listing

    .Title
    ----
    content
    ----
    EOS

    title_text = pdf.find_unique_text font_name: 'NotoSerif-Italic'
    (expect title_text[:string]).to eql 'Listing 1. Title'
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
    pdf = to_pdf <<~'EOS', pdf_theme: { code_font_family: 'Courier' }, analyze: true
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

  it 'should allow theme to set conum color using CMYK value' do
    cmyk_color = [0, 100, 100, 60].extend Asciidoctor::PDF::ThemeLoader::CMYKColorValue
    pdf = to_pdf <<~'EOS', pdf_theme: { conum_font_color: cmyk_color }, analyze: true
    ----
    foo <1>
    ----
    <1> the counterpart of bar
    EOS

    conum_texts = pdf.find_text '①'
    (expect conum_texts).to have_size 2
    # NOTE: yes, the hex color is all weird here; could be a parser issue
    (expect conum_texts[0][:font_color]).to eql cmyk_color.map(&:to_f)
    (expect conum_texts[1][:font_color]).to eql cmyk_color.map(&:to_f)
  end

  it 'should allow width of border to be set only on ends' do
    pdf_theme = {
      code_border_color: 'AA0000',
      code_border_width: [1, nil],
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0][:from][:y]).to eql lines[0][:to][:y]
    (expect lines[1][:from][:y]).to eql lines[1][:to][:y]
  end

  it 'should allow width of border to be set only on sides' do
    pdf_theme = {
      code_border_color: 'AA0000',
      code_border_width: [nil, 1],
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    EOS

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0][:from][:x]).to eql lines[0][:to][:x]
    (expect lines[1][:from][:x]).to eql lines[1][:to][:x]
  end

  it 'should allow width of border on ends and sides to be different' do
    pdf_theme = {
      code_border_color: 'AA0000',
      code_border_width: [2, 1],
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    EOS

    lines = pdf.lines
    (expect lines).to have_size 4
    (expect lines[0][:from][:y]).to eql lines[0][:to][:y]
    (expect lines[0][:width]).to eql 2
    (expect lines[2][:from][:x]).to eql lines[2][:to][:x]
    (expect lines[2][:width]).to eql 1
  end

  it 'should use dashed border to indicate where block is split across a page boundary when border is only on ends', visual: true do
    pdf_theme = {
      code_border_color: 'AA0000',
      code_border_width: [1, 0],
    }

    to_file = to_pdf_file <<~EOS, 'listing-page-split-border-ends.pdf', pdf_theme: pdf_theme
    ----
    #{(['listing'] * 60).join ?\n}
    ----
    EOS

    (expect to_file).to visually_match 'listing-page-split-border-ends.pdf'
  end

  it 'should allow theme to set different padding per side' do
    pdf_theme = {
      code_border_radius: 0,
      code_padding: [5, 10, 15, 20],
      code_background_color: nil,
    }

    input = <<~EOS
    ----
    downloading#{(%w(.) * 100).join}done
    ----
    EOS

    text = (to_pdf input, pdf_theme: pdf_theme, analyze: true).text
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines

    left = lines[0][:from][:x]
    top = lines[0][:to][:y]
    bottom = lines[1][:to][:y]
    (expect text[0][:x]).to eql (left + 20.0).round 2
    (expect text[0][:y] + text[0][:font_size]).to be_within(1).of(top - 5)
    (expect text[1][:y]).to be_within(5).of(bottom + 15)
  end

  it 'should not substitute conums if callouts sub is absent' do
    pdf = to_pdf <<~'EOS', analyze: true
    [subs=-callouts]
    ----
    not a conum <1>
    ----
    EOS

    (expect pdf.lines).to include 'not a conum <1>'
    (expect pdf.find_text '①').to be_empty
  end
end
