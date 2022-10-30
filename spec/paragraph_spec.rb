# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Paragraph' do
  it 'should normalize newlines and whitespace' do
    pdf = to_pdf <<~END, analyze: true
    He's  a  real  nowhere  man,
    Sitting in his nowhere land,
    Making all his nowhere plans\tfor nobody.
    END
    (expect pdf.text).to have_size 1
    text = pdf.text[0][:string]
    (expect text).not_to include '  '
    (expect text).not_to include ?\t
    (expect text).not_to include ?\n
    (expect text).to include 'man, Sitting'
  end

  it 'should allow paragraph to flow over page boundary with correct top placement' do
    pdf_theme = {
      role_outline_border_width: 0.5,
      role_outline_border_color: '0000EE',
    }
    with_content_spacer 50, 675 do |spacer_path|
      input = <<~END
      [.outline]#top#

      image::#{spacer_path}[]

      #{(lorem_ipsum '2-sentences-1-paragraph').sub 'non', '[.outline]#non#'}
      #{(['fillmefillme'] * 380).join ' '} [.outline]#fin#
      END

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      (expect pdf.pages).to have_size 3
      (expect (pdf.find_unique_text 'top')[:page_number]).to eql 1
      (expect (pdf.find_unique_text 'non')[:page_number]).to eql 2
      (expect (pdf.find_unique_text 'fin')[:page_number]).to eql 3
      outlines = (to_pdf input, pdf_theme: pdf_theme, analyze: :rect).rectangles.reject {|it| it[:width] == 50.0 }
      (expect outlines).to have_size 3
      reference_outline, subject1_outline, subject2_outline = outlines
      expected_top = pdf.pages[0][:size][1] - 36 - 0.75
      initial_top = reference_outline.yield_self {|it| it[:point][1] + it[:height] }
      (expect initial_top).to eql expected_top
      top_after_first_page_break = subject1_outline.yield_self {|it| it[:point][1] + it[:height] }
      (expect top_after_first_page_break).to eql initial_top
      top_after_second_page_break = subject2_outline.yield_self {|it| it[:point][1] + it[:height] }
      (expect top_after_second_page_break).to eql initial_top
    end
  end

  it 'should indent first line of justified paragraph if prose_text_indent key is set in theme' do
    pdf = to_pdf (lorem_ipsum '2-paragraphs'), pdf_theme: { prose_text_indent: 18 }, analyze: true

    (expect pdf.text).to have_size 4
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
  end

  it 'should indent first line of left-aligned paragraph if prose_text_indent key is set in theme' do
    pdf = to_pdf (lorem_ipsum '2-paragraphs'), pdf_theme: { base_text_align: 'left', prose_text_indent: 18 }, analyze: true

    (expect pdf.text).to have_size 4
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
  end

  it 'should not indent first line of paragraph if text alignment is center' do
    input = <<~'END'
    [.text-center]
    x
    END

    expected_x = (to_pdf input, analyze: true).text[0][:x]
    actual_x = (to_pdf input, pdf_theme: { prose_text_indent: 18 }, analyze: true).text[0][:x]

    (expect actual_x).to eql expected_x
  end

  it 'should not indent first line of paragraph if text alignment is right' do
    input = <<~'END'
    [.text-right]
    x
    END

    expected_x = (to_pdf input, analyze: true).text[0][:x]
    actual_x = (to_pdf input, pdf_theme: { prose_text_indent: 18 }, analyze: true).text[0][:x]

    (expect actual_x).to eql expected_x
  end

  it 'should not alter line height of wrapped lines when prose_text_indent is set in theme that uses a TTF font' do
    input = lorem_ipsum '4-sentences-2-paragraphs'

    pdf = to_pdf input, analyze: true

    last_line_y = pdf.text[-1][:y]

    pdf = to_pdf input, pdf_theme: { prose_text_indent: 18 }, analyze: true

    (expect pdf.text[-1][:y]).to eql last_line_y
  end

  it 'should not alter line height of wrapped lines when prose_text_indent is set in theme that uses an AFM font' do
    input = lorem_ipsum '4-sentences-2-paragraphs'

    pdf = to_pdf input, pdf_theme: { extends: 'base' }, analyze: true

    last_line_y = pdf.text[-1][:y]

    pdf = to_pdf input, pdf_theme: { extends: 'base', prose_text_indent: 18 }, analyze: true

    (expect pdf.text[-1][:y]).to eql last_line_y
  end

  it 'should use prose_margin_inner between paragraphs when prose_text_indent key is set in theme' do
    pdf = to_pdf <<~END, pdf_theme: { prose_text_indent: 18, prose_margin_inner: 0 }, analyze: true
    #{lorem_ipsum '2-sentences-2-paragraphs'}

    * list item
    END

    line_spacing = 1.upto(3).map {|i| (pdf.text[i - 1][:y] - pdf.text[i][:y]).round 2 }.uniq
    (expect line_spacing).to have_size 1
    (expect line_spacing[0]).to eql 15.78
    (expect pdf.text[0][:x]).to be > pdf.text[1][:x]
    (expect pdf.text[2][:x]).to be > pdf.text[3][:x]
    list_item_text = (pdf.find_text 'list item')[0]
    (expect (pdf.text[3][:y] - list_item_text[:y]).round 2).to eql 27.78
  end

  it 'should use prose_margin_inner between paragraphs even when prose_text_indent key in theme is set to 0' do
    pdf = to_pdf <<~END, pdf_theme: { prose_text_indent: 0, prose_margin_inner: 0 }, analyze: true
    #{lorem_ipsum '2-sentences-2-paragraphs'}

    * list item
    END

    line_spacing = 1.upto(3).map {|i| (pdf.text[i - 1][:y] - pdf.text[i][:y]).round 2 }.uniq
    (expect line_spacing).to have_size 1
    (expect line_spacing[0]).to eql 15.78
    (expect pdf.text[0][:x]).to eql pdf.text[1][:x]
    (expect pdf.text[2][:x]).to eql pdf.text[3][:x]
    list_item_text = (pdf.find_text 'list item')[0]
    (expect (pdf.text[3][:y] - list_item_text[:y]).round 2).to eql 27.78
  end

  it 'should indent first line of inner paragraphs if prose_text_indent_inner key is set in theme' do
    left_margin = (to_pdf 'text', analyze: true).text[0][:x]
    pdf_theme = {
      prose_text_indent_inner: 10.5,
      prose_margin_inner: 0,
    }
    pdf = to_pdf <<~END, analyze: true, pdf_theme: pdf_theme
    #{lorem_ipsum '2-sentences-1-paragraph'}

    #{lorem_ipsum '2-sentences-1-paragraph'}

    > quote

    #{lorem_ipsum '2-sentences-1-paragraph'}

    #{lorem_ipsum '2-sentences-1-paragraph'}
    END

    lorem_texts = pdf.find_text %r/^Lorem/
    (expect lorem_texts).to have_size 4
    (expect lorem_texts[0][:x]).to eql left_margin
    (expect lorem_texts[1][:x]).to be > left_margin
    (expect lorem_texts[2][:x]).to eql left_margin
    (expect lorem_texts[3][:x]).to be > left_margin
  end

  it 'should allow text alignment to be controlled using text-align document attribute' do
    pdf = to_pdf <<~'END', analyze: true
    = Document Title
    :text-align: right

    right-aligned
    END

    center_x = (pdf.page 1)[:size][1] / 2
    paragraph_text = (pdf.find_text 'right-aligned')[0]
    (expect paragraph_text[:x]).to be > center_x
  end

  it 'should output block title for paragraph if specified' do
    pdf = to_pdf <<~'END', analyze: true
    .Disclaimer
    All views expressed are my own.
    END

    (expect pdf.lines).to eql ['Disclaimer', 'All views expressed are my own.']
    disclaimer_text = (pdf.find_text 'Disclaimer')[0]
    (expect disclaimer_text[:font_name]).to eql 'NotoSerif-Italic'
  end

  it 'should use base text align if caption align is set to inherit' do
    pdf = to_pdf <<~'END', pdf_theme: { base_text_align: 'right', caption_align: 'inherit' }, analyze: true
    .Title
    Text
    END

    center_x = (pdf.page 1)[:size][1] * 0.5
    title_text = pdf.find_unique_text 'Title'
    paragraph_text = pdf.find_unique_text 'Text'
    (expect title_text[:x]).to be > center_x
    (expect paragraph_text[:x]).to be > center_x
  end

  it 'should use value of align on caption to align text if caption_text_align key not specified' do
    pdf = to_pdf <<~'END', pdf_theme: { caption_align: 'right' }, analyze: true
    .Title
    Text
    END

    center_x = (pdf.page 1)[:size][1] * 0.5
    title_text = pdf.find_unique_text 'Title'
    paragraph_text = pdf.find_unique_text 'Text'
    (expect title_text[:x]).to be > center_x
    (expect paragraph_text[:x]).to eql 48.24
  end

  it 'should apply the lead style to a paragraph with the lead role' do
    pdf = to_pdf <<~'END', analyze: true
    = Document Title

    preamble content

    [.lead]
    more preamble content

    == First Section

    section content
    END

    preamble_text = pdf.find_text 'preamble content'
    (expect preamble_text).to have_size 1
    (expect preamble_text[0][:font_size]).to be 13
    more_preamble_text = pdf.find_text 'more preamble content'
    (expect more_preamble_text).to have_size 1
    (expect more_preamble_text[0][:font_size]).to be 13
  end

  it 'should allow the theme to control the line height of a lead paragraph' do
    input = <<~END
    [.lead]
    #{lorem_ipsum '2-sentences-1-paragraph'}
    END

    reference_texts = (to_pdf input, analyze: true).text
    default_spacing = reference_texts[0][:y] - reference_texts[1][:y]

    texts = (to_pdf input, pdf_theme: { role_lead_line_height: 2 }, analyze: true).text
    adjusted_spacing = texts[0][:y] - texts[1][:y]

    (expect adjusted_spacing).to be > default_spacing
  end

  it 'should apply font properties defined by role to paragraph' do
    pdf_theme = {
      role_custom_font_size: 14,
      role_custom_font_color: 'FF0000',
      role_custom_text_align: :center,
      role_custom_font_style: 'bold',
      role_custom_text_transform: 'lowercase',
    }

    input = <<~END
    reference

    [.custom]
    This is a special paragraph.
    END

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    left_margin = pdf.text[0][:x]
    text_with_role = pdf.text[1]
    (expect text_with_role[:font_size]).to eql pdf_theme[:role_custom_font_size]
    (expect text_with_role[:font_color]).to eql pdf_theme[:role_custom_font_color]
    (expect text_with_role[:font_name]).to eql 'NotoSerif-Bold'
    (expect text_with_role[:x]).to be > left_margin
    (expect text_with_role[:string]).to eql 'this is a special paragraph.'
  end

  it 'should allow the theme to control the line height of a paragraph with a custom role' do
    input = <<~END
    [.spaced-out]
    #{lorem_ipsum '2-sentences-1-paragraph'}
    END

    reference_texts = (to_pdf input, analyze: true).text
    default_spacing = reference_texts[0][:y] - reference_texts[1][:y]

    texts = (to_pdf input, pdf_theme: { 'role_spaced-out_line_height': 2 }, analyze: true).text
    adjusted_spacing = texts[0][:y] - texts[1][:y]

    (expect adjusted_spacing).to be > default_spacing
  end
end
