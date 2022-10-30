# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Example' do
  it 'should keep block together if it can fit on one page' do
    pdf = to_pdf <<~END, analyze: true
    #{(['filler'] * 15).join %(\n\n)}

    [%unbreakable]
    ====
    #{(['content'] * 15).join %(\n\n)}
    ====
    END

    example_text = (pdf.find_text 'content')[0]
    (expect example_text[:page_number]).to be 2
  end

  it 'should include title if specified' do
    pdf = to_pdf <<~'END', analyze: true
    .Title
    ====
    Content
    ====
    END

    title_texts = pdf.find_text 'Example 1. Title'
    (expect title_texts).to have_size 1
  end

  it 'should include title if specified and background and border are not set' do
    pdf = to_pdf <<~'END', pdf_theme: { example_background_color: 'transparent', example_border_width: 0 }, analyze: true
    .Title
    ====
    Content
    ====
    END

    title_texts = pdf.find_text 'Example 1. Title'
    (expect title_texts).to have_size 1
  end

  it 'should keep title with content when block is advanced to next page' do
    pdf = to_pdf <<~END, analyze: true
    #{(['filler'] * 15).join %(\n\n)}

    .Title
    [%unbreakable]
    ====
    #{(['content'] * 15).join %(\n\n)}
    ====
    END

    example_title_text = (pdf.find_text 'Example 1. Title')[0]
    example_content_text = (pdf.find_text 'content')[0]
    (expect example_title_text[:page_number]).to be 2
    (expect example_content_text[:page_number]).to be 2
  end

  it 'should split block if it cannot fit on one page' do
    pdf = to_pdf <<~END, analyze: true
    .Title
    [%unbreakable]
    ====
    #{(['content'] * 30).join %(\n\n)}
    ====
    END

    example_title_text = (pdf.find_text 'Example 1. Title')[0]
    example_content_text = (pdf.find_text 'content')
    (expect example_title_text[:page_number]).to be 1
    (expect example_content_text[0][:page_number]).to be 1
    (expect example_content_text[-1][:page_number]).to be 2
  end

  it 'should split border when block is split across pages', visual: true do
    to_file = to_pdf_file <<~END, 'example-page-split.pdf'
    .Title
    [%unbreakable]
    ====
    #{(['content'] * 30).join %(\n\n)}
    ====
    END

    (expect to_file).to visually_match 'example-page-split.pdf'
  end

  it 'should not collapse bottom padding if block ends near bottom of page' do
    pdf_theme = {
      example_padding: 12,
      example_background_color: 'EEEEEE',
      example_border_width: 0,
      example_border_radius: 0,
    }
    pdf = with_content_spacer 10, 690 do |spacer_path|
      to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      image::#{spacer_path}[]

      ====
      content +
      that wraps
      ====
      END
    end

    pages = pdf.pages
    (expect pages).to have_size 1
    gs = pdf.extract_graphic_states pages[0][:raw_content]
    (expect gs[1]).to have_background color: 'EEEEEE', top_left: [48.24, 103.89], bottom_right: [48.24, 48.33]
    last_text_y = pdf.text[-1][:y]
    (expect last_text_y - pdf_theme[:example_padding]).to be > 48.24

    pdf = with_content_spacer 10, 692 do |spacer_path|
      to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      image::#{spacer_path}[]

      ====
      content +
      that wraps
      ====
      END
    end

    pages = pdf.pages
    (expect pages).to have_size 2
    gs = pdf.extract_graphic_states pages[0][:raw_content]
    (expect gs[1]).to have_background color: 'EEEEEE', top_left: [48.24, 101.89], bottom_right: [48.24, 48.24]
    (expect pdf.text[0][:page_number]).to eql 1
    (expect pdf.text[1][:page_number]).to eql 2
    (expect pdf.text[0][:y] - pdf_theme[:example_padding]).to be > 48.24
  end

  it 'should draw border around whole block when block contains nested unbreakable block', visual: true do
    to_file = to_pdf_file <<~END, 'example-with-nested-block-page-split.pdf'
    .Title
    ====
    #{(['content'] * 25).join %(\n\n)}

    [NOTE%unbreakable]
    ======
    This block does not fit on a single page.

    Therefore, it is split across multiple pages.
    ======

    #{(['content'] * 5).join %(\n\n)}
    ====
    END

    (expect to_file).to visually_match 'example-with-nested-block-page-split.pdf'
  end

  it 'should not add signifier and numeral to caption if example-caption attribute is unset' do
    pdf = to_pdf <<~'END', analyze: true
    :!example-caption:

    .Title
    ====
    content
    ====
    END

    (expect pdf.lines[0]).to eql 'Title'
  end

  it 'should allow theme to override caption for example blocks' do
    pdf_theme = {
      caption_font_color: '0000ff',
      example_caption_font_style: 'bold',
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Title
    ====
    content
    ====
    END

    title_text = (pdf.find_text 'Example 1. Title')[0]
    (expect title_text[:font_color]).to eql '0000FF'
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
  end

  it 'should allow theme to place caption below block' do
    pdf_theme = { example_caption_end: 'bottom' }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Look out below!
    ====
    content
    ====
    END

    content_text = pdf.find_unique_text 'content'
    title_text = pdf.find_unique_text 'Example 1. Look out below!'
    (expect title_text[:y]).to be < content_text[:y]
  end

  it 'should apply text decoration to caption' do
    pdf_theme = {
      caption_text_decoration: 'underline',
      caption_text_decoration_color: 'DDDDDD',
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    .Title
    ====
    content
    ====
    END

    underline = pdf.lines.find {|it| it[:color] = 'DDDDDD' }
    (expect underline).not_to be_nil
    (expect underline[:from][:y]).to eql underline[:to][:y]
    (expect underline[:from][:x]).to be < underline[:to][:x]
  end

  it 'should apply border style set by theme' do
    pdf_theme = {
      example_border_style: 'double',
      example_border_width: 3,
      example_border_radius: 0,
      example_border_color: '333333',
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    ====
    example

    content

    here
    ====
    END

    lines = pdf.lines
    (expect lines).to have_size 8
    (expect lines.map {|it| it[:width] }.uniq).to eql [1.0]
    outer_left_x = 48.24
    outer_right_x = 547.04
    outer_lines = lines.select {|it| it[:from][:x] == outer_left_x || it[:from][:x] == outer_right_x }
    (expect outer_lines).to have_size 4
    inner_left_x = 50.24
    inner_right_x = 545.04
    inner_lines = lines.select {|it| it[:from][:x] == inner_left_x || it[:from][:x] == inner_right_x }
    (expect inner_lines).to have_size 4
  end

  it 'should cap the border corners when border width is specified as ends and sides', visual: true do
    pdf_theme = {
      example_border_width: [4, 6],
      example_border_color: 'DDDDDD',
      example_padding: 3,
    }

    input = <<~'END'
    ====
    first

    last
    ====
    END

    to_file = to_pdf_file input, 'example-uneven-border-end-caps.pdf', pdf_theme: pdf_theme
    (expect to_file).to visually_match 'example-uneven-border-end-caps.pdf'
  end

  it 'should cap the border corners when border width is specified as single value', visual: true do
    pdf_theme = {
      example_border_width: 4,
      example_border_color: 'DDDDDD',
      example_border_radius: 0,
      example_padding: 3,
    }

    input = <<~'END'
    ====
    first

    last
    ====
    END

    # NOTE: visually, these two reference files are identical, but the image comparator doesn't think so
    to_file = to_pdf_file input, 'example-singular-border-end-caps.pdf', pdf_theme: pdf_theme
    (expect to_file).to visually_match 'example-singular-border-end-caps.pdf'

    to_file = to_pdf_file input, 'example-uniform-array-border-end-caps.pdf', pdf_theme: (pdf_theme.merge example_border_width: [4, 4])
    (expect to_file).to visually_match 'example-uniform-array-border-end-caps.pdf'
  end

  it 'should add correct padding around content when using default theme' do
    input = <<~'END'
    ====
    first

    last
    ====
    END

    pdf = to_pdf input, analyze: true
    lines = (to_pdf input, analyze: :line).lines

    (expect lines).to have_size 4
    (expect lines.map {|it| it[:color] }.uniq).to eql ['EEEEEE']
    (expect lines.map {|it| it[:width] }.uniq).to eql [0.75]
    top, bottom = lines.map {|it| [it[:from][:y], it[:to][:y]] }.flatten.yield_self {|it| [it.max, it.min] }
    left = lines.map {|it| [it[:from][:x], it[:to][:x]] }.flatten.min
    text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
    text_bottom = (pdf.find_unique_text 'last')[:y]
    text_left = (pdf.find_unique_text 'first')[:x]
    (expect (top - text_top).to_f).to (be_within 1.5).of 12.0
    (expect (text_bottom - bottom).to_f).to (be_within 1).of 15.0 # extra padding is descender
    (expect (text_left - left).to_f).to eql 12.0
  end

  it 'should add equal padding around content when using base theme' do
    input = <<~'END'
    ====
    first

    last
    ====
    END

    pdf = to_pdf input, attribute_overrides: { 'pdf-theme' => 'base' }, analyze: true
    lines = (to_pdf input, attribute_overrides: { 'pdf-theme' => 'base' }, analyze: :line).lines

    (expect lines).to have_size 4
    (expect lines.map {|it| it[:color] }.uniq).to eql %w(000000)
    (expect lines.map {|it| it[:width] }.uniq).to eql [0.5]
    top, bottom = lines.map {|it| [it[:from][:y], it[:to][:y]] }.flatten.yield_self {|it| [it.max, it.min] }
    left = lines.map {|it| [it[:from][:x], it[:to][:x]] }.flatten.min
    text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
    text_bottom = (pdf.find_unique_text 'last')[:y]
    text_left = (pdf.find_unique_text 'first')[:x]
    (expect (top - text_top).to_f).to (be_within 1).of 12.0
    (expect (text_bottom - bottom).to_f).to (be_within 1).of 15.0 # extra padding is descender
    (expect (text_left - left).to_f).to eql 12.0
  end

  it 'should use informal title, indented content, no border or shading, and bottom margin if collapsible option is set' do
    input = <<~'END'
    .Reveal Answer
    [%collapsible]
    ====
    This is a PDF, so the answer is always visible.
    ====

    Paragraph following collapsible block.
    END

    pdf = to_pdf input, analyze: true
    lines = pdf.lines
    expected_lines = [
      %(\u25bc Reveal Answer),
      'This is a PDF, so the answer is always visible.',
      'Paragraph following collapsible block.',
    ]
    (expect lines).to eql expected_lines
    (expect pdf.text[0][:x]).to eql pdf.text[2][:x]
    (expect pdf.text[1][:x]).to be > pdf.text[2][:x]
    (expect pdf.text[1][:y] - (pdf.text[2][:y] + pdf.text[2][:font_size])).to be > 12

    pdf = to_pdf input, analyze: :line
    (expect pdf.lines).to be_empty
  end

  # see https://developer.mozilla.org/en-US/docs/Web/HTML/Element/summary#default_label_text
  it 'should use fallback title for collapsible block if no title is specified' do
    input = <<~'END'
    [%collapsible]
    ====
    These are the details.
    ====
    END

    pdf = to_pdf input, analyze: true
    (expect pdf.text[0][:string]).to eql %(\u25bc Details)
  end

  it 'should align left margin of content of collapsible block with start of title text' do
    input = <<~'END'
    .*Spoiler*
    [%collapsible]
    ====
    Now you can't unsee it.
    Muahahahaha.
    ====
    END

    pdf = to_pdf input, analyze: true
    (expect pdf.text[0][:x]).to eql 48.24
    (expect pdf.text[1][:x]).to be > 48.24
    (expect pdf.text[2][:x]).to be > 48.24
    (expect pdf.text[1][:x]).to eql pdf.text[2][:x]
  end

  it 'should insert block margin between bottom of content and next block' do
    pdf_theme = {
      code_background_color: 'transparent',
      code_border_radius: 0,
      code_border_width: [1, 0],
    }
    input = <<~'END'
    [%collapsible]
    ====
    ----
    inside
    ----
    ====

    ----
    below
    ----
    END

    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines.sort_by {|it| -it[:from][:y] }
    (expect lines).to have_size 4
    (expect lines[1][:from][:y] - lines[2][:from][:y]).to eql 12.0
  end
end
