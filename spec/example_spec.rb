require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Example' do
  it 'should keep block together when it has the unbreakable option' do
    to_file = to_pdf_file <<~EOS, 'example-unbreakable-option-fit.pdf'
    Make it rain.footnote:[money]

    #{(['filler'] * 21).join %(\n\n)}
    [%unbreakable]
    --
    To install Antora, open a terminal and type:
    
     $ npm i -g @antora/cli@2.2 @antora/site-generator-default@2.2
    
    IMPORTANT: The `@` at the beginning of the package name is important.
    It tells `npm` that the `cli` package is located in the `antora` group.
    If you omit this character, `npm` will assume the package name is the name of a git repository on GitHub.
    The second `@` offsets the requested version number.footnote:[Clarification about this statement.]
    Only the major and minor segments are specified to ensure you receive the latest patch update.
    --

    Make it snow.footnote:[dollar bills]
    EOS

    (expect to_file).to visually_match 'example-unbreakable-option-fit.pdf'
  end

  it 'should break an unbreakable block if it does not fit on one page' do
    to_file = to_pdf_file <<~EOS, 'example-unbreakable-option-break.pdf'
    Make it rain.footnote:[money]

    #{(['filler'] * 21).join %(\n\n)}

    [%unbreakable]
    --
    To install Antora, open a terminal and type:
    
     $ npm i -g @antora/cli@2.2 @antora/site-generator-default@2.2
    
    IMPORTANT: The `@` at the beginning of the package name is important.
    It tells `npm` that the `cli` package is located in the `antora` group.
    If you omit this character, `npm` will assume the package name is the name of a git repository on GitHub.
    The second `@` offsets the requested version number.footnote:[Clarification about this statement.]
    Only the major and minor segments are specified to ensure you receive the latest patch update.

    #{(['filler'] * 25).join %(\n\n)}
    --

    Make it snow.footnote:[dollar bills]
    EOS

    (expect to_file).to visually_match 'example-unbreakable-option-break.pdf'
  end

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
