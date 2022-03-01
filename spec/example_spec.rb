# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Example' do
  it 'should keep block together if it can fit on one page' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['filler'] * 15).join %(\n\n)}

    ====
    #{(['content'] * 15).join %(\n\n)}
    ====
    EOS

    example_text = (pdf.find_text 'content')[0]
    (expect example_text[:page_number]).to be 2
  end

  it 'should include title if specified' do
    pdf = to_pdf <<~'EOS', analyze: true
    .Title
    ====
    Content
    ====
    EOS

    title_texts = pdf.find_text 'Example 1. Title'
    (expect title_texts).to have_size 1
  end

  it 'should include title if specified and background and border are not set' do
    pdf = to_pdf <<~'EOS', pdf_theme: { example_background_color: 'transparent', example_border_width: 0 }, analyze: true
    .Title
    ====
    Content
    ====
    EOS

    title_texts = pdf.find_text 'Example 1. Title'
    (expect title_texts).to have_size 1
  end

  it 'should keep title with content when block is advanced to next page' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['filler'] * 15).join %(\n\n)}

    .Title
    ====
    #{(['content'] * 15).join %(\n\n)}
    ====
    EOS

    example_title_text = (pdf.find_text 'Example 1. Title')[0]
    example_content_text = (pdf.find_text 'content')[0]
    (expect example_title_text[:page_number]).to be 2
    (expect example_content_text[:page_number]).to be 2
  end

  it 'should split block if it cannot fit on one page' do
    pdf = to_pdf <<~EOS, analyze: true
    .Title
    ====
    #{(['content'] * 30).join %(\n\n)}
    ====
    EOS

    example_title_text = (pdf.find_text 'Example 1. Title')[0]
    example_content_text = (pdf.find_text 'content')
    (expect example_title_text[:page_number]).to be 1
    (expect example_content_text[0][:page_number]).to be 1
    (expect example_content_text[-1][:page_number]).to be 2
  end

  it 'should split border when block is split across pages', visual: true do
    to_file = to_pdf_file <<~EOS, 'example-page-split.pdf'
    .Title
    ====
    #{(['content'] * 30).join %(\n\n)}
    ====
    EOS

    (expect to_file).to visually_match 'example-page-split.pdf'
  end

  it 'should not add signifier and numeral to caption if example-caption attribute is unset' do
    pdf = to_pdf <<~'EOS', analyze: true
    :!example-caption:

    .Title
    ====
    content
    ====
    EOS

    (expect pdf.lines[0]).to eql 'Title'
  end

  it 'should allow theme to override caption for example blocks' do
    pdf_theme = {
      caption_font_color: '0000ff',
      example_caption_font_style: 'bold',
    }

    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    .Title
    ====
    content
    ====
    EOS

    title_text = (pdf.find_text 'Example 1. Title')[0]
    (expect title_text[:font_color]).to eql '0000FF'
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
  end
end
