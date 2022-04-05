# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter#arrange_block' do
  let :pdf_theme do
    {
      page_margin: 50,
      page_size: 'Letter',
      example_background_color: 'ffffcc',
      example_border_radius: 0,
      example_border_width: 0,
      sidebar_border_radius: 0,
      sidebar_border_width: 0,
    }
  end

  it 'should draw background across extent of empty block' do
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    before block

    ====
    ====

    after block
    EOS

    pages = pdf.pages
    (expect pages).to have_size 1
    (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
    (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
    gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
    (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 702.22]
  end

  it 'should not draw backgrounds and borders in scratch document' do
    pdf_theme[:sidebar_border_color] = '222222'
    pdf_theme[:sidebar_border_width] = 0.5
    input = <<~'EOS'
    before

    [%unbreakable]
    --
    ====
    example

    ****
    sidebar
    ****

    example
    ====
    --
    EOS
    scratch_pdf = nil
    extensions = proc do
      postprocessor do
        process do |doc, output|
          scratch_pdf = doc.converter.scratch
          output
        end
      end
    end
    to_pdf input, pdf_theme: pdf_theme, extensions: extensions
    scratch_pdf_output = scratch_pdf.render
    scratch_pdf = (EnhancedPDFTextInspector.analyze scratch_pdf_output)
    (expect (scratch_pdf.extract_graphic_states scratch_pdf.pages[0][:raw_content])).to be_empty
    scratch_pdf_lines = (LineInspector.analyze scratch_pdf_output).lines
    (expect scratch_pdf_lines).to be_empty
  end

  it 'should invoke on_page_create if set on scratch document' do
    input = <<~'EOS'
    scratch_background_color:CCCCCC[]

    image::tall.svg[pdfwidth=70mm]

    ====
    content

    of

    block
    ====
    EOS
    scratch_pdf = nil
    extensions = proc do
      inline_macro :scratch_background_color do
        process do |parent, target|
          (scratch_pdf = parent.document.converter.scratch).on_page_create do
            scratch_pdf.fill_absolute_bounds target
          end
          create_inline parent, :quoted, 'before'
        end
      end
    end
    to_pdf input, pdf_theme: pdf_theme, extensions: extensions
    scratch_pdf_output = scratch_pdf.render
    scratch_pdf = (EnhancedPDFTextInspector.analyze scratch_pdf_output)
    (expect scratch_pdf.pages[0][:raw_content]).to include %(/DeviceRGB cs\n0.8 0.8 0.8 scn\n0.0 0.0 612.0 792.0 re)
  end

  describe 'unbreakable block' do
    # NOTE: only add tests that verify at top ignores unbreakable option; otherwise, put test in breakable at top
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 674.44]
      end

      it 'should split block taller than page across pages, starting from page top' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 437.17]
      end

      it 'should split block with nested block taller than page across pages, starting from page top' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        block_content = ['nested block content'] * 35 * %(\n\n)
        input = <<~EOS
        [%unbreakable]
        ====

        block content

        [%unbreakable]
        ======
        #{block_content}
        ======

        block content
        ====

        after block
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_border_cut_lines = lines
          .select {|it| it[:page_number] == 1 && it[:color] == 'FFFFFF' && it[:style] == :dashed }
          .sort_by {|it| it[:from][:x] }
        (expect p1_border_cut_lines).to have_size 2
        (expect p1_border_cut_lines[0][:from][:x]).to eql 50.5
        (expect p1_border_cut_lines[1][:from][:x]).to eql 62.5
        (expect p1_border_cut_lines[0][:from][:y]).to eql 50.0
        (expect p1_border_cut_lines[0][:from][:y]).to eql p1_border_cut_lines[1][:from][:y]
        p2_border_cut_lines = lines
          .select {|it| it[:page_number] == 2 && it[:color] == 'FFFFFF' && it[:style] == :dashed }
          .sort_by {|it| it[:from][:x] }
        (expect p2_border_cut_lines).to have_size 2
        (expect p2_border_cut_lines[0][:from][:x]).to eql 50.5
        (expect p2_border_cut_lines[1][:from][:x]).to eql 62.5
        (expect p2_border_cut_lines[0][:from][:y]).to eql 742.0
        (expect p2_border_cut_lines[0][:from][:y]).to eql p2_border_cut_lines[1][:from][:y]
      end

      it 'should split block taller than several pages across pages, starting from page top' do
        block_content = ['block content'] * 50 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 3
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end
    end

    describe 'below top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        before block

        [%unbreakable]
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 646.66]
      end

      it 'should advance block shorter than page to next page to avoid breaking' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 313.3]
      end

      it 'should advance block shorter than page and with caption to next page to avoid breaking' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_unique_text 'Example 1. block title')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'Example 1. block title')[:y]).to be > 723.009
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 294.309]
      end

      it 'should advance block shorter than page and with multiline caption to next page to avoid breaking' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        block_title = ['block title'] * 20 * ' '
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, attributes: { 'example-caption' => nil }, analyze: true
        #{before_block_content}

        .#{block_title}
        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        block_title_texts = pdf.find_text %r/block title /
        (expect block_title_texts).to have_size 2
        (expect block_title_texts[0][:page_number]).to be 2
        (expect block_title_texts[0][:y]).to be > 723.009
        (expect block_title_texts[1][:y]).to be > 708.018
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 708.018], bottom_right: [562.0, 279.318]
      end

      it 'should advance nested unbreakable block shorter than page to next page to avoid breaking', breakable: true do
        before_block_content = ['before block'] * 20 * %(\n\n)
        nested_block_content = ['nested block content'] * 5 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        before nested block

        [%unbreakable]
        ****
        #{nested_block_content}
        ****
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'before nested block')[:page_number]).to be 1
        (expect (pdf.find_text 'nested block content')[0][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])
        (expect p1_gs).to have_size 2
        (expect p1_gs[0]).to have_background color: 'FFFFCC', top_left: [50.0, 186.4], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])
        (expect p2_gs).to have_size 3
        (expect p2_gs[0]).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 579.1]
        (expect p2_gs[2]).to have_background color: 'EEEEEE', top_left: [62.0, 742.0], bottom_right: [550.0, 591.1]
      end

      it 'should advance block with only nested unbreakable block shorter than page to next page to avoid breaking', breakable: true do
        before_block_content = ['before block'] * 20 * %(\n\n)
        nested_block_content = ['nested block content'] * 5 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        [%unbreakable]
        ****
        #{nested_block_content}
        ****
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'nested block content')[0][:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])
        (expect p2_gs).to have_size 2
        (expect p2_gs[0]).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 567.1]
        (expect p2_gs[1]).to have_background color: 'EEEEEE', top_left: [62.0, 730.0], bottom_right: [550.0, 579.1]
      end

      it 'should split block taller than page across pages, starting from current position' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        before block

        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 409.39]
      end

      it 'should restart dry run on new page if first page is empty', breakable: true do
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
        pdf = with_content_spacer 10, 650 do |spacer_path|
          to_pdf <<~EOS, pdf_theme: pdf_theme, extensions: extensions, analyze: true
          image::#{spacer_path}[]

          ****
          [discrete]
          == does not fit

          [spy]
          paragraph
          ****
          EOS
        end

        (expect pdf.pages).to have_size 2
        (expect (pdf.find_unique_text 'does not fit')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'paragraph')[:page_number]).to be 2
        (expect calls).to have_size 1
        (expect (calls.join ?\n).scan '`dry_run\'').to have_size 2
      end

      it 'should restart dry run at current position once content exceeds height of first page', breakable: true do
        block_content = ['block content'] * 35 * %(\n\n)
        calls = []
        extensions = proc do
          block :spy do
            on_context :sidebar
            process do |parent, reader, attrs|
              block = create_block parent, :sidebar, reader.lines, attrs, content_model: :compound
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
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, extensions: extensions, analyze: true
        before block

        [%unbreakable]
        ====
        #{block_content}

        [spy]
        ****
        nested block content
        ****
        ====

        after block
        EOS

        (expect pdf.pages).to have_size 2
        # 1st call: to compute extent of sidebar for example block in scratch document
        # 2nd call: to render sidebar in example block in scratch document
        # 3nd call: to compute extent of sidebar in primary document
        # 4th call: (not included) to render sidebar in primary document
        (expect calls).to have_size 3
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'nested block content')[:page_number]).to be 2
      end

      it 'should not restart dry run at top of page once content exceeds height of first page', breakable: true do
        block_content = ['block content'] * 35 * %(\n\n)
        calls = []
        extensions = proc do
          block :spy do
            on_context :sidebar
            process do |parent, reader, attrs|
              block = create_block parent, :sidebar, reader.lines, attrs, content_model: :compound
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
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, extensions: extensions, analyze: true
        [%unbreakable]
        ====
        #{block_content}

        [spy]
        ****
        nested block content
        ****
        ====

        after block
        EOS

        (expect pdf.pages).to have_size 2
        # 1st call: to compute extent of sidebar for example block in scratch document
        # 2nd call: to render sidebar in example block in scratch document
        # 3nd call: to compute extent of sidebar in primary document
        # 4th call: (not included) to render sidebar in primary document
        (expect calls).to have_size 3
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'nested block content')[:page_number]).to be 2
      end

      it 'should restart dry run at current position if unbreakable block exceeds height of first page inside nested block', breakable: true do
        block_content = ['block content'] * 35 * %(\n\n)
        calls = []
        extensions = proc do
          block :spy do
            on_context :sidebar
            process do |parent, reader, attrs|
              block = create_block parent, :sidebar, reader.lines, attrs, content_model: :compound
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
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, extensions: extensions, analyze: true
        before block

        [%unbreakable]
        ====
        before nested block

        [%unbreakable]
        ======
        #{block_content}

        [spy]
        ****
        deeply nested block content
        ****
        ======
        ====

        after block
        EOS

        (expect pdf.pages).to have_size 2
        (expect calls).to have_size 7
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'deeply nested block content')[:page_number]).to be 2
      end

      it 'should restart dry run at current position if breakable content exceeds height of first page inside nested block', breakable: true do
        block_content = ['block content'] * 30 * %(\n\n)
        calls = []
        extensions = proc do
          block :spy do
            on_context :sidebar
            process do |parent, reader, attrs|
              block = create_block parent, :sidebar, reader.lines, attrs, content_model: :compound
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
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, extensions: extensions, analyze: true
        before block

        [%unbreakable]
        ====
        ======
        #{block_content}

        [spy]
        ****
        deeply nested block content
        ****
        ======
        ====

        after block
        EOS

        (expect pdf.pages).to have_size 2
        (expect calls).to have_size 7
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'deeply nested block content')[:page_number]).to be 2
      end

      it 'should advance block taller than page to next page if only caption fits on current page' do
        before_block_content = ['before block'] * 22 * %(\n\n)
        block_content = ['block content'] * 25 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ****
        filler
        ****

        #{before_block_content}

        .block title
        [%unbreakable]
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[0][:page_number]).to be 1
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to have_size 1
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end

      it 'should advance block taller than page to next page if no content fits on current page' do
        before_block_content = ['before block'] * 22 * %(\n\n)
        block_content = ['block content'] * 25 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ====
        filler
        ====

        #{before_block_content}

        .block title
        [%unbreakable]
        ****
        #{block_content}
        ****
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[0][:page_number]).to be 1
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to have_size 1
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 687.19]
      end

      it 'should preserve indentation across pages in scratch document' do
        x = Set.new
        extensions = proc do
          block :spy do
            on_context :paragraph
            process do |parent, reader, attrs|
              para = create_paragraph parent, reader.lines, attrs
              para.instance_variable_set :@_x, x
              para.extend (Module.new do
                def content
                  @_x << @document.converter.bounds.absolute_left # rubocop:disable RSpec/InstanceVariable
                  super
                end
              end)
            end
          end
        end
        pdf_theme.delete :page_margin
        pdf_theme.delete :page_size
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        input = <<~EOS
        before block

        [%unbreakable]
        ====
        example1

        [%unbreakable]
        ======
        #{['example2'] * 25 * %(\n\n)}

        [%unbreakable]
        ========
        [spy]
        #{['example3'] * 405 * ' '}
        ========
        ======
        ====
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, extensions: extensions, analyze: true
        p3_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines.select {|it| it[:page_number] == 3 }
        (expect pdf.pages).to have_size 3
        (expect x).to have_size 1
        last_text_y = (pdf.find_text %r/example3/)[-1][:y]
        last_lines_y = p3_lines
          .select {|it| it[:color] == '0000FF' && it[:from][:y] < 805 && it[:from][:y] == it[:to][:y] }
          .map {|it| it[:from][:y] }
        (expect last_lines_y).to have_size 3
        (expect last_lines_y[2] - last_lines_y[1]).to eql 12.0
        (expect last_lines_y[1] - last_lines_y[0]).to eql 12.0
        (expect last_lines_y[0]).to be < (last_text_y - 1)
      end
    end
  end

  describe 'breakable block', breakable: true do
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 674.44]
      end

      it 'should split block taller than page across pages, starting from page top' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 437.17]
      end

      it 'should split block with nested block taller than page across pages, starting from page top' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        block_content = ['nested block content'] * 35 * %(\n\n)
        input = <<~EOS
        ====

        block content

        ======
        #{block_content}
        ======

        block content
        ====

        after block
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_border_cut_lines = lines
          .select {|it| it[:page_number] == 1 && it[:color] == 'FFFFFF' && it[:style] == :dashed }
          .sort_by {|it| it[:from][:x] }
        (expect p1_border_cut_lines).to have_size 2
        (expect p1_border_cut_lines[0][:from][:x]).to eql 50.5
        (expect p1_border_cut_lines[1][:from][:x]).to eql 62.5
        (expect p1_border_cut_lines[0][:from][:y]).to eql 50.0
        (expect p1_border_cut_lines[0][:from][:y]).to eql p1_border_cut_lines[1][:from][:y]
        p2_border_cut_lines = lines
          .select {|it| it[:page_number] == 2 && it[:color] == 'FFFFFF' && it[:style] == :dashed }
          .sort_by {|it| it[:from][:x] }
        (expect p2_border_cut_lines).to have_size 2
        (expect p2_border_cut_lines[0][:from][:x]).to eql 50.5
        (expect p2_border_cut_lines[1][:from][:x]).to eql 62.5
        (expect p2_border_cut_lines[0][:from][:y]).to eql 742.0
        (expect p2_border_cut_lines[0][:from][:y]).to eql p2_border_cut_lines[1][:from][:y]
      end

      it 'should split block taller than several pages, starting from page top' do
        block_content = ['block content'] * 50 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        ====
        #{block_content}
        ====

        after block
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 3
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end

      it 'should split block across pages that contains image that does not fit in remaining space on current page' do
        block_content = ['block content'] * 10 * %(\n\n)
        input = <<~EOS
        ====
        #{block_content}

        image::tux.png[pdfwidth=100%]
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 1
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 155.88235]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 742.0
      end

      # NOTE: this scenario renders an example block that starts with an empty page
      it 'should split block across pages that contains image taller than page at start of block', negative: true do
        input = <<~'EOS'
        ====
        image::tall-spacer.png[]
        ====
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        page_width, page_height = (get_page_size pdf, 1).map(&:to_f)
        page_margin = pdf_theme[:page_margin].to_f
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql (page_height - page_margin)
        (expect image[:height]).to eql (page_height - page_margin * 2)
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [page_margin, page_height - page_margin], bottom_right: [page_width - page_margin, page_margin]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [page_margin, page_height - page_margin], bottom_right: [page_width - page_margin, page_margin]
      end

      it 'should split block across pages that contains image taller than page that follows text' do
        input = <<~'EOS'
        ====
        before image

        image::tall-spacer.png[]
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'before image')[:page_number]).to be 1
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 742.0
      end
    end

    describe 'below top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        before block

        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 646.66]
      end

      it 'should advance block shorter than page to next page if only caption fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        block_title = pdf.find_unique_text 'Example 1. block title'
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be > 723.009
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 294.309]
      end

      it 'should advance block shorter than page to next page if caption spills over page boundary' do
        block_content = ['block content'] * 15 * %(\n\n)
        block_title = ['block title'] * 15 * ' '
        pdf = with_content_spacer 10, 635 do |spacer_path|
          input = <<~EOS
          image::#{spacer_path}[]

          before block

          .#{block_title}
          ====
          #{block_content}
          ====
          EOS
          to_pdf input, pdf_theme: pdf_theme, analyze: true
        end

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        block_title = pdf.find_unique_text %r/^Example 1. block title/
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be > 708.318
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 708.018], bottom_right: [562.0, 279.318]
      end

      it 'should advance block shorter than page to next page if caption fits but advances page' do
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = with_content_spacer 10, 635 do |spacer_path|
          input = <<~EOS
          image::#{spacer_path}[]

          before block

          .block title
          ====
          #{block_content}
          ====
          EOS
          to_pdf input, pdf_theme: pdf_theme, analyze: true
        end

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        block_title = pdf.find_unique_text 'Example 1. block title'
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be > 723.009
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 294.309]
      end

      it 'should advance block shorter than page to next page if no content fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ****
        #{block_content}
        ****
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        block_title = pdf.find_unique_text 'block title'
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be < 742.0
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 284.82]
      end

      it 'should advance block taller than page to next page if only caption fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 30 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        block_title = pdf.find_unique_text 'Example 1. block title'
        (expect block_title[:page_number]).to be 2
        (expect block_title[:y]).to be > 723.009
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 50.0]
      end

      it 'should advance block taller than page to next page if no content fits on current page' do
        before_block_content = ['before block'] * 24 * %(\n\n)
        block_content = ['block content'] * 30 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ****
        #{block_content}
        ****
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'block title')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 548.29]
      end

      it 'should split block shorter than page across pages, starting from current position if it does not fit on current page' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 325.3], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 576.07]
      end

      it 'should split block taller than page across pages, starting from current position' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        #{block_content}
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 3
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 325.3], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 714.22]
      end

      it 'should split block across pages that contains image that does not fit in remaining space on current page' do
        before_block_content = ['before block'] * 5 * %(\n\n)
        block_content = ['block content'] * 5 * %(\n\n)
        input = <<~EOS
        #{before_block_content}

        ====
        #{block_content}

        image::tux.png[pdfwidth=100%]
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 1
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 603.1], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 155.88235]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 742.0
      end

      it 'should advance block that starts with image that does not fit in remaining space on current page to next page' do
        before_block_content = ['before block'] * 10 * %(\n\n)
        input = <<~EOS
        #{before_block_content}

        ====
        image::tux.png[pdfwidth=100%]

        after image
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'after image')[:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 116.10235]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 730.0
      end

      it 'should advance block with caption that starts with image that does not fit in remaining space on current page to next page' do
        before_block_content = ['before block'] * 10 * %(\n\n)
        input = <<~EOS
        #{before_block_content}

        .block title
        ====
        image::tux.png[pdfwidth=100%]

        after image
        ====
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'Example 1. block title')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'after image')[:page_number]).to be 2
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 723.009], bottom_right: [562.0, 97.11135]
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql 711.009
      end

      # NOTE: this scenario renders an example block that starts with an empty page
      it 'should split block across pages that contains image taller than page at start of block', negative: true do
        input = <<~'EOS'
        before block

        ====
        image::tall-spacer.png[]
        ====
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 3
        page_width, page_height = (get_page_size pdf, 1).map(&:to_f)
        page_margin = pdf_theme[:page_margin].to_f
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 3
        (expect image[:y]).to eql (page_height - page_margin)
        (expect image[:height]).to eql (page_height - page_margin * 2)
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [page_margin, page_height - page_margin], bottom_right: [page_width - page_margin, page_margin]
        p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
        (expect p3_gs).to have_background color: 'FFFFCC', top_left: [page_margin, page_height - page_margin], bottom_right: [page_width - page_margin, page_margin]
      end

      # FIXME: this fails when block is unbreakable
      it 'should account for top margin of discrete heading inside block with no top padding' do
        pdf_theme[:sidebar_padding] = [0, 10, 10, 10]
        pdf_theme[:sidebar_border_color] = '0000ff'
        pdf_theme[:sidebar_border_width] = 0.5
        pdf_theme[:heading_margin_top] = 50
        input = <<~'EOS'
        before

        ****
        [discrete]
        == Discrete Heading

        content
        ****
        EOS

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines

        pages = pdf.pages
        (expect pages).to have_size 1
        bottom_line_y = lines.select {|it| it[:color] == '0000FF' }.map {|it| it[:to][:y] }.min
        bottom_content_y = (pdf.find_unique_text 'content')[:y]
        (expect bottom_line_y).to be < bottom_content_y
      end

      it 'should not go haywire if caption does not fit and converter does not tare content' do
        block_title = (['long caption that wraps'] * 15).join ' '
        extensions = proc do
          tree_processor do
            process do |doc|
              doc.converter.extend TareFirstPageContentStreamNoop
              nil
            end
          end
        end
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, extensions: extensions, analyze: true
        image::tall.svg[pdfwidth=78mm]

        .#{block_title}
        ====
        content

        of

        example
        ====
        EOS

        pages = pdf.pages
        (expect pages).to have_size 2
        block_title = pdf.find_unique_text %r/^Example 1\. /
        (expect block_title[:page_number]).to be 1
        (expect (pdf.find_unique_text 'content')[:page_number]).to be 2
      end
    end
  end

  describe 'multiple' do
    it 'should arrange block after another block has been arranged' do
      before_block_content = ['before block'] * 35 * %(\n\n)
      block_content = ['block content'] * 15 * %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
      [%unbreakable]
      ====
      #{before_block_content}
      ====

      between

      [%unbreakable]
      ====
      #{block_content}
      ====
      EOS

      pages = pdf.pages
      (expect pages).to have_size 3
      (expect (pdf.find_text 'before block')[0][:page_number]).to be 1
      (expect (pdf.find_text 'before block')[-1][:page_number]).to be 2
      (expect (pdf.find_text 'block content')[0][:page_number]).to be 3
      (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
      p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
      (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
      p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
      (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 437.17]
      p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
      (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 313.3]
    end
  end

  describe 'table cell', breakable: true do
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:table_cell_padding] = 5
        block_content = ['block content'] * 3 * %(\n\n)
        input = <<~EOS
        |===
        a|
        before block

        ====
        #{block_content}
        ====

        after block
        |===
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        (expect pdf.pages).to have_size 1
        block_edges = lines.select {|it| it[:color] == '0000FF' }.each_with_object({ x: [], y: [] }) do |line, accum|
          accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
          accum[:y] = (accum[:y] << line[:from][:y] << line[:to][:y]).sort.uniq.reverse
        end
        block_edges_expected = { x: [55.0, 557.0], y: [709.22, 613.88] }
        (expect block_edges).to eql block_edges_expected
        (expect (pdf.find_unique_text 'after block')[:y]).to be < block_edges_expected[:y][1]
      end

      it 'should draw border around block extent when table cell has large padding' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:table_cell_padding] = [30, 20]
        block_content = ['block content'] * 3 * %(\n\n)
        input = <<~EOS
        |===
        a|
        before block

        ====
        #{block_content}

        ---
        ====

        after block
        |===
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        (expect pdf.pages).to have_size 1
        block_edges = lines.select {|it| it[:color] == '0000FF' }.each_with_object({ x: [], y: [] }) do |line, accum|
          accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
          accum[:y] = (accum[:y] << line[:from][:y] << line[:to][:y]).sort.uniq.reverse
        end
        block_edges_expected = { x: [70.0, 542.0], y: [684.22, 564.88] }
        thematic_break = lines.find {|it| it[:color] == 'EEEEEE' }
        (expect thematic_break[:to][:y]).to be > block_edges[:y][1]
        (expect (pdf.find_unique_text 'after block')[:y]).to be < block_edges_expected[:y][1]
        (expect block_edges).to eql block_edges_expected
      end

      it 'should truncate block taller than page within table cell' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:page_margin] = 36
        pdf_theme[:table_cell_padding] = 5
        block_content = ['block content'] * 25 * %(\n\n)
        input = <<~EOS
        |===
        a|
        table cell

        ====
        #{block_content}
        ====

        table cell
        |===
        EOS
        (expect do
          pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
          lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
          (expect pdf.pages).to have_size 1
          fragment_line = lines.find {|it| it[:color] == 'FFFFFF' && it[:to][:y] == 41.0 }
          (expect fragment_line).not_to be_nil
          (expect fragment_line[:style]).to eql :dashed
          block_edges = lines.select {|it| it[:color] == '0000FF' }.each_with_object({ x: [], y: [] }) do |line, accum|
            accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
            accum[:y] = (accum[:y] << line[:from][:y] << line[:to][:y]).sort.uniq.reverse
          end
          block_edges_expected = { x: [41.0, 571.0], y: [723.22, 41.0] }
          (expect block_edges).to eql block_edges_expected
          (expect (pdf.find_text 'block content').size).to be < 25
        end).to log_message severity: :ERROR, message: '~the table cell on page 1 has been truncated'
      end

      it 'should not convert content in table cell that overruns first page when computing height of table cell' do
        table_cell_content = ['table cell'] * 30 * %(\n\n)
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
        input = <<~EOS
        before table

        |===
        a|
        #{table_cell_content}

        [spy]
        beyond of first page
        |===
        EOS
        (expect do
          pdf = to_pdf input, pdf_theme: pdf_theme, extensions: extensions, analyze: true
          (expect pdf.pages).to have_size 2
          (expect pdf.find_text 'beyond first page').to be_empty
          (expect (pdf.find_text 'table cell')[0][:page_number]).to be 2
          (expect (pdf.find_text 'table cell')[-1][:page_number]).to be 2
          (expect calls).to be_empty
        end).to log_message severity: :ERROR, message: '~the table cell on page 2 has been truncated'
      end

      it 'should not convert content in table cell that overruns first page when computing height of table cell in scratch document' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        table_cell_content = ['table cell'] * 30 * %(\n\n)
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
        input = <<~EOS
        ====
        before table
        |===
        a|
        #{table_cell_content}

        [spy]
        beyond of first page
        |===
        ====
        EOS
        (expect do
          pdf = to_pdf input, pdf_theme: pdf_theme, extensions: extensions, analyze: true
          lines = (to_pdf input, pdf_theme: pdf_theme, extensions: extensions, analyze: :line).lines
          (expect pdf.pages).to have_size 2
          (expect pdf.find_text 'beyond first page').to be_empty
          (expect (pdf.find_text 'table cell')[0][:page_number]).to be 2
          (expect (pdf.find_text 'table cell')[-1][:page_number]).to be 2
          (expect calls).to be_empty
          p2_bottom_border_lines = lines.select do |it|
            it[:page_number] == 2 && it[:color] != '000000' && it[:from][:y] == 50.0 && it[:to][:y] == 50.0
          end
          (expect p2_bottom_border_lines).to have_size 2
          block_bottom_border_range = [p2_bottom_border_lines[0][:from][:x], p2_bottom_border_lines[0][:to][:x]].sort
          (expect block_bottom_border_range).to eql [50.0, 562.0]
          table_bottom_border_range = [p2_bottom_border_lines[1][:from][:x], p2_bottom_border_lines[1][:to][:x]].sort
          (expect table_bottom_border_range).to eql [62.0, 550.0]
        end).to log_message severity: :ERROR, message: '~the table cell on page 2 has been truncated'
      end

      it 'should scale font when computing height of block' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:example_padding] = [10, 10, 0, 10]
        pdf_theme[:prose_margin_bottom] = 10
        pdf_theme[:block_margin_bottom] = 10
        pdf_theme[:table_font_size] = 5.25
        block_content = ['block content'] * 10 * %(\n\n)
        input = <<~EOS
        |===
        a|
        ====
        #{block_content}
        ====

        table cell
        |===
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        border_bottom_y = lines
          .select {|it| it[:color] == '0000FF' }
          .reduce(Float::INFINITY) {|min, it| [min, it[:to][:y], it[:from][:y]].min }
        last_content = (pdf.find_text 'block content')[-1]
        last_content_bottom_y = last_content[:y]
        (expect border_bottom_y).to be < last_content_bottom_y
        padding_below = last_content_bottom_y - border_bottom_y
        (expect padding_below).to ((be_within 2).of 10)
        (expect (pdf.find_text 'block content')[0][:font_size]).to eql 5.25
        (expect (pdf.find_text 'table cell')[0][:font_size]).to eql 5.25
      end
    end

    describe 'below top' do
      it 'should advance table cell that contains block shorter than page but does not fit on current page' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:page_margin] = 36
        pdf_theme[:table_cell_padding] = 5
        before_table_content = ['before table'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        input = <<~EOS
        #{before_table_content}

        |===
        a|
        ====
        #{block_content}

        block content end
        ====
        |===

        after table
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        (expect pdf.pages).to have_size 2
        (expect (pdf.find_text 'before table')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'after table')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_unique_text 'block content end')[:page_number]).to be 2
        table_edges_expected = { x: [36.0, 576.0], y: [756.0, 278.0] }
        block_edges_expected = { x: [41.0, 571.0], y: [751.0, 294.52] }
        table_border_lines = lines.select {|it| it[:color] == 'DDDDDD' }
        (expect table_border_lines.map {|it| it[:page_number] }.uniq).to eql [2]
        table_edges = table_border_lines.each_with_object({ x: [], y: [] }) do |line, accum|
          accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
          from_y = (line[:from][:y].ceil - (line[:from][:y].ceil % 2)).floor.to_f
          to_y = (line[:to][:y].ceil - (line[:to][:y].ceil % 2)).floor.to_f
          accum[:y] = (accum[:y] << from_y << to_y).sort.uniq.reverse
        end
        (expect table_edges).to eql table_edges_expected
        block_border_lines = lines.select {|it| it[:color] == '0000FF' }
        (expect block_border_lines.map {|it| it[:page_number] }.uniq).to eql [2]
        block_edges = block_border_lines.each_with_object({ x: [], y: [] }) do |line, accum|
          accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
          accum[:y] = (accum[:y] << line[:from][:y] << line[:to][:y]).sort.uniq.reverse
        end
        (expect block_edges).to eql block_edges_expected
      end

      it 'should advance table cell that contains unbreakable block that does not fit on current page' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:page_margin] = 36
        pdf_theme[:table_cell_padding] = 5
        before_table_content = ['before table'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        input = <<~EOS
        #{before_table_content}

        |===
        a|
        before block

        [%unbreakable]
        ====
        #{block_content}

        block content end
        ====
        |===

        after table
        EOS
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        (expect pdf.pages).to have_size 2
        (expect (pdf.find_text 'before table')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'after table')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_unique_text 'block content end')[:page_number]).to be 2
        table_edges_expected = { x: [36.0, 576.0], y: [756.0, 250.0] }
        block_edges_expected = { x: [41.0, 571.0], y: [723.22, 266.74] }
        table_border_lines = lines.select {|it| it[:color] == 'DDDDDD' }
        (expect table_border_lines.map {|it| it[:page_number] }.uniq).to eql [2]
        table_edges = table_border_lines.each_with_object({ x: [], y: [] }) do |line, accum|
          accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
          from_y = (line[:from][:y].ceil - (line[:from][:y].ceil % 2)).floor.to_f
          to_y = (line[:to][:y].ceil - (line[:to][:y].ceil % 2)).floor.to_f
          accum[:y] = (accum[:y] << from_y << to_y).sort.uniq.reverse
        end
        (expect table_edges).to eql table_edges_expected
        block_border_lines = lines.select {|it| it[:color] == '0000FF' }
        (expect block_border_lines.map {|it| it[:page_number] }.uniq).to eql [2]
        block_edges = block_border_lines.each_with_object({ x: [], y: [] }) do |line, accum|
          accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
          accum[:y] = (accum[:y] << line[:from][:y] << line[:to][:y]).sort.uniq.reverse
        end
        (expect block_edges).to eql block_edges_expected
      end

      it 'should advance table cell and truncate child block taller than page' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:page_margin] = 36
        pdf_theme[:table_cell_padding] = 5
        before_table_content = ['before table'] * 15 * %(\n\n)
        block_content = ['block content'] * 25 * %(\n\n)
        input = <<~EOS
        #{before_table_content}

        |===
        a|
        ====
        #{block_content}

        block content end
        ====
        |===

        after table
        EOS
        (expect do
          pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
          lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
          (expect pdf.pages).to have_size 3
          (expect (pdf.find_text 'before table')[-1][:page_number]).to be 1
          (expect (pdf.find_unique_text 'after table')[:page_number]).to be 3
          (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
          (expect (pdf.find_unique_text 'block content end')).to be_nil
          table_edges_expected = { x: [36.0, 576.0], y: [756.0, 36.0] }
          block_edges_expected = { x: [41.0, 571.0], y: [751.0, 41.0] }
          table_border_lines = lines.select {|it| it[:color] == 'DDDDDD' }
          (expect table_border_lines.map {|it| it[:page_number] }.uniq).to eql [2]
          table_edges = table_border_lines.each_with_object({ x: [], y: [] }) do |line, accum|
            accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
            from_y = (line[:from][:y].ceil - (line[:from][:y].ceil % 2)).floor.to_f
            to_y = (line[:to][:y].ceil - (line[:to][:y].ceil % 2)).floor.to_f
            accum[:y] = (accum[:y] << from_y << to_y).sort.uniq.reverse
          end
          (expect table_edges).to eql table_edges_expected
          block_border_lines = lines.select {|it| it[:color] == '0000FF' }
          (expect block_border_lines.map {|it| it[:page_number] }.uniq).to eql [2]
          block_edges = block_border_lines.each_with_object({ x: [], y: [] }) do |line, accum|
            accum[:x] = (accum[:x] << line[:from][:x] << line[:to][:x]).sort.uniq
            accum[:y] = (accum[:y] << line[:from][:y] << line[:to][:y]).sort.uniq.reverse
          end
          (expect block_edges).to eql block_edges_expected
          fragment_line = lines.find {|it| it[:color] == 'FFFFFF' && it[:to][:y] == 41.0 }
          (expect fragment_line).not_to be_nil
          (expect fragment_line[:style]).to eql :dashed
        end).to log_message severity: :ERROR, message: '~the table cell on page 2 has been truncated'
      end
    end
  end

  describe 'anchor' do
    it 'should keep anchor with unbreakable block that is advanced to new page' do
      before_block_content = ['before block'] * 15 * %(\n\n)
      block_content = ['block content'] * 15 * %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: pdf_theme
      #{before_block_content}

      [#block-id%unbreakable]
      ====
      #{block_content}
      ====
      EOS

      pages = pdf.pages
      (expect (pages[0].text.split %r/\n+/).uniq.compact).to eql ['before block']
      (expect (pages[1].text.split %r/\n+/).uniq.compact).to eql ['block content']
      (expect pages).to have_size 2
      dest = get_dest pdf, 'block-id'
      (expect dest[:page_number]).to be 2
      (expect dest[:y].to_f).to eql 742.0
    end

    it 'should keep anchor with breakable block that is advanced to next page' do
      before_block_content = ['before block'] * 24 * %(\n\n)
      block_content = ['block content'] * 15 * %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: pdf_theme
      #{before_block_content}

      .block title
      [#block-id]
      ====
      #{block_content}
      ====
      EOS

      pages = pdf.pages
      (expect pages).to have_size 2
      dest = get_dest pdf, 'block-id'
      (expect dest[:page_number]).to be 2
      (expect dest[:y].to_f).to eql 742.0
    end
  end
end
