# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Quote' do
  it 'should show caption above block if title is specified' do
    input = <<~'EOS'
    .Words of wisdom
    ____
    Let it be.
    ____
    EOS

    pdf = to_pdf input, analyze: :line
    lines = pdf.lines
    (expect pdf.lines).to have_size 1

    pdf = to_pdf input, analyze: true
    (expect pdf.lines).to eql ['Words of wisdom', 'Let it be.']
    title_text = (pdf.find_text 'Words of wisdom')[0]
    body_text = (pdf.find_text 'Let it be.')[0]
    (expect title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect title_text[:x]).to eql 48.24
    (expect title_text[:y]).to be > lines[0][:from][:y]
    (expect title_text[:x]).to be < lines[0][:from][:x]
    (expect lines[0][:from][:x]).to be < body_text[:x]
  end

  it 'should show attribution line below text of quote' do
    pdf = to_pdf <<~'EOS', analyze: true
    [,Alice Walker,Speech]
    ____
    The most common way people give up their power is by thinking they don't have any.
    ____
    EOS

    last_quote_text = pdf.text[-2]
    attribution_text = (pdf.find_text %r/Alice Walker/)[0]
    (expect attribution_text[:string]).to eql %(\u2014 Alice Walker, Speech)
    (expect attribution_text[:font_size]).to eql 9
    (expect attribution_text[:font_color]).to eql '999999'
    (expect attribution_text[:font_name]).to eql 'NotoSerif'
    (expect (last_quote_text[:y] - attribution_text[:y]).round).to eql 27
    (expect attribution_text[:x]).to eql last_quote_text[:x]
  end

  it 'should escape bare ampersand in attribution' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      [quote, J. Helliwell & B. McMahon]
      The richer the metadata available to the scientist, the greater the potential for new discoveries.
      EOS

      (expect pdf.lines[-1]).to eql %(\u2014 J. Helliwell & B. McMahon)
    end).to not_log_message
  end

  it 'should escape bare ampersand in citetitle' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      [quote, J. Helliwell & B. McMahon, Melbourne Congress & General Assembly of the IUCr]
      The richer the metadata available to the scientist, the greater the potential for new discoveries.
      EOS

      (expect pdf.lines[-1]).to eql %(\u2014 J. Helliwell & B. McMahon, Melbourne Congress & General Assembly of the IUCr)
    end).to not_log_message
  end

  it 'should render character reference in attribution' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      [quote, J. Helliwell & B. McMahon &#169; IUCr]
      The richer the metadata available to the scientist, the greater the potential for new discoveries.
      EOS

      (expect pdf.lines[-1]).to eql %(\u2014 J. Helliwell & B. McMahon \u00a9 IUCr)
    end).to not_log_message
  end

  it 'should apply substitutions to attribution and citetitle if enclosed in single quotes' do
    input = <<~'EOS'
    [, 'Author--aka Alias', 'https://asciidoctor.org[Source]']
    ____
    Use the attribution and citetitle attributes to credit the author and identify the source of the quote, respectively.
    ____
    EOS

    pdf = to_pdf input, analyze: true
    attribution_text, citetitle_text = (pdf.find_text font_size: 9)
    (expect attribution_text[:string]).to eql %(\u2014 Author\u2014aka Alias, )
    (expect citetitle_text[:string]).to eql 'Source'
    (expect citetitle_text[:font_color]).to eql '428BCA'

    pdf = to_pdf input
    annotations = get_annotations pdf, 1
    (expect annotations).to have_size 1
    link_annotation = annotations[0]
    (expect link_annotation[:Subtype]).to be :Link
    (expect link_annotation[:A][:URI]).to eql 'https://asciidoctor.org'
    (expect link_annotation[:Rect][0]).to eql citetitle_text[:x]
    (expect link_annotation[:Rect][2]).to eql (citetitle_text[:x] + citetitle_text[:width])
  end

  it 'should not draw left border if border_left_width is 0' do
    pdf = to_pdf <<~'EOS', pdf_theme: { blockquote_border_left_width: 0 }, analyze: :line
    ____
    Let it be.
    ____
    EOS

    (expect pdf.lines).to be_empty
  end

  it 'should not draw left border if border_left_width is nil' do
    pdf = to_pdf <<~'EOS', pdf_theme: { blockquote_border_left_width: nil, blockquote_border_width: nil }, analyze: :line
    ____
    Let it be.
    ____
    EOS

    (expect pdf.lines).to be_empty
  end

  it 'should not draw left border on next page if block falls at bottom of page' do
    pdf_theme = {
      thematic_break_border_color: 'DDDDDD',
      thematic_break_margin_bottom: 669.75,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
    filler

    ---

    ____
    Let it be.

    Let it be.
    ____

    Words of wisdom were spoken.
    EOS

    quote_borders = pdf.lines.select {|it| it[:color] == 'EEEEEE' }
    (expect quote_borders).to have_size 1
    (expect quote_borders[0][:page_number]).to be 1
  end

  it 'should apply specified background color', visual: true do
    pdf_theme = {
      blockquote_background_color: 'dddddd',
      blockquote_border_color: 'aa0000',
    }
    to_file = to_pdf_file <<~'EOS', 'quote-background-color.pdf', pdf_theme: pdf_theme
    ____
    Let it be. +
    Let it be.
    ____
    EOS

    (expect to_file).to visually_match 'quote-background-color.pdf'
  end

  it 'should apply specified border and background color', visual: true do
    pdf_theme = build_pdf_theme \
      blockquote_border_left_width: 0,
      blockquote_border_width: 0.5,
      blockquote_border_color: 'aa0000',
      blockquote_background_color: 'dddddd'
    pdf_theme.blockquote_padding = pdf_theme.sidebar_padding
    to_file = to_pdf_file <<~'EOS', 'quote-border-and-background-color.pdf', pdf_theme: pdf_theme
    [,Paul McCartney]
    ____
    Let it be. +
    Let it be.
    ____
    EOS

    (expect to_file).to visually_match 'quote-border-and-background-color.pdf'
  end

  it 'should split border when block is split across pages', visual: true do
    pdf_theme = {
      blockquote_border_left_width: 0,
      blockquote_border_width: 0.5,
      blockquote_border_color: 'CCCCCC',
      blockquote_background_color: 'EEEEEE',
      blockquote_padding: [6, 10, 0, 10],
    }
    to_file = to_pdf_file <<~EOS, 'quote-page-split.pdf', pdf_theme: pdf_theme
    ____
    #{(['Let it be.'] * 30).join %(\n\n)}
    ____
    EOS

    (expect to_file).to visually_match 'quote-page-split.pdf'
  end

  it 'should advance to next page if block is split and caption does not fit' do
    quote = ['Power concedes nothing without a demand.', 'It never did and it never will.'].join %( +\n)
    with_content_spacer 10, 705 do |spacer_path|
      input = <<~EOS
      before

      image::#{spacer_path}[]

      .Sage advice by Frederick Douglass
      ____
      #{([quote] * 18).join %(\n\n)}
      ____
      EOS

      pdf = to_pdf input, analyze: true
      advice_text = pdf.find_unique_text 'Sage advice by Frederick Douglass'
      (expect advice_text[:page_number]).to be 2
      (expect advice_text[:y] + advice_text[:font_size]).to ((be_within 1).of 805)
    end
  end

  it 'should keep caption with block and draw border across extent if only caption fits on current page' do
    block_content = ['text of quote'] * 15 * %(\n\n)
    pdf_theme = { prose_margin_bottom: 12, blockquote_padding: [0, 0, -12, 15] }
    with_content_spacer 10, 690 do |spacer_path|
      input = <<~EOS
      before

      image::#{spacer_path}[]

      .Sage advice
      ____
      #{block_content}
      ____
      EOS

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
      (expect pdf.pages).to have_size 2
      advice_text = pdf.find_unique_text 'Sage advice'
      (expect advice_text[:page_number]).to be 2
      (expect advice_text[:y] + advice_text[:font_size]).to ((be_within 1).of 805)
      quote_text = (pdf.find_text 'text of quote')
      # NOTE: y location of text does not include descender
      quote_text_start_y = quote_text[0][:y] + quote_text[0][:font_size] + 1.5
      quote_text_end_y = quote_text[-1][:y] - 4.5
      border_left_line = lines.find {|it| it[:color] == 'EEEEEE' }
      (expect border_left_line[:page_number]).to be 2
      border_left_line_start_y, border_left_line_end_y = [border_left_line[:from][:y], border_left_line[:to][:y]].sort.reverse
      (expect border_left_line_start_y).to (be_within 0.5).of (quote_text_start_y)
      (expect border_left_line_end_y).to (be_within 0.5).of (quote_text_end_y)
    end
  end
end
