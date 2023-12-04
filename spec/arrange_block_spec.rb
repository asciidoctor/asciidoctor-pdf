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
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    before block

    ====
    ====

    after block
    END

    pages = pdf.pages
    (expect pages).to have_size 1
    (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
    (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
    gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
    # NOTE: height is equivalent to top + bottom padding
    (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 690.22]
  end

  it 'should not draw backgrounds and borders in scratch document' do
    pdf_theme[:sidebar_border_color] = '222222'
    pdf_theme[:sidebar_border_width] = 0.5
    input = <<~'END'
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
    END
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
    scratch_pdf = (TextInspector.analyze scratch_pdf_output)
    (expect (scratch_pdf.extract_graphic_states scratch_pdf.pages[0][:raw_content])).to be_empty
    scratch_pdf_lines = (LineInspector.analyze scratch_pdf_output).lines
    (expect scratch_pdf_lines).to be_empty
  end

  it 'should invoke on_page_create if set on scratch document' do
    with_content_spacer 200, 600, fill: '#008000' do |spacer_path|
      input = <<~END
      scratch_background_color:CCCCCC[]

      image::#{spacer_path}[pdfwidth=70mm]

      ====
      content

      of

      block
      ====
      END
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
      scratch_pdf = (TextInspector.analyze scratch_pdf_output)
      (expect scratch_pdf.pages[0][:raw_content]).to include %(/DeviceRGB cs\n0.8 0.8 0.8 scn\n0.0 0.0 612.0 792.0 re)
    end
  end

  it 'should not add bottom margin to last block or styled paragraph in enclosure that supports blocks' do
    pdf_theme = {
      sidebar_background_color: 'transparent',
      admonition_border_color: 'EEEEEE',
      admonition_border_width: 0.5,
      admonition_padding: 12,
      quote_border_width: 0.5,
      quote_border_left_width: 0,
      quote_font_size: 10.5,
      quote_padding: 12,
      code_padding: 12,
    }
    %w(==== **** ____ ---- .... [NOTE]==== example sidebar quote NOTE).each do |style|
      block_lines = []
      if style.start_with? '['
        delim = (style.split ']', 2)[1]
        block_lines << %([#{style.slice 1, (style.index ']') - 1}])
        block_lines << delim
        block_lines << 'content'
        block_lines << delim
      elsif /\p{Alpha}/ =~ style.chr
        block_lines << %([#{style}])
        block_lines << 'content'
      else
        block_lines << style
        block_lines << 'content'
        block_lines << style
      end
      input = <<~END
      ******
      #{block_lines * ?\n}
      ******
      END

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
      (expect horizontal_lines[-2][:from][:y] - horizontal_lines[-1][:from][:y]).to eql 12.0
      (expect (pdf.find_unique_text 'content')[:y] - horizontal_lines[-2][:from][:y]).to (be_within 1).of 15.0
    end
  end

  it 'should compute extent of block correctly when indent is applied to section body' do
    pdf_theme[:section_indent] = 36
    pdf = with_content_spacer 10, 650 do |spacer_path|
      to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      == Section Title

      image::#{spacer_path}[]

      ****
      This is a sidebar block.

      It has a shaded background and a subtle border, which are added by the default theme.

      It contains this very long sentence, which causes the block to become split across two pages.
      ****
      END
    end

    pages = pdf.pages
    (expect pages).to have_size 2
    last_text = pdf.text[-1]
    (expect last_text[:page_number]).to eql 2
    (expect last_text[:string]).to eql 'two pages.'
    gs_p2 = (pdf.extract_graphic_states pages[1][:raw_content])[0]
    (expect gs_p2).to have_background color: 'EEEEEE', top_left: [86.0, 742.0], bottom_right: [526.0, 615.1]
    bottom_padding = last_text[:y] - 615.1
    (expect bottom_padding).to (be_within 1).of 15.0
  end

  describe 'unbreakable block' do
    # NOTE: only add tests that verify at top ignores unbreakable option; otherwise, put test in breakable at top
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====

        after block
        END

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 674.44]
      end

      it 'should split block taller than page across pages, starting from page top' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        END

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 436.42]
      end

      it 'should split block with nested block taller than page across pages, starting from page top' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        block_content = ['nested block content'] * 35 * %(\n\n)
        input = <<~END
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
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        END

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
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        before block

        [%unbreakable]
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        [%unbreakable]
        ====
        #{block_content}
        ====
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        [%unbreakable]
        ====
        #{block_content}
        ====
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, attributes: { 'example-caption' => nil }, analyze: true
        #{before_block_content}

        .#{block_title}
        [%unbreakable]
        ====
        #{block_content}
        ====
        END

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

      it 'should advance nested unbreakable block shorter than page to next page to avoid breaking' do
        before_block_content = ['before block'] * 20 * %(\n\n)
        nested_block_content = ['nested block content'] * 5 * %(\n\n)
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        before nested block

        [%unbreakable]
        ****
        #{nested_block_content}
        ****
        ====
        END

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

      it 'should advance block with only nested unbreakable block shorter than page to next page to avoid breaking' do
        before_block_content = ['before block'] * 20 * %(\n\n)
        nested_block_content = ['nested block content'] * 5 * %(\n\n)
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        [%unbreakable]
        ****
        #{nested_block_content}
        ****
        ====
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        before block

        [%unbreakable]
        ====
        #{block_content}
        ====

        after block
        END

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 714.22], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 408.64]
      end

      it 'should restart dry run on new page if first page is empty' do
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
          to_pdf <<~END, pdf_theme: pdf_theme, extensions: extensions, analyze: true
          image::#{spacer_path}[]

          ****
          [discrete]
          == does not fit

          [spy]
          paragraph
          ****
          END
        end

        (expect pdf.pages).to have_size 2
        (expect (pdf.find_unique_text 'does not fit')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'paragraph')[:page_number]).to be 2
        (expect calls).to have_size 1
        (expect (calls.join ?\n).scan '`dry_run\'').to have_size 2
      end

      it 'should restart dry run at current position once content exceeds height of first page' do
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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, extensions: extensions, analyze: true
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
        END

        (expect pdf.pages).to have_size 2
        # 1st call: to compute extent of sidebar for example block in scratch document
        # 2nd call: to render sidebar in example block in scratch document
        # 3nd call: to compute extent of sidebar in primary document
        # 4th call: (not included) to render sidebar in primary document
        (expect calls).to have_size 3
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'nested block content')[:page_number]).to be 2
      end

      it 'should not restart dry run at top of page once content exceeds height of first page' do
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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, extensions: extensions, analyze: true
        [%unbreakable]
        ====
        #{block_content}

        [spy]
        ****
        nested block content
        ****
        ====

        after block
        END

        (expect pdf.pages).to have_size 2
        # 1st call: to compute extent of sidebar for example block in scratch document
        # 2nd call: to render sidebar in example block in scratch document
        # 3nd call: to compute extent of sidebar in primary document
        # 4th call: (not included) to render sidebar in primary document
        (expect calls).to have_size 3
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'nested block content')[:page_number]).to be 2
      end

      it 'should restart dry run at current position if unbreakable block exceeds height of first page inside nested block' do
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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, extensions: extensions, analyze: true
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
        END

        (expect pdf.pages).to have_size 2
        (expect calls).to have_size 7
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'deeply nested block content')[:page_number]).to be 2
      end

      it 'should restart dry run at current position if breakable content exceeds height of first page inside nested block' do
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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, extensions: extensions, analyze: true
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
        END

        (expect pdf.pages).to have_size 2
        (expect calls).to have_size 7
        (expect (calls.join ?\n)).not_to include '`perform_on_single_page\''
        (expect (pdf.find_unique_text 'deeply nested block content')[:page_number]).to be 2
      end

      it 'should advance block taller than page to next page if only caption fits on current page' do
        before_block_content = ['before block'] * 22 * %(\n\n)
        block_content = ['block content'] * 25 * %(\n\n)
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        ****
        filler
        ****

        #{before_block_content}

        .block title
        [%unbreakable]
        ====
        #{block_content}
        ====
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        ====
        filler
        ====

        #{before_block_content}

        .block title
        [%unbreakable]
        ****
        #{block_content}
        ****
        END

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
        (expect p3_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 686.44]
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
        input = <<~END
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
        END
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

  describe 'breakable block' do
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====

        after block
        END

        pages = pdf.pages
        (expect pages).to have_size 1
        (expect (pdf.find_unique_text %r/^This block fits /)[:page_number]).to be 1
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 674.44]
      end

      it 'should split block taller than page across pages, starting from page top' do
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        ====
        #{block_content}
        ====

        after block
        END

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_unique_text 'after block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 436.42]
      end

      it 'should split block with nested block taller than page across pages, starting from page top' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        block_content = ['nested block content'] * 35 * %(\n\n)
        input = <<~END
        ====

        block content

        ======
        #{block_content}
        ======

        block content
        ====

        after block
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        ====
        #{block_content}
        ====

        after block
        END

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
        input = <<~END
        ====
        #{block_content}

        image::tux.png[pdfwidth=100%]
        ====
        END

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

      it 'should split block across pages that contains image taller than page at start of block' do
        input = <<~'END'
        ====
        image::tall-spacer.png[]
        ====
        END
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 1
        page_width, page_height = (get_page_size pdf, 1).map(&:to_f)
        page_margin = pdf_theme[:page_margin].to_f
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 1
        (expect image[:y]).to eql (page_height - page_margin - 12)
        (expect image[:height]).to eql (page_height - 12 - page_margin * 2)
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [page_margin, page_height - page_margin], bottom_right: [page_width - page_margin, page_margin]
      end

      it 'should split block across pages that contains image taller than page that follows text' do
        input = <<~'END'
        ====
        before image

        image::tall-spacer.png[]
        ====
        END

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

      it 'should split block across pages that starts at top of rotated page' do
        pdf_theme.update \
          code_border_width: [1, 0],
          code_border_color: '0000FF',
          code_border_radius: 0,
          code_background_color: 'transparent'
        block_content = ['block content with very long lines that do not wrap because the page layout is rotated to landscape'] * 20 * %(\n\n)
        input = <<~END
        first page

        [page-layout=landscape]
        <<<

        ....
        #{block_content}
        ....
        END

        block_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines.select {|it| it[:color] == '0000FF' }
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        (expect pdf.pages).to have_size 3
        block_text = pdf.find_text %r/very long lines/
        (expect block_lines[0][:from][:y]).to eql (pdf.pages[1][:size][1] - 50).to_f
        (expect block_lines[0][:page_number]).to eql 2
        (expect block_lines[0][:from][:y]).to be > block_text[0][:y]
        (expect (block_lines[0][:from][:y] - (block_text[0][:y] + block_text[0][:font_size]))).to be < 12
        (expect block_lines[-1][:page_number]).to eql 3
        (expect block_lines[-1][:from][:y]).to be < block_text[-1][:y]
        (expect block_text[-1][:y] - block_lines[-1][:from][:y]).to be < 14
      end

      it 'should split block across pages that starts at top of rotated page with different margin' do
        pdf_theme.update \
          code_border_width: [1, 0],
          code_border_color: '0000FF',
          code_border_radius: 0,
          code_background_color: 'transparent',
          page_margin_rotated: 10
        block_content = ['block content with very long lines that do not wrap because the page layout is rotated to landscape'] * 20 * %(\n\n)
        input = <<~END
        first page

        [page-layout=landscape]
        <<<

        ....
        #{block_content}
        ....
        END

        block_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines.select {|it| it[:color] == '0000FF' }
        top_line = block_lines[0]
        bottom_line = block_lines[-1]
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        (expect pdf.pages).to have_size 3
        block_text = pdf.find_text %r/very long lines/
        (expect top_line[:page_number]).to eql 2
        (expect top_line[:from][:x]).to eql 10.0
        (expect top_line[:to][:x]).to eql (pdf.pages[1][:size][0] - 10).to_f
        (expect top_line[:from][:y]).to eql (pdf.pages[1][:size][1] - 10).to_f
        (expect top_line[:from][:y]).to be > block_text[0][:y]
        (expect (top_line[:from][:y] - (block_text[0][:y] + block_text[0][:font_size]))).to be < 12
        (expect bottom_line[:page_number]).to eql 3
        (expect bottom_line[:from][:y]).to be < block_text[-1][:y]
        (expect block_text[-1][:y] - bottom_line[:from][:y]).to be < 14
      end
    end

    describe 'below top' do
      it 'should keep block on current page if it fits' do
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        before block

        ====
        This block fits in the remaining space on the page.

        Therefore, it will not be split or moved to the following page.
        ====
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ====
        #{block_content}
        ====
        END

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
          input = <<~END
          image::#{spacer_path}[]

          before block

          .#{block_title}
          ====
          #{block_content}
          ====
          END
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
          input = <<~END
          image::#{spacer_path}[]

          before block

          .block title
          ====
          #{block_content}
          ====
          END
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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ****
        #{block_content}
        ****
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ====
        #{block_content}
        ====
        END

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
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        .block title
        ****
        #{block_content}
        ****
        END

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
        (expect p3_gs).to have_background color: 'EEEEEE', top_left: [50.0, 742.0], bottom_right: [562.0, 547.54]
      end

      it 'should split block shorter than page across pages, starting from current position if it does not fit on current page' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 15 * %(\n\n)
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        #{block_content}
        ====
        END

        pages = pdf.pages
        (expect pages).to have_size 2
        (expect (pdf.find_text 'before block')[-1][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 1
        (expect (pdf.find_text 'block content')[-1][:page_number]).to be 2
        p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
        (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 325.3], bottom_right: [562.0, 50.0]
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 575.32]
      end

      it 'should split block taller than page across pages, starting from current position' do
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content'] * 35 * %(\n\n)
        pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
        #{before_block_content}

        ====
        #{block_content}
        ====
        END

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
        input = <<~END
        #{before_block_content}

        ====
        #{block_content}

        image::tux.png[pdfwidth=100%]
        ====
        END

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
        input = <<~END
        #{before_block_content}

        ====
        image::tux.png[pdfwidth=100%]

        after image
        ====
        END

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
        input = <<~END
        #{before_block_content}

        .block title
        ====
        image::tux.png[pdfwidth=100%]

        after image
        ====
        END

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

      it 'should split block across pages that contains image taller than page at start of block' do
        input = <<~'END'
        before block

        ====
        image::tall-spacer.png[]
        ====
        END
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
        pages = pdf.pages
        (expect pages).to have_size 2
        page_width, page_height = (get_page_size pdf, 1).map(&:to_f)
        page_margin = pdf_theme[:page_margin].to_f
        (expect images).to have_size 1
        image = images[0]
        (expect image[:page_number]).to be 2
        (expect image[:y]).to eql (page_height - page_margin - 12)
        (expect image[:height]).to eql (page_height - 12 - page_margin * 2)
        (expect (pdf.extract_graphic_states pages[0][:raw_content])).to be_empty
        p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
        (expect p2_gs).to have_background color: 'FFFFCC', top_left: [page_margin, page_height - page_margin], bottom_right: [page_width - page_margin, page_margin]
      end

      # FIXME: this fails when block is unbreakable
      it 'should account for top margin of discrete heading inside block with no top padding' do
        pdf_theme[:sidebar_padding] = [0, 10, 10, 10]
        pdf_theme[:sidebar_border_color] = '0000ff'
        pdf_theme[:sidebar_border_width] = 0.5
        pdf_theme[:heading_margin_top] = 50
        input = <<~'END'
        before

        ****
        [discrete]
        == Discrete Heading

        content
        ****
        END

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines

        pages = pdf.pages
        (expect pages).to have_size 1
        bottom_line_y = lines.select {|it| it[:color] == '0000FF' }.map {|it| it[:to][:y] }.min
        bottom_content_y = (pdf.find_unique_text 'content')[:y]
        (expect bottom_line_y).to be < bottom_content_y
      end

      it 'should not go haywire if caption does not fit and converter does not tare content' do
        with_content_spacer 200, 600 do |spacer_path|
          block_title = (['long caption that wraps'] * 15).join ' '
          extensions = proc do
            tree_processor do
              process do |doc|
                doc.converter.extend RSpec::ExampleGroupHelpers::TareFirstPageContentStreamNoop
                nil
              end
            end
          end
          pdf = to_pdf <<~END, pdf_theme: pdf_theme, extensions: extensions, analyze: true
          image::#{spacer_path}[pdfwidth=78mm]

          .#{block_title}
          ====
          content

          of

          example
          ====
          END

          pages = pdf.pages
          (expect pages).to have_size 2
          block_title = pdf.find_unique_text %r/^Example 1\. /
          (expect block_title[:page_number]).to be 1
          (expect (pdf.find_unique_text 'content')[:page_number]).to be 2
        end
      end

      it 'should split block across pages that starts partway down rotated page' do
        pdf_theme.update \
          code_border_width: [1, 0],
          code_border_color: '0000FF',
          code_border_radius: 0,
          code_background_color: 'transparent'
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content with very long lines that do not wrap because the page layout is rotated to landscape'] * 15 * %(\n\n)
        input = <<~END
        first page

        [page-layout=landscape]
        <<<

        #{before_block_content}

        ....
        #{block_content}
        ....
        END

        block_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines.select {|it| it[:color] == '0000FF' }
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        (expect pdf.pages).to have_size 3
        block_text = pdf.find_text %r/very long lines/
        (expect block_lines[0][:page_number]).to eql 2
        (expect block_lines[0][:from][:y]).to be > block_text[0][:y]
        (expect (block_lines[0][:from][:y] - (block_text[0][:y] + block_text[0][:font_size]))).to be < 12
        (expect block_lines[-1][:page_number]).to eql 3
        (expect block_lines[-1][:from][:y]).to be < block_text[-1][:y]
        (expect block_text[-1][:y] - block_lines[-1][:from][:y]).to be < 14
      end

      it 'should restore page layout in scratch document after it has been toggled in main document' do
        pdf_theme.update \
          code_border_width: [1, 0],
          code_border_color: '0000FF',
          code_border_radius: 0,
          code_background_color: 'transparent'
        before_block_content = ['before block'] * 15 * %(\n\n)
        block_content = ['block content with very long lines that wrap because the page layout is not rotated to landscape'] * 15 * %(\n\n)
        input = <<~END
        first page

        [page-layout=landscape]
        <<<

        rotated page

        [page-layout=portrait]
        <<<

        #{before_block_content}

        ....
        #{block_content}
        ....
        END

        block_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines.select {|it| it[:color] == '0000FF' }
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        (expect pdf.pages).to have_size 4
        block_text = pdf.find_text %r/very long lines/
        (expect block_lines[0][:page_number]).to eql 3
        (expect block_lines[0][:from][:y]).to be > block_text[0][:y]
        (expect (block_lines[0][:from][:y] - (block_text[0][:y] + block_text[0][:font_size]))).to be < 12
        block_text = pdf.find_text %r/landscape/
        (expect block_lines[-1][:page_number]).to eql 4
        (expect block_lines[-1][:from][:y]).to be < block_text[-1][:y]
        (expect block_text[-1][:y] - block_lines[-1][:from][:y]).to be < 14
      end
    end
  end

  describe 'multiple' do
    it 'should arrange block after another block has been arranged' do
      before_block_content = ['before block'] * 35 * %(\n\n)
      block_content = ['block content'] * 15 * %(\n\n)
      pdf = to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      [%unbreakable]
      ====
      #{before_block_content}
      ====

      between

      [%unbreakable]
      ====
      #{block_content}
      ====
      END

      pages = pdf.pages
      (expect pages).to have_size 3
      (expect (pdf.find_text 'before block')[0][:page_number]).to be 1
      (expect (pdf.find_text 'before block')[-1][:page_number]).to be 2
      (expect (pdf.find_text 'block content')[0][:page_number]).to be 3
      (expect (pdf.find_text 'block content')[-1][:page_number]).to be 3
      p1_gs = (pdf.extract_graphic_states pages[0][:raw_content])[0]
      (expect p1_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 50.0]
      p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
      (expect p2_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 436.42]
      p3_gs = (pdf.extract_graphic_states pages[2][:raw_content])[0]
      (expect p3_gs).to have_background color: 'FFFFCC', top_left: [50.0, 742.0], bottom_right: [562.0, 313.3]
    end
  end

  describe 'table cell' do
    describe 'at top' do
      it 'should keep block on current page if it fits' do
        pdf_theme[:example_border_width] = 0.5
        pdf_theme[:example_border_color] = '0000ff'
        pdf_theme[:example_background_color] = 'ffffff'
        pdf_theme[:table_cell_padding] = 5
        block_content = ['block content'] * 3 * %(\n\n)
        input = <<~END
        |===
        a|
        before block

        ====
        #{block_content}
        ====

        after block
        |===
        END
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
        input = <<~END
        |===
        a|
        before block

        ====
        #{block_content}

        ---
        ====

        after block
        |===
        END
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
        input = <<~END
        |===
        a|
        table cell

        ====
        #{block_content}
        ====

        table cell
        |===
        END
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
        input = <<~END
        before table

        |===
        a|
        #{table_cell_content}

        [spy]
        beyond of first page
        |===
        END
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
        input = <<~END
        ====
        before table
        |===
        a|
        #{table_cell_content}

        [spy]
        beyond of first page
        |===
        ====
        END
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
        input = <<~END
        |===
        a|
        ====
        #{block_content}
        ====

        table cell
        |===
        END
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        border_bottom_y = lines
          .select {|it| it[:color] == '0000FF' }
          .reduce(Float::INFINITY) {|min, it| [min, it[:to][:y], it[:from][:y]].min }
        last_content = (pdf.find_text 'block content')[-1]
        last_content_bottom_y = last_content[:y]
        (expect border_bottom_y).to be < last_content_bottom_y
        padding_below = last_content_bottom_y - border_bottom_y
        (expect padding_below).to be < 2
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
        input = <<~END
        #{before_table_content}

        |===
        a|
        ====
        #{block_content}

        block content end
        ====
        |===

        after table
        END
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        (expect pdf.pages).to have_size 2
        (expect (pdf.find_text 'before table')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'after table')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_unique_text 'block content end')[:page_number]).to be 2
        table_edges_expected = { x: [36.0, 576.0], y: [756.0, 290.0] }
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
        input = <<~END
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
        END
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        (expect pdf.pages).to have_size 2
        (expect (pdf.find_text 'before table')[-1][:page_number]).to be 1
        (expect (pdf.find_unique_text 'after table')[:page_number]).to be 2
        (expect (pdf.find_unique_text 'before block')[:page_number]).to be 2
        (expect (pdf.find_text 'block content')[0][:page_number]).to be 2
        (expect (pdf.find_unique_text 'block content end')[:page_number]).to be 2
        table_edges_expected = { x: [36.0, 576.0], y: [756.0, 262.0] }
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
        input = <<~END
        #{before_table_content}

        |===
        a|
        ====
        #{block_content}

        block content end
        ====
        |===

        after table
        END
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
      pdf = to_pdf <<~END, pdf_theme: pdf_theme
      #{before_block_content}

      [#block-id%unbreakable]
      ====
      #{block_content}
      ====
      END

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
      pdf = to_pdf <<~END, pdf_theme: pdf_theme
      #{before_block_content}

      .block title
      [#block-id]
      ====
      #{block_content}
      ====
      END

      pages = pdf.pages
      (expect pages).to have_size 2
      dest = get_dest pdf, 'block-id'
      (expect dest[:page_number]).to be 2
      (expect dest[:y].to_f).to eql 742.0
    end
  end

  describe 'column box' do
    it 'should compute extent for block based on correct width' do
      pdf_theme[:code_border_radius] = 0
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def traverse node
          return super unless node.context == :document
          column_box [0, cursor], columns: 2, width: bounds.width, reflow_margins: true, spacer: 12 do
            super
          end
        end
      end
      input = <<~'END'
      ....
      $ gem install asciidoctor-pdf asciidoctor-mathematical
      $ asciidoctor-pdf -r asciidoctor-mathematical -a mathematical-format=svg sample.adoc
      ....
      END
      lines = (to_pdf input, backend: backend, pdf_theme: pdf_theme, analyze: :line).lines
      pdf = to_pdf input, backend: backend, pdf_theme: pdf_theme, analyze: true
      last_line_y = lines.select {|it| it[:from][:y] == it[:to][:y] }.map {|it| it[:from][:y] }.min
      last_text = pdf.text[-1]
      (expect last_text[:y]).to be > last_line_y
    end

    it 'should fill extent when block is advanced to next column' do
      pdf_theme.update \
        page_columns: 2,
        page_column_gap: 12,
        code_border_radius: 0,
        code_border_width: 0,
        code_background_color: 'EFEFEF'

      pdf = with_content_spacer 10, 675 do |spacer_path|
        input = <<~END
        image::#{spacer_path}[]

        ....
        $ gem install asciidoctor-pdf asciidoctor-mathematical
        $ asciidoctor-pdf -r asciidoctor-mathematical -a mathematical-format=svg sample.adoc
        ....
        END
        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        pages = pdf.pages
        (expect pages).to have_size 1
        gs = (pdf.extract_graphic_states pages[0][:raw_content])[1]
        (expect gs).to have_background color: 'EFEFEF', top_left: [312.0, 742.0], bottom_right: [562.0, 646.3]
      end
    end

    it 'should correctly compute to cursor value on extent when column_box starts below top of page' do
      pdf_theme.update page_columns: 2, page_column_gap: 12, admonition_column_rule_color: '0000FF'

      pdf = with_content_spacer 10, 400 do |spacer_path|
        input = <<~END
        = Document Title
        :toc:

        image::#{spacer_path}[]

        == Section Title

        [NOTE]
        ====
        #{lorem_ipsum '4-sentences-2-paragraphs'}
        ====
        END

        pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
        pages = pdf.pages
        (expect pages).to have_size 1
        lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        column_rules = lines.select {|it| it[:color] == '0000FF' }
        (expect column_rules).to have_size 2
        (expect column_rules[0][:from][:x]).to be < column_rules[1][:from][:x]
        expected_y = (lines - column_rules).max_by {|it| it[:from][:y] }[:from][:y]
        (expect column_rules[1][:from][:y]).to eql expected_y
      end
    end
  end

  # NOTE: generate reference files using ./scripts/generate-arrange-block-reference-files.sh
  describe 'acceptance', if: ENV['COVERAGE'], visual: true do
    it 'at top, fits' do
      to_file = to_pdf_file (Pathname.new (fixture_file 'arrange-block-at-top-fits.adoc')),
        'arrange-block-at-top-fits.pdf', attribute_overrides: { 'source-highlighter' => 'rouge' }
      (expect to_file).to visually_match 'arrange-block-at-top-fits.pdf'
    end

    it 'at top, does not fit' do
      (expect do
        to_file = to_pdf_file (Pathname.new (fixture_file 'arrange-block-at-top-does-not-fit.adoc')),
          'arrange-block-at-top-does-not-fit.pdf', attribute_overrides: { 'source-highlighter' => 'rouge' }
        (expect to_file).to visually_match 'arrange-block-at-top-does-not-fit.pdf'
      end).to log_message severity: :ERROR, message: /the table cell on page \d+ has been truncated/
    end

    it 'below top, fits' do
      to_file = to_pdf_file (Pathname.new (fixture_file 'arrange-block-below-top-fits.adoc')),
        'arrange-block-below-top-fits.pdf', attribute_overrides: { 'source-highlighter' => 'rouge' }
      (expect to_file).to visually_match 'arrange-block-below-top-fits.pdf'
    end

    it 'below top, does not fit' do
      to_file = to_pdf_file (Pathname.new (fixture_file 'arrange-block-below-top-does-not-fit.adoc')),
        'arrange-block-below-top-does-not-fit.pdf', attribute_overrides: { 'source-highlighter' => 'rouge' }
      (expect to_file).to visually_match 'arrange-block-below-top-does-not-fit.pdf'
    end

    it 'below top, does not fit, media=prepress' do
      to_file = to_pdf_file (Pathname.new (fixture_file 'arrange-block-below-top-does-not-fit.adoc')),
        'arrange-block-below-top-does-not-fit.pdf',
        attribute_overrides: { 'source-highlighter' => 'rouge', 'media' => 'prepress', 'pdf-theme' => 'default', 'doctype' => 'book' }
      (expect to_file).to visually_match 'arrange-block-below-top-does-not-fit-prepress.pdf'
    end
  end
end
