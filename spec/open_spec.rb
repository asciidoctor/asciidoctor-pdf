# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Open' do
  it 'should be breakable by default' do
    with_content_spacer 10, 720 do |spacer_path|
      pdf = to_pdf <<~EOS, analyze: true
      image::#{spacer_path}[]

      --
      first page

      second page
      --
      EOS
      (expect pdf.pages).to have_size 2
      (expect (pdf.find_unique_text 'first page')[:page_number]).to be 1
      (expect (pdf.find_unique_text 'second page')[:page_number]).to be 2
    end
  end

  it 'should keep block together when it has the unbreakable option', visual: true do
    to_file = to_pdf_file <<~EOS, 'open-unbreakable-option-fit.pdf'
    Make it rain.footnote:[money]

    #{(['filler'] * 21).join %(\n\n)}

    [%unbreakable]
    --
    To install Antora, open a terminal and type:

     $ npm i -g @antora/cli@2.2 @antora/site-generator-default@2.2

    The `@` at the beginning of the package name is important.
    It tells `npm` that the `cli` package is located in the `antora` group.
    If you omit this character, `npm` will assume the package name is the name of a git repository on GitHub.
    The second `@` offsets the requested version number.footnote:[Clarification about this statement.]
    Only the major and minor segments are specified to ensure you receive the latest patch update.
    --

    Make it snow.footnote:[dollar bills]
    EOS

    (expect to_file).to visually_match 'open-unbreakable-option-fit.pdf'
  end

  it 'should break an unbreakable block if it does not fit on one page', visual: true do
    to_file = to_pdf_file <<~EOS, 'open-unbreakable-option-break.pdf'
    Make it rain.footnote:[money]

    #{(['filler'] * 21).join %(\n\n)}

    [%unbreakable]
    --
    To install Antora, open a terminal and type:

     $ npm i -g @antora/cli@2.2 @antora/site-generator-default@2.2

    The `@` at the beginning of the package name is important.
    It tells `npm` that the `cli` package is located in the `antora` group.
    If you omit this character, `npm` will assume the package name is the name of a git repository on GitHub.
    The second `@` offsets the requested version number.footnote:[Clarification about this statement.]
    Only the major and minor segments are specified to ensure you receive the latest patch update.

    #{(['filler inside open block'] * 25).join %(\n\n)}
    --

    Make it snow.footnote:[dollar bills]
    EOS

    (expect to_file).to visually_match 'open-unbreakable-option-break.pdf'
  end

  it 'should include title if specified' do
    pdf = to_pdf <<~'EOS', analyze: true
    .Title
    --
    content
    --
    EOS

    title_texts = pdf.find_text 'Title'
    (expect title_texts).to have_size 1
    title_text = title_texts[0]
    (expect title_text[:font_name]).to eql 'NotoSerif-Italic'
    (expect title_text[:y]).to be > (pdf.find_unique_text 'content')[:y]
  end

  it 'should keep title with content if content is advanced to new page' do
    pdf = with_content_spacer 10, 700 do |spacer_path|
      to_pdf <<~EOS, analyze: true
      image::#{spacer_path}[]

      .Title
      [%unbreakable]
      --
      content

      more content
      --
      EOS
    end
    (expect pdf.pages).to have_size 2
    (expect (pdf.find_unique_text 'content')[:page_number]).to be 2
    (expect (pdf.find_unique_text 'Title')[:page_number]).to be 2
  end

  it 'should not dry run block unless necessary' do
    calls = []
    extensions = proc do
      block :spy do
        on_context :paragraph
        process do |parent, reader, attrs|
          block = create_paragraph parent, reader.lines, attrs
          block.instance_variable_set :@_calls, calls
          block.extend (Module.new do
            def content
              @_calls << (caller.join ?\n) if document.converter.scratch? # rubocop:disable RSpec/InstanceVariable
              super
            end
          end)
        end
      end
    end

    {
      '' => false,
      %(.title) => false,
      %([#idname]) => false,
      %([%unbreakable]) => false,
      %(before\n) => false,
      %(before\n\n.title) => true,
      %(before\n\n[#idname]) => true,
      %(before\n\n[%unbreakable]) => true,
    }.each do |before_block, dry_run|
      input = <<~EOS.lstrip
      #{before_block}
      --
      #{['block content'] * 4 * %(\n\n)}

      [spy]
      block content
      --
      EOS
      pdf = to_pdf input, extensions: extensions, analyze: true
      (expect pdf.pages).to have_size 1
      (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
      if dry_run
        (expect calls).not_to be_empty
      else
        (expect calls).to be_empty
      end
    end
  end
end
