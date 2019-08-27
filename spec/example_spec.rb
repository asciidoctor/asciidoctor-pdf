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
    (expect example_text[:page_number]).to eql 2
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
    (expect example_title_text[:page_number]).to eql 2
    (expect example_content_text[:page_number]).to eql 2
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
    (expect example_title_text[:page_number]).to eql 1
    (expect example_content_text[0][:page_number]).to eql 1
    (expect example_content_text[-1][:page_number]).to eql 2
  end

  it 'should split border when block is split across pages', integration: true do
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
end
