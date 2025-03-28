# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Admonition' do
  it 'should advance unbreakable block shorter than page to next page to avoid splitting it' do
    pdf = to_pdf <<~END, analyze: true
    #{(['paragraph'] * 20).join %(\n\n)}

    [NOTE%unbreakable]
    ====
    #{(['admonition'] * 20).join %(\n\n)}
    ====
    END

    admon_page_numbers = (pdf.find_text 'admonition').map {|it| it[:page_number] }.uniq
    (expect admon_page_numbers).to eql [2]
  end

  it 'should place anchor directly at top of block' do
    input = <<~END
    paragraph

    [NOTE#admon-1]
    ====
    filler
    ====
    END

    lines = (to_pdf input, analyze: :line).lines
    pdf = to_pdf input
    (expect (dest = get_dest pdf, 'admon-1')).not_to be_nil
    (expect dest[:y]).to eql lines[0][:from][:y]
  end

  it 'should offset anchor from top of block by amount of block_anchor_top' do
    pdf_theme = { block_anchor_top: -12 }

    input = <<~END
    paragraph

    [NOTE#admon-1]
    ====
    filler
    ====
    END

    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    pdf = to_pdf input, pdf_theme: pdf_theme
    (expect (dest = get_dest pdf, 'admon-1')).not_to be_nil
    (expect dest[:y]).to eql (lines[0][:from][:y] + -pdf_theme[:block_anchor_top])
  end

  it 'should keep anchor with block if block is advanced to next page' do
    input = <<~END
    paragraph

    [NOTE#admon-1%unbreakable]
    ====
    #{(['filler'] * 27).join %(\n\n)}
    ====
    END

    lines = (to_pdf input, analyze: :line).lines
    pdf = to_pdf input
    (expect (dest = get_dest pdf, 'admon-1')).not_to be_nil
    (expect dest[:page_number]).to be 2
    (expect dest[:y]).to eql lines[0][:from][:y]
  end

  it 'should vertically center label on first page if block is split across pages' do
    pdf = to_pdf <<~END, pdf_theme: { page_margin: '0.5in' }, analyze: true
    [NOTE]
    ====
    #{(['admonition'] * 40).join %(\n\n)}
    ====
    END

    (expect pdf.pages).to have_size 2
    page_height = (get_page_size pdf)[1]
    label_text = (pdf.find_text 'NOTE')[0]
    label_text_midpoint = label_text[:y] + (label_text[:font_size] * 0.5)
    (expect label_text_midpoint).to be_within(2).of(page_height * 0.5)
  end

  it 'should draw vertical rule on all pages if block is split across pages' do
    pdf = to_pdf <<~END, pdf_theme: { page_margin: '0.5in' }, analyze: :line
    [NOTE]
    ====
    #{(['admonition'] * 40).join %(\n\n)}
    ====
    END

    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines.map {|it| it[:page_number] }).to eql [1, 2]
    (expect lines[0][:to][:y]).to eql 36.0
    (expect lines[1][:to][:y]).to be > 36.0
  end

  it 'should draw border and background on all pages if block is split across pages', visual: true do
    pdf_theme = {
      admonition_background_color: 'F5A9A9',
      admonition_border_width: 0.5,
      admonition_border_color: '333333',
      admonition_rule_color: 'FFFFFF',
    }

    to_file = to_pdf_file <<~END, 'admonition-page-split.pdf', pdf_theme: pdf_theme
    before

    [NOTE]
    ====
    #{(['admonition'] * 40).join %(\n\n)}
    ====

    after
    END

    (expect to_file).to visually_match 'admonition-page-split.pdf'
  end

  it 'should not collapse bottom padding if block ends near bottom of page' do
    pdf_theme = {
      admonition_padding: 12,
      admonition_background_color: 'EEEEEE',
      admonition_column_rule_width: 0,
    }
    pdf = with_content_spacer 10, 690 do |spacer_path|
      to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      image::#{spacer_path}[]

      [NOTE]
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
    (expect last_text_y - pdf_theme[:admonition_padding]).to be > 48.24

    pdf = with_content_spacer 10, 692 do |spacer_path|
      to_pdf <<~END, pdf_theme: pdf_theme, analyze: true
      image::#{spacer_path}[]

      [NOTE]
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
    (expect pdf.text[1][:page_number]).to eql 1
    (expect pdf.text[2][:page_number]).to eql 2
    (expect pdf.text[1][:y] - pdf_theme[:admonition_padding]).to be > 48.24
  end

  it 'should allow theme to configure properties of caption' do
    pdf_theme = {
      admonition_caption_font_color: '00AA00',
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    .Admonition title
    [NOTE]
    ====
    There's something you should know.
    ====
    END

    title_text = (pdf.find_text 'Admonition title')[0]
    (expect title_text[:font_color]).to eql '00AA00'
  end

  it 'should use value of caption attribute as label' do
    pdf = to_pdf <<~'END', analyze: true
    [NOTE,caption=Pro Tip]
    Use bundler!
    END

    label_text = pdf.text[0]
    (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect label_text[:string]).to eql 'PRO TIP'
  end

  it 'should not transform label text if admonition_label_text_transform key is nil, none, or invalid' do
    [nil, 'none', 'invalid'].each do |transform|
      pdf = to_pdf <<~'END', pdf_theme: { admonition_label_text_transform: transform }, analyze: true
      [NOTE,caption=Pro Tip]
      Use bundler!
      END

      label_text = pdf.text[0]
      (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
      (expect label_text[:string]).to eql 'Pro Tip'
    end
  end

  # TODO: this could use a deeper assertion
  it 'should compute width of label even when glyph is missing' do
    pdf = to_pdf <<~'END', analyze: true
    [TIP,caption=⏻ Tip]
    Use bundler!
    END

    label_text = pdf.text[0]
    (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect label_text[:string]).to eql '⏻ TIP'
  end

  it 'should resize label text to fit if it overflows available space' do
    pdf = to_pdf <<~'END', pdf_theme: { admonition_label_font_size: 18 }, analyze: true
    [IMPORTANT]
    Make sure the device is powered off before servicing it.
    END

    label_text = pdf.find_unique_text 'IMPORTANT'
    (expect label_text).not_to be_nil
    (expect label_text[:font_size]).to be < 18
  end

  it 'should allow padding to be specified for label and content using single value' do
    input = <<~'END'
    [IMPORTANT]
    Make sure the device is powered off before servicing it.
    END

    pdf = to_pdf input, pdf_theme: { admonition_padding: 0, admonition_label_padding: 0 }, analyze: true
    ref_label_text = pdf.find_unique_text 'IMPORTANT'
    ref_content_text = pdf.find_unique_text 'Make sure the device is powered off before servicing it.'

    pdf = to_pdf input, pdf_theme: { admonition_padding: 10, admonition_label_padding: 10 }, analyze: true
    label_text = pdf.find_unique_text 'IMPORTANT'
    content_text = pdf.find_unique_text 'Make sure the device is powered off before servicing it.'

    (expect (label_text[:x] - ref_label_text[:x]).round 4).to eql 10.0
    (expect (content_text[:x] - ref_content_text[:x]).round 4).to eql 30.0
  end

  it 'should allow padding to be specified for label and content using array value' do
    input = <<~'END'
    [IMPORTANT]
    Make sure the device is powered off before servicing it.
    END

    pdf = to_pdf input, pdf_theme: { admonition_padding: 0, admonition_label_padding: 0 }, analyze: true
    ref_label_text = pdf.find_unique_text 'IMPORTANT'
    ref_content_text = pdf.find_unique_text 'Make sure the device is powered off before servicing it.'

    pdf = to_pdf input, pdf_theme: { admonition_padding: [nil, 10], admonition_label_padding: [nil, 10] }, analyze: true
    label_text = pdf.find_unique_text 'IMPORTANT'
    content_text = pdf.find_unique_text 'Make sure the device is powered off before servicing it.'

    (expect (label_text[:x] - ref_label_text[:x]).round 4).to eql 10.0
    (expect (content_text[:x] - ref_content_text[:x]).round 4).to eql 30.0
  end

  it 'should not move cursor below block if block ends at top of page' do
    pdf = to_pdf <<~'END', analyze: true
    top of page

    [NOTE]
    ====
    something to remember

    <<<
    ====

    top of page
    END

    top_of_page_texts = pdf.find_text 'top of page'
    (expect top_of_page_texts).to have_size 2
    (expect top_of_page_texts[0][:y]).to eql top_of_page_texts[0][:y]
  end

  it 'should not allow prose_margin_bottom to impact padding' do
    input = <<~'END'
    NOTE: The prose_margin_bottom value does not impact the padding around the content box.
    END

    pdf = to_pdf input, pdf_theme: { prose_margin_bottom: 12 }, analyze: :line
    reference_line = pdf.lines[0]
    reference_text = (to_pdf input, pdf_theme: { prose_margin_bottom: 12 }, analyze: true).text[0]

    pdf = to_pdf input, pdf_theme: { prose_margin_bottom: 24 }, analyze: :line
    line = pdf.lines[0]
    text = (to_pdf input, pdf_theme: { prose_margin_bottom: 24 }, analyze: true).text[0]

    (expect line[:from][:y]).to eql reference_line[:from][:y]
    (expect line[:to][:y]).to eql reference_line[:to][:y]
    (expect text[:y]).to eql reference_text[:y]
  end

  it 'should not increment counter in admonition content more times than expected' do
    pdf = to_pdf <<~'END', analyze: true
    == Initial value

    Current number is {counter:my-count:0}.

    == One is expected

    Current number is {counter:my-count}.

    == Two is expected

    Current number is {counter:my-count}.

    == Three is expected

    NOTE: Current number is {counter:my-count}.

    == Four is expected

    [%unbreakable]
    CAUTION: Current number is {counter:my-count}.

    == Five is expected

    Current number is {counter:my-count}.
    END

    expected = (0.upto 5).map {|it| %(Current number is #{it}.) }
    number_texts = pdf.find_text %r/^Current number is/
    (expect number_texts.map {|it| it[:string] }).to eql expected
  end

  context 'Text' do
    it 'should show admonition label in bold by default' do
      pdf = to_pdf <<~'END', analyze: true
      TIP: Look for the warp zone under the bridge.
      END

      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql 'TIP Look for the warp zone under the bridge.'
      text = pdf.text
      (expect text).to have_size 2
      label_text = text[0]
      (expect label_text[:string]).to eql 'TIP'
      (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
      content_text = text[1]
      (expect content_text[:string]).to eql 'Look for the warp zone under the bridge.'
    end

    it 'should allow the theme to specify a minimum width for the text-based label' do
      pdf_theme = {
        admonition_label_min_width: '75',
        admonition_label_text_align: 'right',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      NOTE: Remember the milk.

      TIP: Look for the warp zone under the bridge.

      CAUTION: Slippery when wet.

      WARNING: Beware of dog!

      IMPORTANT: Sign off before stepping away from the computer.
      END

      label_texts = pdf.find_text font_name: 'NotoSerif-Bold'
      label_right_reference = nil
      label_texts.each do |it|
        label_right_reference ||= it[:x] + it[:width]
        (expect it[:x] + it[:width]).to be_within(1.5).of(label_right_reference)
      end

      content_texts = pdf.find_text font_name: 'NotoSerif'
      (expect content_texts.map {|it| it[:x] }.uniq).to eql [content_texts[0][:x]]
    end

    it 'should allow theme to control vertical alignment of label' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_label_vertical_align: 'top' }, analyze: true
      [NOTE]
      ====
      There are lots of things you need to know.
      Then there are the things that you already know.
      And those things that you don't know that you do not know.
      This documentation seeks to close the gaps between them.
      ====
      END

      label_text = (pdf.find_text 'NOTE')[0]
      content_text = (pdf.find_text font_name: 'NotoSerif')[0]
      (expect label_text[:y]).to be > content_text[:y]
    end

    it 'should resolve character references in label' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_label_font_color: '000000' }, analyze: true
      [NOTE,caption=&#174;]
      ====
      Christoph and sons.
      ====
      END

      label_text = (pdf.find_text font_color: '000000')[0]
      (expect label_text[:string]).to eql ?\u00ae
      (expect label_text[:width]).to be < label_text[:font_size]
      (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    end
  end

  context 'Icon' do
    it 'should show font-based icon in place of label when icons=font' do
      pdf = to_pdf <<~'END', analyze: true
      :icons: font

      TIP: Look for the warp zone under the bridge.
      END

      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql %(\uf0eb Look for the warp zone under the bridge.)
      text = pdf.text
      (expect text).to have_size 2
      label_text = text[0]
      (expect label_text[:string]).to eql ?\uf0eb
      (expect label_text[:font_name]).to eql 'FontAwesome5Free-Regular'
      # NOTE: font size is reduced to fit within available space
      (expect label_text[:font_size]).to be < 24
      content_text = text[1]
      (expect content_text[:string]).to eql 'Look for the warp zone under the bridge.'
    end

    it 'should not reduce font size of icon if specified size fits within available space' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_icon_important: { size: 50, scale: 1 } }, analyze: true
      :icons: font

      [IMPORTANT]
      ====
      Always do this.

      And when you do that, always do this too!
      ====
      END

      label_text = pdf.find_unique_text ?\uf06a
      (expect label_text[:font_size]).to eql 50
    end

    it 'should allow the theme to specify a minimum width for the font-based icon label' do
      pdf_theme = {
        admonition_label_min_width: '75',
        admonition_label_text_align: 'right',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      :icons: font

      NOTE: Remember the milk.

      TIP: Look for the warp zone under the bridge.

      CAUTION: Slippery when wet.

      WARNING: Beware of dog!

      IMPORTANT: Sign off before stepping away from the computer.
      END

      label_texts = pdf.text.select {|it| it[:font_name].start_with? 'FontAwesome' }
      (expect label_texts[0][:x]).to be > 100
      label_right_reference = nil
      label_texts.each do |it|
        label_right_reference ||= it[:x] + it[:width]
        (expect it[:x] + it[:width]).to be_within(1.5).of(label_right_reference)
      end

      content_texts = pdf.find_text font_name: 'NotoSerif'
      (expect content_texts.map {|it| it[:x] }.uniq).to eql [content_texts[0][:x]]
    end

    it 'should allow theme to control vertical alignment of icon' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_label_vertical_align: 'top' }, analyze: true
      :icons: font

      [NOTE]
      ====
      There are lots of things you need to know.
      Then there are the things that you already know.
      And those things that you don't know that you do not know.
      This documentation seeks to close the gaps between them.
      ====
      END

      icon_text = (pdf.find_text ?\uf05a)[0]
      content_text = (pdf.find_text font_color: '333333')[1]
      (expect icon_text[:y]).to be > content_text[:y]
    end

    it 'should assume icon name with no icon set prefix is a legacy FontAwesome icon name' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_icon_tip: { name: 'smile-wink' } }, analyze: true
      :icons: font

      TIP: Time to upgrade your icon set.
      END

      icon_text = pdf.text[0]
      (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      (expect icon_text[:string]).to eql ?\uf4da
    end

    it 'should be able to use fa- prefix to reference icon in legacy FontAwesome set' do
      (expect do
        pdf = to_pdf <<~'END', pdf_theme: { admonition_icon_tip: { name: 'fa-smile-wink' } }, analyze: true
        :icons: font

        TIP: Time to upgrade your icon set.
        END

        icon_text = pdf.text[0]
        (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
        (expect icon_text[:string]).to eql ?\uf4da
      end).to log_message severity: :INFO, message: 'tip admonition in theme uses icon from deprecated fa icon set; use fas, far, or fab instead', using_log_level: :INFO
    end

    it 'should allow icon to come from Foundation icon set' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_icon_warning: { name: 'fi-alert' } }, analyze: true
      :icons: font

      WARNING: Just don't do it.
      END

      icon_text = pdf.text[0]
      (expect icon_text[:font_name]).to eql 'fontcustom'
      (expect icon_text[:string]).to eql ?\uf101
    end

    it 'should fall back to note icon if icon name cannot be resolved' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_icon_warning: { name: nil } }, analyze: true
      :icons: font

      WARNING: If the icon name is nil, the default note icon will be used.
      END

      icon_text = pdf.text[0]
      (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      (expect icon_text[:string]).to eql ?\uf05a
    end

    it 'should set color of icon to value of stroke_color key specified in theme' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_icon_note: { stroke_color: '00ff00' } }, analyze: true
      :icons: font

      NOTE: This icon is green.
      END

      icon_text = (pdf.find_text ?\uf05a)[0]
      (expect icon_text[:font_color]).to eql '00FF00'
    end

    it 'should use icon glyph specified in theme' do
      pdf = to_pdf <<~'END', pdf_theme: { admonition_icon_tip: { name: 'far-money-bill-alt' } }, analyze: true
      :icons: font

      TIP: Look for the warp zone under the bridge.
      END

      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql %(\uf3d1 Look for the warp zone under the bridge.)
      text = pdf.text
      (expect text).to have_size 2
      label_text = text[0]
      (expect label_text[:string]).to eql ?\uf3d1
      (expect label_text[:font_name]).to eql 'FontAwesome5Free-Regular'
      content_text = text[1]
      (expect content_text[:string]).to eql 'Look for the warp zone under the bridge.'
    end

    it 'should use SVG icon specified by icon attribute when icons attribute is set', visual: true do
      to_file = to_pdf_file <<~'END', 'admonition-custom-svg-icon.pdf', attribute_overrides: { 'docdir' => fixtures_dir }
      :icons: font
      :iconsdir:
      :icontype: svg

      [TIP,icon=square]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      END

      (expect to_file).to visually_match 'admonition-custom-svg-icon.pdf'
    end

    it 'should position SVG icon specified by icon attribute in correct column when icons attribute is set' do
      pdf_theme = {
        page_columns: 2,
        page_column_gap: 12,
        admonition_padding: 0,
        admonition_column_rule_width: 0,
        admonition_icon_tip: { width: 24, scale: 1 },
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      :icons: svg
      :iconsdir: {imagesdir}

      left column

      [.column]
      <<<

      right column

      [icon=square]
      TIP: Use the icon attribute to customize the image for an admonition block.
      END

      expected_icon_x = (pdf.find_unique_text 'right column')[:x]
      expected_content_x = expected_icon_x + 24
      gs = pdf.extract_graphic_states pdf.pages[0][:raw_content]
      (expect gs[0]).to include %(#{expected_icon_x} 574.33 200.0 200.0 re)
      (expect (pdf.find_unique_text %r/Use /)[:x]).to eql expected_content_x
    end

    it 'should warn if SVG icon specified by icon attribute is missing' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }
        :icons: font

        [TIP,icon=missing]
        Use the icon attribute to customize the image for an admonition block.
        END
        (expect get_images pdf, 1).to be_empty
        (expect (pdf.page 1).text).to include 'TIP'
      end).to log_message severity: :WARN, message: %(admonition icon image not found or not readable: #{fixture_file 'missing.png'})
    end

    it 'should warn if SVG icon specified by icon attribute has errors' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: :rect
        :icons: font
        :icontype: svg

        [TIP,icon=faulty]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        END
        (expect pdf.rectangles).to have_size 1
        # NOTE: width and height of rectangle match what's defined in SVG
        (expect pdf.rectangles[0][:width]).to eql 200.0
        (expect pdf.rectangles[0][:height]).to eql 200.0
      end).to log_message severity: :WARN, message: %(~problem encountered in image: #{fixture_file 'faulty.svg'}; Unknown tag 'foobar')
    end

    it 'should not warn if SVG icon specified by icon attribute in scratch document has errors' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: :rect
        :icons: font
        :icontype: svg

        [%unbreakable]
        --
        [TIP,icon=faulty]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        --
        END
        (expect pdf.rectangles).to have_size 1
        # NOTE: width and height of rectangle match what's defined in SVG
        (expect pdf.rectangles[0][:width]).to eql 200.0
        (expect pdf.rectangles[0][:height]).to eql 200.0
      end).to log_message severity: :WARN, message: %(~problem encountered in image: #{fixture_file 'faulty.svg'}; Unknown tag 'foobar')
    end

    it 'should warn and fall back to admonition label if SVG icon cannot be found' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: true
        :icons:
        :icontype: svg

        [WARNING]
        ====
        The admonition label will be used if the image cannot be resolved.
        ====
        END
        label_text = pdf.find_unique_text 'WARNING'
        (expect label_text).not_to be_nil
        (expect label_text[:font_name]).to include 'Bold'
      end).to log_message severity: :WARN, message: %(admonition icon image for WARNING not found or not readable: #{fixture_file 'warning.svg'})
    end

    it 'should warn and fall back to admonition label if SVG icon specified by icon attribute cannot be embedded' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: true
        :icons: font
        :icontype: svg

        [TIP,icon=broken]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        END
        label_text = pdf.find_unique_text 'TIP'
        (expect label_text).not_to be_nil
        (expect label_text[:font_name]).to include 'Bold'
      end).to log_message severity: :WARN, message: %(~could not embed admonition icon image: #{fixture_file 'broken.svg'}; The data supplied is not a valid SVG document.\nMissing end tag for 'rect')
    end

    it 'should resize fallback admonition label to fit in available space if icon fails to embed' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: true
        :icons: font
        :icontype: svg

        [WARNING,icon=broken]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        END
        label_text = pdf.find_unique_text 'WARNING'
        (expect label_text).not_to be_nil
        (expect label_text[:font_size]).to be < 10.5
      end).to log_message severity: :WARN, message: %(~could not embed admonition icon image: #{fixture_file 'broken.svg'}; The data supplied is not a valid SVG document.\nMissing end tag for 'rect')
    end

    # NOTE: this test also verifies the text transform is applied as requested by theme
    it 'should warn and fall back to admonition label if raster icon cannot be found' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }, pdf_theme: { admonition_label_text_transform: 'uppercase' }, analyze: true
        :icons:

        [WARNING]
        ====
        The admonition label will be used if the image cannot be resolved.
        ====
        END
        label_text = pdf.find_unique_text 'WARNING'
        (expect label_text).not_to be_nil
        (expect label_text[:font_name]).to include 'Bold'
      end).to log_message severity: :WARN, message: %(admonition icon image for WARNING not found or not readable: #{fixture_file 'warning.png'})
    end

    # NOTE: this test also verifies the text transform is not applied if disabled by the theme
    it 'should warn and fall back to admonition label if raster icon specified by icon attribute cannot be embedded' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => fixtures_dir }, pdf_theme: { admonition_label_text_transform: 'none' }, analyze: true
        :icons:

        [TIP,icon=corrupt.png]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        END
        label_text = pdf.find_unique_text 'Tip'
        (expect label_text).not_to be_nil
        (expect label_text[:font_name]).to include 'Bold'
      end).to log_message severity: :WARN, message: %(~could not embed admonition icon image: #{fixture_file 'corrupt.png'}; image file is an unrecognised format)
    end

    it 'should embed remote image in icon if allow-uri-read attribute is set', network: true, visual: true do
      with_svg_with_remote_image do |image_path|
        to_file = to_pdf_file <<~END, 'admonition-custom-svg-icon-with-remote-image.pdf', attribute_overrides: { 'docdir' => tmp_dir, 'allow-uri-read' => '' }
        :icons: font
        :iconsdir:

        [NOTE,icon=#{File.basename image_path}]
        ====
        AsciiDoc is awesome!
        ====
        END

        (expect to_file).to visually_match 'admonition-custom-svg-icon-with-remote-image.pdf'
      end
    end

    it 'should use original width of SVG icon if height is less than height of admonition block', visual: true do
      pdf_theme = { admonition_icon_note: { width: 36, scale: 1 } }
      to_file = to_pdf_file <<~'END', 'admonition-custom-svg-fit.pdf', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }
      :icons: font
      :iconsdir:

      [NOTE,icon=green-bar.svg]
      ====
      When you see this icon, it means there's additional advice about passing tests.
      ====
      END

      (expect to_file).to visually_match 'admonition-custom-svg-fit.pdf'
    end

    it 'should use raster icon specified by icon attribute when icons attribute is set', visual: true do
      to_file = to_pdf_file <<~'END', 'admonition-custom-raster-icon.pdf', attribute_overrides: { 'docdir' => fixtures_dir }
      :icons: font
      :iconsdir:

      [TIP,icon=tux.png]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      END

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    it 'should allow theme to control width of admonition icon image using width key' do
      pdf_theme = { admonition_icon_tip: { scale: 0.6, width: 40 } }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :image
      :icons: font
      :iconsdir:

      [TIP,icon=logo.png]
      ====
      Use the icon attribute to customize the image for an admonition block.

      Use the admonition_label_min_width key to control the image width.
      ====
      END

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to eql 24.0
      (expect images[0][:x]).to eql 68.24
    end

    it 'should allow theme to control spacing around admonition icon image using admonition_label_min_width key' do
      pdf_theme = { admonition_label_min_width: 40, admonition_icon_tip: { scale: 1, width: 24 } }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :image
      :icons: font
      :iconsdir:

      [TIP,icon=logo.png]
      ====
      Use the icon attribute to customize the image for an admonition block.

      Use the admonition_label_min_width key to control the image width.
      ====
      END

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to eql 24.0
      (expect images[0][:x]).to eql 68.24
    end

    it 'should resolve icon when icons attribute is set to image', visual: true do
      to_file = to_pdf_file <<~'END', 'admonition-image-icon.pdf', attribute_overrides: { 'docdir' => fixtures_dir }
      :icons: image
      :iconsdir:

      [TIP]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      END

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    it 'should not unset data-uri attribute when resolving icon image if already unset', visual: true do
      doc = Asciidoctor.load <<~'END', backend: :pdf, safe: :safe, standalone: true, attributes: { 'docdir' => fixtures_dir, 'nofooter' => '' }
      :icons: image
      :iconsdir:

      [TIP]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      END

      (expect doc.converter).not_to be_nil
      doc.remove_attr 'data-uri'
      to_file = File.join output_dir, 'admonition-image-icon-no-data-uri.pdf'
      doc.converter.write doc.convert, to_file

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    it 'should not resolve remote icon when icons attribute is set to image and allow-uri-read is not set' do
      with_local_webserver do |base_url|
        (expect do
          pdf = to_pdf <<~'END', attribute_overrides: { 'iconsdir' => base_url }, analyze: true
          :icons: image

          [TIP]
          ====
          Use the icon attribute to customize the image for an admonition block.
          ====
          END

          label_text = pdf.find_unique_text 'TIP'
          (expect label_text).not_to be_nil
          (expect pdf.lines).to eql ['TIP Use the icon attribute to customize the image for an admonition block.']
        end).to log_messages [
          { severity: :WARN, message: %(cannot embed remote image: #{base_url}/tip.png (allow-uri-read attribute not enabled)) },
          { severity: :WARN, message: %(admonition icon image for TIP not found or not readable: #{base_url}/tip.png) },
        ]
      end
    end

    it 'should not resolve remote icon when icons attribute is set to image, allow-uri-read is set, and image is missing' do
      with_local_webserver do |base_url|
        base_url += '/nada'
        (expect do
          pdf = to_pdf <<~'END', attribute_overrides: { 'allow-uri-read' => '', 'iconsdir' => base_url }, analyze: true
          :icons: image

          [TIP]
          ====
          Use the icon attribute to customize the image for an admonition block.
          ====
          END

          label_text = pdf.find_unique_text 'TIP'
          (expect label_text).not_to be_nil
          (expect pdf.lines).to eql ['TIP Use the icon attribute to customize the image for an admonition block.']
        end).to log_messages [
          { severity: :WARN, message: %(could not retrieve remote image: #{base_url}/tip.png; 404 Not Found) },
          { severity: :WARN, message: %(admonition icon image for TIP not found or not readable: #{base_url}/tip.png) },
        ]
      end
    end

    it 'should resolve remote icon when icons attribute is set to image and allow-uri-read is set', visual: true do
      to_file = with_local_webserver do |base_url|
        to_pdf_file <<~'END', 'admonition-remote-image-icon.pdf', attribute_overrides: { 'allow-uri-read' => '', 'iconsdir' => base_url }
        :icons: image

        [TIP]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        END
      end

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    it 'should resize icon only if it does not fit within the available space' do
      pdf_theme = { admonition_icon_tip: { scale: 1 } }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :image
      :icons: image
      :iconsdir:

      [TIP]
      This is Tux.
      He's the Linux mascot.
      END

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to be < 36.0
      (expect images[0][:height]).to be < 42.3529

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :image
      :icons: image
      :iconsdir:

      [TIP]
      ====
      This is Tux.
      If you spend any amount of time in the Linux world, you'll see him a lot.
      He's the Linux mascot.

      Thanks to Linux, penguins have receive a lot more attention.
      Technology can sometimes be a force for good like that.
      ====
      END

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to eql 36.0
      (expect images[0][:height]).to eql 42.35294
    end

    it 'should warn and fall back to admonition label if image icon cannot be resolved' do
      (expect do
        pdf = to_pdf <<~'END', attribute_overrides: { 'docdir' => fixtures_dir }, analyze: true
        :icons: image
        :iconsdir:

        [NOTE]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        END

        note_text = pdf.find_unique_text 'NOTE'
        (expect note_text).not_to be_nil
        (expect note_text[:font_name]).to include 'Bold'
      end).to log_message severity: :WARN, message: '~admonition icon image for NOTE not found or not readable'
    end

    it 'should use icon image specified in theme if icon attribute is not set on block', visual: true do
      to_file = to_pdf_file <<~'END', 'admonition-icon-image.pdf', attribute_overrides: { 'pdf-theme' => (fixture_file 'admonition-image-theme.yml') }, analyze: true
      :icons:

      [NOTE]
      ====
      You can use a custom PDF theme to customize the icon image for a specific admonition type.
      ====
      END

      (expect to_file).to visually_match 'admonition-icon-image.pdf'
    end

    it 'should substitute attribute references in icon image value in theme', visual: true do
      pdf_theme = { admonition_icon_note: { image: '{docdir}/tux-note.svg' } }
      to_file = to_pdf_file <<~'END', 'admonition-icon-image-with-attribute-ref.pdf', attribute_overrides: { 'docdir' => fixtures_dir }, pdf_theme: pdf_theme, analyze: true
      :icons:

      [NOTE]
      ====
      You can use a custom PDF theme to customize the icon image for a specific admonition type.
      ====
      END

      (expect to_file).to visually_match 'admonition-icon-image.pdf'
    end

    it 'should warn and fall back to admonition label if icon image specified in theme cannot be resolved' do
      pdf_theme = {
        __dir__: fixtures_dir,
        admonition_icon_note: { image: 'does-not-exist.png' },
      }
      (expect do
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme
        :icons:

        [NOTE]
        ====
        If the icon image cannot be found, the converter will fall back to using the label text in the place of the icon.
        ====
        END

        (expect get_images pdf).to be_empty
        (expect pdf.pages[0].text).to include 'NOTE'
      end).to log_message severity: :WARN, message: '~admonition icon image for NOTE not found or not readable'
    end

    it 'should allow theme to specify icon for custom admonition type' do
      require 'asciidoctor/extensions'

      extensions = proc do
        block :QUESTION do
          on_context :example
          process do |parent, reader, attrs|
            attrs['name'] = 'question'
            attrs['caption'] = 'Question'
            create_block parent, :admonition, reader.lines, attrs, content_model: :compound
          end
        end
      end

      pdf_theme = {
        admonition_icon_question: { name: 'question-circle' },
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, extensions: extensions, analyze: true
      :icons: font

      [QUESTION]
      ====
      Are you following along?

      Just checking ;)
      ====
      END

      icon_text = pdf.find_unique_text ?\uf059
      (expect icon_text).not_to be_nil
      (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      (expect icon_text[:font_size]).to be 24
      (expect pdf.find_unique_text 'Are you following along?').not_to be_nil
      (expect pdf.find_unique_text 'Just checking ;)').not_to be_nil
    end

    it 'should use note icon for custom admonition type if theme does not specify icon name' do
      require 'asciidoctor/extensions'

      extensions = proc do
        block :FACT do
          on_context :example
          process do |parent, reader, attrs|
            attrs['name'] = 'fact'
            attrs['caption'] = 'Fact'
            create_block parent, :admonition, reader.lines, attrs, content_model: :compound
          end
        end
      end

      pdf = to_pdf <<~'END', extensions: extensions, analyze: true
      :icons: font

      [FACT]
      ====
      Like all planetary bodies, the Earth is spherical.
      ====
      END

      (expect pdf.lines).to eql [%(\uf05a Like all planetary bodies, the Earth is spherical.)]
      icon_text = pdf.find_unique_text ?\uf05a
      (expect icon_text[:font_color]).to eql '333333'
    end
  end

  context 'Background & Lines' do
    it 'should allow theme to customize color, width, and style of column rule' do
      %w(dotted dashed).each do |style|
        pdf_theme = {
          admonition_column_rule_color: '222222',
          admonition_column_rule_width: 1,
          admonition_column_rule_style: style,
        }
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
        TIP: You can use the theme to customize the color and width of the column rule.
        END

        lines = pdf.lines
        (expect lines).to have_size 1
        column_rule = lines[0]
        (expect column_rule[:from][:x]).to eql column_rule[:to][:x]
        (expect column_rule[:color]).to eql '222222'
        (expect column_rule[:width]).to eql 1
        (expect column_rule[:style]).to eql style.to_sym
      end
    end

    it 'should not draw column rule if value is transparent' do
      pdf_theme = { admonition_column_rule_color: 'transparent' }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      END

      lines = pdf.lines
      (expect lines).to be_empty
    end

    it 'should not draw column rule if value is nil and base border color is transparent' do
      pdf_theme = { base_border_color: 'transparent', admonition_column_rule_color: nil }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      END

      lines = pdf.lines
      (expect lines).to be_empty
    end

    it 'should not assign default width to column rule if key is not specified' do
      pdf_theme = {
        admonition_column_rule_color: '222222',
        admonition_column_rule_width: nil,
        base_border_width: nil,
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      END

      lines = pdf.lines
      (expect lines).to be_empty
    end

    it 'should not fail if base border width is not set when using original theme' do
      pdf_theme = {
        extends: 'base',
        base_border_width: nil,
        admonition_column_rule_width: nil,
        admonition_column_rule_color: '222222',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      END

      (expect pdf.lines).to be_empty
    end

    it 'should allow theme to specify double style for column rule' do
      pdf_theme = {
        admonition_column_rule_color: '222222',
        admonition_column_rule_width: 1,
        admonition_column_rule_style: 'double',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      END

      lines = pdf.lines
      (expect lines).to have_size 2
      column_rule1 = lines[0]
      (expect column_rule1[:from][:x]).to eql column_rule1[:to][:x]
      (expect column_rule1[:color]).to eql '222222'
      (expect column_rule1[:width]).to eql 1
      (expect column_rule1[:style]).to eql :solid
      column_rule2 = lines[1]
      (expect column_rule2[:from][:x]).to eql column_rule2[:to][:x]
      (expect column_rule2[:color]).to eql '222222'
      (expect column_rule2[:width]).to eql 1
      (expect column_rule2[:style]).to eql :solid
      (expect column_rule2[:from][:x] - column_rule1[:from][:x]).to eql 2.0
    end

    it 'should not use base border width for column rule if column rule width is nil' do
      pdf_theme = {
        base_border_width: 2,
        admonition_column_rule_color: '222222',
        admonition_column_rule_width: nil,
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      END

      lines = pdf.lines
      (expect lines).to be_empty
    end

    it 'should allow theme to add border', visual: true do
      pdf_theme = {
        admonition_border_width: 0.5,
        admonition_border_radius: 5,
        admonition_border_color: 'e0e0e0',
        admonition_column_rule_color: 'e0e0e0',
      }
      to_file = to_pdf_file <<~'END', 'admonition-border.pdf', pdf_theme: pdf_theme
      TIP: You can use the theme to add a border.
      END

      (expect to_file).to visually_match 'admonition-border.pdf'
    end

    it 'should allow theme to add background color', visual: true do
      pdf_theme = {
        admonition_background_color: 'eeeeee',
        admonition_border_radius: 3,
        admonition_column_rule_width: 0,
      }
      to_file = to_pdf_file <<~'END', 'admonition-background-color.pdf', pdf_theme: pdf_theme
      TIP: You can use the theme to add a background color.
      END

      (expect to_file).to visually_match 'admonition-background-color.pdf'
    end

    it 'should apply correct padding around content' do
      pdf_theme = { admonition_background_color: 'EEEEEE' }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      :icons: font

      [NOTE]
      ====
      first

      last
      ====
      END

      boundaries = (pdf.extract_graphic_states pdf.pages[0][:raw_content])[0]
        .select {|l| l.end_with? 'l' }
        .map {|l| l.split.yield_self {|it| { x: it[0].to_f, y: it[1].to_f } } }
      (expect boundaries).to have_size 4
      top, bottom = boundaries.map {|it| it[:y] }.yield_self {|it| [it.max, it.min] }
      left = boundaries.map {|it| it[:x] }.min
      text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
      text_bottom = (pdf.find_unique_text 'last')[:y]
      text_left = (pdf.find_unique_text 'first')[:x]
      (expect (top - text_top).to_f).to (be_within 2).of 4.0
      (expect (text_bottom - bottom).to_f).to (be_within 2).of 8.0 # extra padding is descender
      (expect (text_left - left).to_f).to eql 72.0
    end

    it 'should apply correct padding around content when using base theme' do
      pdf_theme = { extends: 'base', admonition_background_color: 'EEEEEE' }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      :icons: font

      [NOTE]
      ====
      first

      last
      ====
      END

      boundaries = (pdf.extract_graphic_states pdf.pages[0][:raw_content])[0]
        .select {|l| l.end_with? 'l' }
        .map {|l| l.split.yield_self {|it| { x: it[0].to_f, y: it[1].to_f } } }
      (expect boundaries).to have_size 4
      top, bottom = boundaries.map {|it| it[:y] }.yield_self {|it| [it.max, it.min] }
      left = boundaries.map {|it| it[:x] }.min
      text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
      text_bottom = (pdf.find_unique_text 'last')[:y]
      text_left = (pdf.find_unique_text 'first')[:x]
      (expect (top - text_top).to_f).to (be_within 1).of 4.0
      (expect (text_bottom - bottom).to_f).to (be_within 1).of 8.0 # extra padding is descender
      (expect (text_left - left).to_f).to eql 72.0
    end

    it 'should allow theme to disable column rule by setting width to 0' do
      pdf_theme = { admonition_column_rule_width: 0 }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to add a background color.
      END

      (expect pdf.lines).to be_empty
    end
  end
end
