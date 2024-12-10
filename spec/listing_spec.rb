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
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    ----
    ----
    END

    lines = pdf.lines
    (expect lines).to have_size 4
    (expect lines[1][:from][:y] - lines[1][:to][:y]).to be <= 1
  end

  it 'should wrap text consistently regardless of whether the characters contain diacritics' do
    pdf = to_pdf <<~'END', analyze: true
    :pdf-page-size: A5

    ....
    aàbècìdòeùf gáhéiíjókúlým nâoêpîqôrûs tñuõvãw xäyëzïaöbücÿd
    aabbccddeef gghhiijjkkllm nnooppqqrrs ttuuvvw xxyyzzaabbccd
    ....
    END

    text = pdf.text
    (expect text).to have_size 4
    (expect text[1][:string]).to start_with 'x'
    (expect text[3][:string]).to start_with 'x'
  end

  it 'should move unbreakable block shorter than page to next page to avoid splitting it' do
    pdf = to_pdf <<~END, analyze: true
    #{(['paragraph'] * 20).join (?\n * 2)}

    [%unbreakable]
    ----
    #{(['listing'] * 20).join ?\n}
    ----
    END

    listing_page_numbers = (pdf.find_text 'listing').map {|it| it[:page_number] }.uniq
    (expect listing_page_numbers).to eql [2]
  end

  it 'should not split block that has less lines than breakable_min_lines value' do
    pdf = with_content_spacer 10, 700 do |spacer_path|
      to_pdf <<~END, pdf_theme: { code_border_color: 'FF0000', code_breakable_min_lines: 3 }, analyze: :line
      image::#{spacer_path}[]

      ----
      not
      breakable
      ----
      END
    end

    lines = pdf.lines.select {|it| it[:color] == 'FF0000' }
    (expect lines.map {|it| it[:page_number] }.uniq).to eql [2]
  end

  it 'should advance block to next page if remaining height is less than code_orphans_min_height' do
    pdf_theme = {
      code_orphans_min_height: 72,
      code_border_color: 'FF0000',
    }
    pdf = with_content_spacer 10, 700 do |spacer_path|
      input = <<~END
      image::#{spacer_path}[]

      ----
      this
      code
      will
      not
      break
      ----
      END

      (expect ((to_pdf input, analyze: true).find_unique_text 'this')[:page_number]).to eql 1
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      (expect pdf.pages).to have_size 2
      (expect (pdf.find_unique_text 'this')[:page_number]).to eql 2
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      code_border = pdf.lines.select {|it| it[:color] == 'FF0000' }
      (expect code_border.map {|it| it[:page_number] }.uniq).to eql [2]
    end
  end

  it 'should keep anchor together with block when block is moved to next page' do
    pdf = to_pdf <<~END
    #{(['paragraph'] * 20).join (?\n * 2)}

    [#listing-1%unbreakable]
    ----
    #{(['listing'] * 20).join ?\n}
    ----
    END

    (expect (pdf.page 1).text).not_to include 'listing'
    (expect (pdf.page 2).text).to include 'listing'
    (expect (dest = get_dest pdf, 'listing-1')).not_to be_nil
    (expect dest[:page_number]).to be 2
    (expect dest[:y]).to eql 805.89
  end

  it 'should place anchor directly at top of block' do
    input = <<~'END'
    paragraph

    [#listing-1]
    ----
    listing
    ----
    END

    lines = (to_pdf input, analyze: :line).lines
    pdf = to_pdf input
    (expect (dest = get_dest pdf, 'listing-1')).not_to be_nil
    (expect dest[:page_number]).to be 1
    (expect dest[:y]).to eql lines[0][:from][:y]
  end

  it 'should offset anchor from top of block by value of block_anchor_top' do
    input = <<~'END'
    paragraph

    [#listing-1]
    ----
    listing
    ----
    END

    pdf_theme = { block_anchor_top: -12 }

    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    pdf = to_pdf input, pdf_theme: pdf_theme
    (expect (dest = get_dest pdf, 'listing-1')).not_to be_nil
    (expect dest[:page_number]).to be 1
    (expect dest[:y]).to eql (lines[0][:from][:y] + -pdf_theme[:block_anchor_top])
  end

  it 'should place anchor at top of block if advanced to next page' do
    input = <<~END
    paragraph

    [#listing-1%unbreakable]
    ----
    #{(['filler'] * 25).join %(\n\n)}
    ----
    END

    lines = (to_pdf input, analyze: :line).lines
    pdf = to_pdf input
    (expect (dest = get_dest pdf, 'listing-1')).not_to be_nil
    (expect dest[:page_number]).to be 2
    (expect dest[:y]).to eql lines[0][:from][:y]
  end

  it 'should split block if it cannot fit on a whole page' do
    pdf = to_pdf <<~END, analyze: true
    #{(['paragraph'] * 20).join (?\n * 2)}

    ----
    #{(['listing'] * 60).join ?\n}
    ----
    END

    (expect pdf.pages).to have_size 2
    listing_texts = pdf.find_text 'listing'
    (expect listing_texts[0][:page_number]).to be 1
    (expect listing_texts[-1][:page_number]).to be 2
  end

  it 'should use dashed border to indicate where block is split across a page boundary', visual: true do
    to_file = to_pdf_file <<~END, 'listing-page-split.pdf'
    ----
    #{(['listing'] * 60).join ?\n}
    ----

    ----
    #{(['more listing'] * 2).join ?\n}
    ----
    END

    (expect to_file).to visually_match 'listing-page-split.pdf'
  end

  it 'should not collapse bottom padding if block ends near bottom of page' do
    pdf_theme = {
      code_padding: 11,
      code_background_color: 'EEEEEE',
      code_border_width: 0,
      code_border_radius: 0,
    }
    pdf = with_content_spacer 10, 695 do |spacer_path|
      to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      image::#{spacer_path}[]

      ----
      $ gem install asciidoctor-pdf
      $ asciidoctor-pdf doc.adoc
      ----
      END
    end

    pages = pdf.pages
    (expect pages).to have_size 1
    gs = pdf.extract_graphic_states pages[0][:raw_content]
    (expect gs[1]).to have_background color: 'EEEEEE', top_left: [48.24, 98.89], bottom_right: [48.24, 48.24]
    last_text_y = pdf.text[-1][:y]
    (expect last_text_y - pdf_theme[:code_padding]).to be > 48.24

    pdf = with_content_spacer 10, 696 do |spacer_path|
      to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      image::#{spacer_path}[]

      ----
      $ gem install asciidoctor-pdf
      $ asciidoctor-pdf doc.adoc
      ----
      END
    end

    pages = pdf.pages
    (expect pages).to have_size 2
    gs = pdf.extract_graphic_states pages[0][:raw_content]
    (expect gs[1]).to have_background color: 'EEEEEE', top_left: [48.24, 97.89], bottom_right: [48.24, 48.24]
    (expect pdf.text[0][:page_number]).to eql 1
    (expect pdf.text[1][:page_number]).to eql 2
    (expect pdf.text[0][:y] - pdf_theme[:code_padding]).to be > 48.24
  end

  it 'should break line if wider than content area of block and still compute height correctly' do
    pdf_theme = {
      code_border_radius: 0,
      code_border_color: 'CCCCCC',
      code_border_width: [1, 0],
      code_background_color: 'transparent',
      sidebar_border_radius: 0,
      sidebar_border_width: [1, 0],
      sidebar_border_color: '0000EE',
      sidebar_background_color: 'transparent',
    }
    input = <<~END
    ****
    before

    ----
    one
    tw#{'o' * 250}
    three
    ----

    after
    ****
    END

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    (expect pdf.find_text %r/^ooo/).to have_size 3
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines.sort_by {|it| -it[:from][:y] }
    (expect lines).to have_size 4
    (expect lines[0][:color]).to eql '0000EE'
    (expect lines[1][:color]).to eql 'CCCCCC'
    (expect lines[2][:color]).to eql 'CCCCCC'
    (expect lines[3][:color]).to eql '0000EE'
    (expect (lines[0][:from][:y] - lines[1][:from][:y]).round 5).to eql ((lines[2][:from][:y] - lines[3][:from][:y]).round 5)
  end

  it 'should resize font to prevent wrapping if autofit option is set' do
    pdf = to_pdf <<~'END', pdf_theme: { code_font_size: 12 }, analyze: true
    [%autofit]
    ----
    @themesdir = ::File.expand_path theme.__dir__ || (doc.attr 'pdf-themesdir') || ::Dir.pwd
    ----
    END

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size]).to be < 12
  end

  it 'should not resize font if not necessary' do
    pdf = to_pdf <<~'END', analyze: true
    [%autofit]
    ----
    puts 'Hello, World!'
    ----
    END

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size]).to eql 11
  end

  it 'should not resize font more than base minimum font size' do
    pdf = to_pdf <<~'END', pdf_theme: { base_font_size_min: 8 }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    END

    (expect pdf.text).to have_size 2
    (expect pdf.text[0][:font_size]).to be 8
  end

  it 'should not resize font more than code minimum font size' do
    pdf = to_pdf <<~'END', pdf_theme: { base_font_size_min: 0, code_font_size_min: 8 }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    END

    (expect pdf.text).to have_size 2
    (expect pdf.text[0][:font_size]).to be 8
  end

  it 'should allow autofit to shrink text as much as it needs if the minimum font size is 0 or nil' do
    [0, nil].each do |size|
      pdf = to_pdf <<~'END', pdf_theme: { base_font_size_min: size }, analyze: true
      [%autofit]
      ----
      +--------------------------------------+----------------------------------------------------+-----------------------------------------------------+
      | id                                   | name                                               | subnets                                             |
      +--------------------------------------+----------------------------------------------------+-----------------------------------------------------+
      ----
      END

      expected_line = '+--------------------------------------+----------------------------------------------------+-----------------------------------------------------+'
      lines = pdf.lines
      (expect lines).to have_size 3
      (expect lines[0]).to eql expected_line
      (expect lines[2]).to eql expected_line
    end
  end

  it 'should allow base minimum font size to be specified relative to base font size' do
    pdf = to_pdf <<~'END', pdf_theme: { base_font_size: 12, base_font_size_min: '0.5rem' }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    END

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size].floor).to be 7
  end

  it 'should allow base minimum font size to be specified relative to current font size' do
    pdf = to_pdf <<~'END', pdf_theme: { base_font_size: 15, code_font_size: 12, base_font_size_min: '0.5em' }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    END

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size].floor).to be 7
  end

  it 'should use base font color if font color is not specified' do
    pdf = to_pdf <<~'END', pdf_theme: { base_font_color: 'AA0000', code_font_color: nil }, analyze: true
    before

    ----
    in the mix
    ----
    END

    before_text = pdf.find_unique_text 'before'
    (expect before_text[:font_color]).to eql 'AA0000'

    code_text = pdf.find_unique_text 'in the mix'
    (expect code_text[:font_color]).to eql 'AA0000'
  end

  it 'should allow theme to set different padding per edge when autofit is enabled' do
    pdf_theme = {
      code_border_radius: 0,
      code_padding: [5, 10, 15, 20],
      code_background_color: nil,
    }

    input = <<~END
    [%autofit]
    ----
    downloading#{(%w(.) * 100).join}
    done
    ----
    END

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
    pdf = to_pdf <<~'END', analyze: true
    ----
    flush
      indented
    flush
    ----
    END

    (expect pdf.lines).to eql ['flush', %(\u00a0 indented), 'flush']
  end

  it 'should guard indentation using no-break space character if string starts with indented line' do
    pdf = to_pdf <<~'END', analyze: true
    ----
      indented
    flush
      indented
    ----
    END

    (expect pdf.lines).to eql [%(\u00a0 indented), 'flush', %(\u00a0 indented)]
  end

  it 'should expand tabs if tabsize attribute is not specified' do
    pdf = to_pdf <<~END, analyze: true
    ----
    flush
      lead space
    \tlead tab
    \tlead tab\tcolumn tab
      lead space\tcolumn tab

    flush\t\t\tcolumn tab
    ----
    END

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
    pdf = to_pdf <<~END, analyze: true
    [tabsize=4]
    ----
    flush
      lead space
    \tlead tab
    \tlead tab\tcolumn tab
      lead space\tcolumn tab

    flush\t\t\tcolumn tab
    ----
    END

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
    pdf = to_pdf <<~END, analyze: true
    :tabsize: 4

    ----
    flush
      lead space
    \tlead tab
    \tlead tab\tcolumn tab
      lead space\tcolumn tab

    flush\t\t\tcolumn tab
    ----
    END

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
    pdf = to_pdf <<~'END', analyze: true
    :listing-caption: Listing

    .Title
    ----
    content
    ----
    END

    title_text = pdf.find_unique_text font_name: 'NotoSerif-Italic'
    (expect title_text[:string]).to eql 'Listing 1. Title'
  end

  it 'should allow theme to override caption for code blocks' do
    pdf_theme = {
      caption_font_color: '0000ff',
      code_caption_font_style: 'bold',
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Title
    ----
    content
    ----
    END

    title_text = (pdf.find_text 'Title')[0]
    (expect title_text[:font_color]).to eql '0000FF'
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
  end

  it 'should allow theme to set background color on caption' do
    pdf_theme = {
      code_caption_font_color: 'ffffff',
      code_caption_font_style: 'bold',
      code_caption_background_color: 'AA0000',
      code_caption_margin_outside: 10,
      code_background_color: 'transparent',
      code_border_radius: 0,
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Caption with background color
    ----
    content
    ----
    END

    title_text = pdf.find_unique_text 'Caption with background color'
    (expect title_text[:font_color]).to eql 'FFFFFF'
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect pdf.pages[0][:raw_content]).to include %(/DeviceRGB cs\n0.66667 0.0 0.0 scn\n48.24 790.899 498.8 14.991 re)
    (expect title_text[:y]).to be > 790.899
    (expect title_text[:y]).to (be_within 5).of 790.899
    (expect title_text[:font_size].round).to eql 10
  end

  it 'should allow theme to set background color on caption with outside margin that follows other text' do
    pdf_theme = {
      code_caption_font_color: 'ffffff',
      code_caption_font_style: 'bold',
      code_caption_background_color: 'AA0000',
      code_caption_margin_outside: 10,
      code_background_color: 'transparent',
      code_border_radius: 0,
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    before

    .Caption with background color
    ----
    content
    ----
    END

    title_text = pdf.find_unique_text 'Caption with background color'
    (expect title_text[:font_color]).to eql 'FFFFFF'
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect pdf.pages[0][:raw_content]).to include %(\n0.66667 0.0 0.0 scn\n48.24 753.119 498.8 14.991 re)
    (expect title_text[:y]).to be > 753.119
    (expect title_text[:y]).to (be_within 5).of 753.119
    (expect title_text[:font_size].round).to eql 10
  end

  it 'should apply text transform when computing height of background on caption' do
    pdf_theme = {
      code_caption_font_color: 'ffffff',
      code_caption_font_style: 'normal',
      code_caption_background_color: '3399FF',
      code_caption_text_transform: 'uppercase',
      code_caption_margin_outside: 10,
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Caption with background color that spans multiple lines because of the text transform
    ----
    content
    ----
    END

    title_text = pdf.find_unique_text %r/^CAPTION WITH BACKGROUND COLOR/
    (expect title_text[:font_color]).to eql 'FFFFFF'
    (expect title_text[:font_name]).to eql 'NotoSerif'
    (expect pdf.pages[0][:raw_content]).to include %(/DeviceRGB cs\n0.2 0.6 1.0 scn\n48.24 775.908 498.8 29.982 re)
    (expect title_text[:y]).to be > 790.899
    (expect title_text[:y]).to (be_within 5).of 790.899
    (expect title_text[:font_size].round).to eql 10
  end

  it 'should apply text formatting when computing height of background on caption' do
    pdf_theme = {
      code_caption_font_color: 'ffffff',
      code_caption_font_style: 'normal',
      code_caption_background_color: '3399FF',
      code_caption_margin_outside: 10,
    }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Caption with background color that contains _inline formatting_ but does not wrap
    ----
    content
    ----
    END

    title_text = pdf.find_unique_text %r/^Caption with background color/
    (expect title_text[:font_color]).to eql 'FFFFFF'
    (expect title_text[:font_name]).to eql 'NotoSerif'
    (expect (pdf.find_unique_text 'inline formatting')[:font_name]).to eql 'NotoSerif-Italic'
    (expect pdf.pages[0][:raw_content]).to include %(\n0.2 0.6 1.0 scn\n48.24 790.899 498.8 14.991 re)
    (expect title_text[:y]).to be > 790.899
    (expect title_text[:y]).to (be_within 5).of 790.899
    (expect title_text[:font_size].round).to eql 10
  end

  it 'should allow theme to place caption below block' do
    pdf_theme = { code_caption_end: 'bottom' }

    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Look out below!
    ----
    code
    ----
    END

    content_text = pdf.find_unique_text 'code'
    title_text = pdf.find_unique_text 'Look out below!'
    (expect title_text[:y]).to be < content_text[:y]
  end

  it 'should apply inline formatting if quotes subs is enabled' do
    pdf = to_pdf <<~'END', analyze: true
    [subs=+quotes]
    ----
    _1_ skipped
    *99* passing
    ----
    END

    italic_text = (pdf.find_text '1')[0]
    (expect italic_text[:font_name]).to eql 'mplus1mn-italic'
    bold_text = (pdf.find_text '99')[0]
    (expect bold_text[:font_name]).to eql 'mplus1mn-bold'
  end

  it 'should honor font family set on conum category in theme for conum in listing block' do
    pdf = to_pdf <<~'END', pdf_theme: { code_font_family: 'Courier' }, analyze: true
    ----
    fe <1>
    fi <2>
    fo <3>
    ----
    END

    lines = pdf.lines
    (expect lines[0]).to end_with ' ①'
    (expect lines[1]).to end_with ' ②'
    (expect lines[2]).to end_with ' ③'
    conum_text = (pdf.find_text '①')[0]
    (expect conum_text[:font_name]).not_to eql 'Courier'
  end

  it 'should allow theme to set conum color using CMYK value' do
    cmyk_color = [0, 100, 100, 60].extend Asciidoctor::PDF::ThemeLoader::CMYKColorValue
    pdf = to_pdf <<~'END', pdf_theme: { conum_font_color: cmyk_color }, analyze: true
    ----
    foo <1>
    ----
    <1> the counterpart of bar
    END

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
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    END

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
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    END

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
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    END

    lines = pdf.lines
    (expect lines).to have_size 4
    (expect lines[0][:from][:y]).to eql lines[0][:to][:y]
    (expect lines[0][:width]).to eql 2
    (expect lines[1][:from][:x]).to eql lines[1][:to][:x]
    (expect lines[1][:width]).to eql 1
  end

  it 'should allow width of border to be only set on one end' do
    pdf_theme = {
      code_border_color: 'AA0000',
      code_border_width: [1, 0, 0, 0],
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    END

    lines = pdf.lines
    (expect lines).to have_size 1
    (expect lines[0][:from][:y]).to eql lines[0][:to][:y]
    (expect lines[0][:width]).to eql 1
  end

  it 'should allow max width of border with different ends and sides to be less than 1' do
    pdf_theme = {
      code_border_color: 'AA0000',
      code_border_width: [0.5, 0],
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
    ----
    foo
    bar
    baz
    ----
    END

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0][:from][:y]).to eql lines[0][:to][:y]
    (expect lines[0][:width]).to eql 0.5
    (expect lines[1][:from][:y]).to eql lines[1][:to][:y]
    (expect lines[1][:width]).to eql 0.5
  end

  it 'should use dashed border to indicate where block is split across a page boundary when border is only on ends', visual: true do
    pdf_theme = {
      code_border_color: 'AA0000',
      code_border_width: [1, 0],
    }

    to_file = to_pdf_file <<~END, 'listing-page-split-border-ends.pdf', pdf_theme: pdf_theme
    ----
    #{(['listing'] * 60).join ?\n}
    ----
    END

    (expect to_file).to visually_match 'listing-page-split-border-ends.pdf'
  end

  it 'should allow theme to set different padding per edge' do
    pdf_theme = {
      code_border_radius: 0,
      code_padding: [5, 10, 15, 20],
      code_background_color: nil,
    }

    input = <<~END
    ----
    downloading#{(%w(.) * 100).join}done
    ----
    END

    text = (to_pdf input, pdf_theme: pdf_theme, analyze: true).text
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines

    left = lines[0][:from][:x]
    top = lines[0][:to][:y]
    bottom = lines[1][:to][:y]
    (expect text[0][:x]).to eql (left + 20.0).round 2
    (expect text[0][:y] + text[0][:font_size]).to be_within(1).of(top - 5)
    (expect text[1][:y]).to be_within(5).of(bottom + 15)
  end

  it 'should allow theme to set different padding for ends and sides' do
    pdf_theme = {
      code_border_radius: 0,
      code_padding: [10, 5],
      code_background_color: nil,
    }

    input = <<~END
    ----
    source code here
    ----
    END

    text = (to_pdf input, pdf_theme: pdf_theme, analyze: true).text
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines

    left = lines[0][:from][:x]
    top = lines[0][:to][:y]
    bottom = lines[1][:to][:y]
    (expect text[0][:x]).to eql (left + 5.0).round 2
    (expect text[0][:y] + text[0][:font_size]).to be_within(1).of(top - 10)
    (expect text[0][:y]).to be_within(3).of(bottom + 10)
  end

  it 'should allow theme to set 3-value padding that contains a nil value' do
    pdf_theme = {
      code_border_radius: 0,
      code_padding: [10, nil, 5],
      code_background_color: nil,
      code_border_width: [1, 0],
    }

    input = <<~END
    ----
    source code here
    ----
    END

    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    text = (to_pdf input, pdf_theme: pdf_theme, analyze: true).text

    (expect lines).to have_size 2
    (expect text).to have_size 1
    (expect lines[0][:from][:x]).to eql 48.24
    (expect text[0][:x]).to eql 48.24
  end

  it 'should not substitute conums if callouts sub is absent' do
    pdf = to_pdf <<~'END', analyze: true
    [subs=-callouts]
    ----
    not a conum <1>
    ----
    END

    (expect pdf.lines).to include 'not a conum <1>'
    (expect pdf.find_text '①').to be_empty
  end

  it 'should not fail to process callouts due to specialchars substitution' do
    (expect do
      pdf = to_pdf <<~'END', analyze: true
      ----
      <; <.>
      >; <!--2-->
      ----
      END

      (expect pdf.lines).to eql ['<; ①', '>; ②']
    end).not_to log_message
  end
end
