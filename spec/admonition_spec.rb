# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Admonition' do
  it 'should advance block to next page to avoid splitting it if it will fit on page' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['paragraph'] * 20).join %(\n\n)}

    [NOTE]
    ====
    #{(['admonition'] * 20).join %(\n\n)}
    ====
    EOS

    admon_page_numbers = (pdf.find_text 'admonition').map {|it| it[:page_number] }.uniq
    (expect admon_page_numbers).to eql [2]
  end

  it 'should vertically center label on first page if block is split across pages' do
    pdf = to_pdf <<~EOS, pdf_theme: { page_margin: '0.5in' }, analyze: true
    [NOTE]
    ====
    #{(['admonition'] * 40).join %(\n\n)}
    ====
    EOS

    (expect pdf.pages).to have_size 2
    page_height = (get_page_size pdf)[1]
    label_text = (pdf.find_text 'NOTE')[0]
    label_text_midpoint = label_text[:y] + (label_text[:font_size] * 0.5)
    (expect label_text_midpoint).to be_within(2).of(page_height * 0.5)
  end

  it 'should draw vertical rule on all pages if block is split across pages' do
    pdf = to_pdf <<~EOS, pdf_theme: { page_margin: '0.5in' }, analyze: :line
    [NOTE]
    ====
    #{(['admonition'] * 40).join %(\n\n)}
    ====
    EOS

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

    to_file = to_pdf_file <<~EOS, 'admonition-page-split.pdf', pdf_theme: pdf_theme
    before

    [NOTE]
    ====
    #{(['admonition'] * 40).join %(\n\n)}
    ====

    after
    EOS

    (expect to_file).to visually_match 'admonition-page-split.pdf'
  end

  it 'should allow theme to configure properties of caption' do
    pdf_theme = {
      admonition_caption_font_color: '00AA00',
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    .Admonition title
    [NOTE]
    ====
    There's something you should know.
    ====
    EOS

    title_text = (pdf.find_text 'Admonition title')[0]
    (expect title_text[:font_color]).to eql '00AA00'
  end

  it 'should use value of caption attribute as label' do
    pdf = to_pdf <<~'EOS', analyze: true
    [NOTE,caption=Pro Tip]
    Use bundler!
    EOS

    label_text = pdf.text[0]
    (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect label_text[:string]).to eql 'PRO TIP'
  end

  it 'should not transform label text if admonition_label_text_transform key is nil' do
    pdf = to_pdf <<~'EOS', pdf_theme: { admonition_label_text_transform: nil }, analyze: true
    [NOTE,caption=Pro Tip]
    Use bundler!
    EOS

    label_text = pdf.text[0]
    (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect label_text[:string]).to eql 'Pro Tip'
  end

  # TODO: this could use a deeper assertion
  it 'should compute width of label even when glyph is missing' do
    pdf = to_pdf <<~'EOS', analyze: true
    [TIP,caption=⏻ Tip]
    Use bundler!
    EOS

    label_text = pdf.text[0]
    (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect label_text[:string]).to eql '⏻ TIP'
  end

  # NOTE: this is a negative test until the defect is addressed
  it 'should not show label if it overflows available space' do
    pdf = to_pdf <<~'EOS', pdf_theme: { admonition_label_font_size: 18 }, analyze: true
    [IMPORTANT]
    Make sure the device is powered off before servicing it.
    EOS

    (expect pdf.find_unique_text 'IMPORTANT').to be_nil
  end

  it 'should allow padding to be specified for label and content using single value' do
    input = <<~'EOS'
    [IMPORTANT]
    Make sure the device is powered off before servicing it.
    EOS

    pdf = to_pdf input, pdf_theme: { admonition_padding: 0, admonition_label_padding: 0 }, analyze: true
    ref_label_text = pdf.find_unique_text 'IMPORTANT'
    ref_content_text = pdf.find_unique_text 'Make sure the device is powered off before servicing it.'

    pdf = to_pdf input, pdf_theme: { admonition_padding: 10, admonition_label_padding: 10 }, analyze: true
    label_text = pdf.find_unique_text 'IMPORTANT'
    content_text = pdf.find_unique_text 'Make sure the device is powered off before servicing it.'

    (expect label_text[:x] - ref_label_text[:x]).to eql 10.0
    (expect content_text[:x] - ref_content_text[:x]).to eql 30.0
  end

  it 'should not move cursor below block if block ends at top of page' do
    pdf = to_pdf <<~'EOS', analyze: true
    top of page

    [NOTE]
    ====
    something to remember

    <<<
    ====

    top of page
    EOS

    top_of_page_texts = pdf.find_text 'top of page'
    (expect top_of_page_texts).to have_size 2
    (expect top_of_page_texts[0][:y]).to eql top_of_page_texts[0][:y]
  end

  context 'Text' do
    it 'should show admonition label in bold by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      TIP: Look for the warp zone under the bridge.
      EOS

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
        admonition_label_align: 'right',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      NOTE: Remember the milk.

      TIP: Look for the warp zone under the bridge.

      CAUTION: Slippery when wet.

      WARNING: Beware of dog!

      IMPORTANT: Sign off before stepping away from the computer.
      EOS

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
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_label_vertical_align: 'top' }, analyze: true
      [NOTE]
      ====
      There are lots of things you need to know.
      Then there are the things that you already know.
      And those things that you don't know that you do not know.
      This documentation seeks to close the gaps between them.
      ====
      EOS

      label_text = (pdf.find_text 'NOTE')[0]
      content_text = (pdf.find_text font_name: 'NotoSerif')[0]
      (expect label_text[:y]).to be > content_text[:y]
    end

    it 'should resolve character references in label' do
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_label_font_color: '000000' }, analyze: true
      [NOTE,caption=&#174;]
      ====
      Christoph and sons.
      ====
      EOS

      label_text = (pdf.find_text font_color: '000000')[0]
      (expect label_text[:string]).to eql ?\u00ae
      (expect label_text[:width]).to be < label_text[:font_size]
      (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    end
  end

  context 'Icon' do
    it 'should show font-based icon in place of label when icons=font' do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      TIP: Look for the warp zone under the bridge.
      EOS

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
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_important: { size: 50 } }, analyze: true
      :icons: font

      [IMPORTANT]
      ====
      Always do this.

      And when you do that, always do this too!
      ====
      EOS

      label_text = pdf.find_unique_text ?\uf06a
      (expect label_text[:font_size]).to eql 50
    end

    it 'should allow the theme to specify a minimum width for the font-based icon label' do
      pdf_theme = {
        admonition_label_min_width: '75',
        admonition_label_align: 'right',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      :icons: font

      NOTE: Remember the milk.

      TIP: Look for the warp zone under the bridge.

      CAUTION: Slippery when wet.

      WARNING: Beware of dog!

      IMPORTANT: Sign off before stepping away from the computer.
      EOS

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
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_label_vertical_align: 'top' }, analyze: true
      :icons: font

      [NOTE]
      ====
      There are lots of things you need to know.
      Then there are the things that you already know.
      And those things that you don't know that you do not know.
      This documentation seeks to close the gaps between them.
      ====
      EOS

      icon_text = (pdf.find_text ?\uf05a)[0]
      content_text = (pdf.find_text font_color: '333333')[1]
      (expect icon_text[:y]).to be > content_text[:y]
    end

    it 'should assume icon name with no icon set prefix is a legacy FontAwesome icon name' do
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_tip: { name: 'smile-wink' } }, analyze: true
      :icons: font

      TIP: Time to upgrade your icon set.
      EOS

      icon_text = pdf.text[0]
      (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      (expect icon_text[:string]).to eql ?\uf4da
    end

    it 'should be able to use fa- prefix to reference icon in legacy FontAwesome set' do
      (expect do
        pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_tip: { name: 'fa-smile-wink' } }, analyze: true
        :icons: font

        TIP: Time to upgrade your icon set.
        EOS

        icon_text = pdf.text[0]
        (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
        (expect icon_text[:string]).to eql ?\uf4da
      end).to log_message severity: :INFO, message: 'tip admonition in theme uses icon from deprecated fa icon set; use fas, far, or fab instead', using_log_level: :INFO
    end

    it 'should allow icon to come from Foundation icon set' do
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_warning: { name: 'fi-alert' } }, analyze: true
      :icons: font

      WARNING: Just don't do it.
      EOS

      icon_text = pdf.text[0]
      (expect icon_text[:font_name]).to eql 'fontcustom'
      (expect icon_text[:string]).to eql ?\uf101
    end

    it 'should fall back to note icon if icon name cannot be resolved' do
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_warning: { name: nil } }, analyze: true
      :icons: font

      WARNING: If the icon name is nil, the default note icon will be used.
      EOS

      icon_text = pdf.text[0]
      (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      (expect icon_text[:string]).to eql ?\uf05a
    end

    it 'should set color of icon to value of stroke_color key specified in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_note: { stroke_color: '00ff00' } }, analyze: true
      :icons: font

      NOTE: This icon is green.
      EOS

      icon_text = (pdf.find_text ?\uf05a)[0]
      (expect icon_text[:font_color]).to eql '00FF00'
    end

    it 'should use icon glyph specified in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_tip: { name: 'far-money-bill-alt' } }, analyze: true
      :icons: font

      TIP: Look for the warp zone under the bridge.
      EOS

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
      to_file = to_pdf_file <<~'EOS', 'admonition-custom-svg-icon.pdf', attribute_overrides: { 'docdir' => fixtures_dir }
      :icons: font
      :iconsdir:
      :icontype: svg

      [TIP,icon=square]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      EOS

      (expect to_file).to visually_match 'admonition-custom-svg-icon.pdf'
    end

    it 'should warn if SVG icon specified by icon attribute has errors' do
      (expect do
        pdf = to_pdf <<~'EOS', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: :rect
        :icons: font
        :icontype: svg

        [TIP,icon=faulty]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        EOS
        (expect pdf.rectangles).to have_size 1
        # NOTE: width and height of rectangle match what's defined in SVG
        (expect pdf.rectangles[0][:width]).to eql 200.0
        (expect pdf.rectangles[0][:height]).to eql 200.0
      end).to log_message severity: :WARN, message: %(~problem encountered in image: #{fixture_file 'faulty.svg'}; Unknown tag 'foobar')
    end

    it 'should warn if SVG icon specified by icon attribute cannot be embedded' do
      (expect do
        pdf = to_pdf <<~'EOS', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: :rect
        :icons: font
        :icontype: svg

        [TIP,icon=broken]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        EOS
        (expect pdf.rectangles).to be_empty
      end).to log_message severity: :WARN, message: %(~could not embed admonition icon: #{fixture_file 'broken.svg'}; Missing end tag for 'rect')
    end

    it 'should warn if raster icon specified by icon attribute cannot be embedded' do
      (expect do
        pdf = to_pdf <<~'EOS', attribute_overrides: { 'iconsdir' => fixtures_dir }, analyze: :image
        :icons:

        [TIP,icon=corrupt.png]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        EOS
        (expect pdf.images).to be_empty
      end).to log_message severity: :WARN, message: %(~could not embed admonition icon: #{fixture_file 'corrupt.png'}; image file is an unrecognised format)
    end

    it 'should embed remote image in icon if allow-uri-read attribute is set', visual: true do
      to_file = to_pdf_file <<~'EOS', 'admonition-custom-svg-icon-with-remote-image.pdf', attribute_overrides: { 'docdir' => fixtures_dir, 'allow-uri-read' => '' }
      :icons: font
      :iconsdir:

      [NOTE,icon=svg-with-remote-image.svg]
      ====
      AsciiDoc is awesome!
      ====
      EOS

      (expect to_file).to visually_match 'admonition-custom-svg-icon-with-remote-image.pdf'
    end

    it 'should use original width of SVG icon if height is less than height of admonition block', visual: true do
      to_file = to_pdf_file <<~'EOS', 'admonition-custom-svg-fit.pdf', attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :rect
      :icons: font
      :iconsdir:

      [NOTE,icon=green-bar.svg]
      ====
      When you see this icon, it means there's additional advice about passing tests.
      ====
      EOS

      (expect to_file).to visually_match 'admonition-custom-svg-fit.pdf'
    end

    it 'should use raster icon specified by icon attribute when icons attribute is set', visual: true do
      to_file = to_pdf_file <<~'EOS', 'admonition-custom-raster-icon.pdf', attribute_overrides: { 'docdir' => fixtures_dir }
      :icons: font
      :iconsdir:

      [TIP,icon=tux.png]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      EOS

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    # NOTE: this is a pretty flimsy feature and probably needs some rethink
    it 'should allow theme to control width of admonition icon image using admonition_label_min_width key' do
      pdf_theme = { admonition_label_min_width: 40 }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :image
      :icons: font
      :iconsdir:

      [TIP,icon=logo.png]
      ====
      Use the icon attribute to customize the image for an admonition block.

      Use the admonition_label_min_width key to control the image width.
      ====
      EOS

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to eql 40.0
    end

    it 'should resolve icon when icons attribute is set to image', visual: true do
      to_file = to_pdf_file <<~'EOS', 'admonition-image-icon.pdf', attribute_overrides: { 'docdir' => fixtures_dir }
      :icons: image
      :iconsdir:

      [TIP]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      EOS

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    it 'should not unset data-uri attribute when resolving icon image if already unset', visual: true do
      doc = Asciidoctor.load <<~'EOS', backend: :pdf, safe: :safe, standalone: true, attributes: { 'docdir' => fixtures_dir, 'nofooter' => '' }
      :icons: image
      :iconsdir:

      [TIP]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      EOS

      (expect doc.converter).not_to be_nil
      doc.remove_attr 'data-uri'
      to_file = File.join output_dir, 'admonition-image-icon-no-data-uri.pdf'
      doc.converter.write doc.convert, to_file

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    it 'should resolve remote icon when icons attribute is set to image and allow-uri-read is set', visual: true do
      to_file = with_local_webserver do |base_url|
        to_pdf_file <<~EOS, 'admonition-remote-image-icon.pdf', attribute_overrides: { 'allow-uri-read' => '', 'iconsdir' => base_url }
        :icons: image

        [TIP]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        EOS
      end

      (expect to_file).to visually_match 'admonition-custom-raster-icon.pdf'
    end

    it 'should resize icon only if it does not fit within the available space' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :image
      :icons: image
      :iconsdir:

      [TIP]
      This is Tux.
      He's the Linux mascot.
      EOS

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to be < 36.0
      (expect images[0][:height]).to be < 42.3529

      pdf = to_pdf <<~'EOS', attribute_overrides: { 'docdir' => fixtures_dir }, analyze: :image
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
      EOS

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to eql 36.0
      (expect images[0][:height]).to eql 42.3529
    end

    it 'should warn and fallback to admonition label if image icon cannot be resolved' do
      (expect do
        pdf = to_pdf <<~'EOS', attribute_overrides: { 'docdir' => fixtures_dir }, analyze: true
        :icons: image
        :iconsdir:

        [NOTE]
        ====
        Use the icon attribute to customize the image for an admonition block.
        ====
        EOS

        note_text = (pdf.find_text 'NOTE')[0]
        (expect note_text).not_to be_nil
        (expect note_text[:font_name]).to include 'Bold'
      end).to log_message severity: :WARN, message: '~admonition icon not found or not readable'
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

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, extensions: extensions, analyze: true
      :icons: font

      [QUESTION]
      ====
      Are you following along?

      Just checking ;)
      ====
      EOS

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

      pdf = to_pdf <<~'EOS', extensions: extensions, analyze: true
      :icons: font

      [FACT]
      ====
      Like all planetary bodies, the Earth is spherical.
      ====
      EOS

      (expect pdf.lines).to eql [%(\uf05a Like all planetary bodies, the Earth is spherical.)]
      icon_text = pdf.find_unique_text ?\uf05a
      (expect icon_text[:font_color]).to eql '333333'
    end
  end

  context 'Background & Lines' do
    it 'should allow theme to customize color, width, and style of column rule' do
      pdf_theme = {
        admonition_column_rule_color: '222222',
        admonition_column_rule_width: 2,
        admonition_column_rule_style: 'dotted',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      EOS

      lines = pdf.lines
      (expect lines).to have_size 1
      column_rule = lines[0]
      (expect column_rule[:from][:x]).to eql column_rule[:to][:x]
      (expect column_rule[:color]).to eql '222222'
      (expect column_rule[:width]).to eql 2
      (expect column_rule[:style]).to eql :dotted
    end

    it 'should use base border width for column rule if column rule width is nil' do
      pdf_theme = {
        base_border_width: 2,
        admonition_column_rule_color: '222222',
        admonition_column_rule_width: nil,
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to customize the color and width of the column rule.
      EOS

      lines = pdf.lines
      (expect lines).to have_size 1
      column_rule = lines[0]
      (expect column_rule[:from][:x]).to eql column_rule[:to][:x]
      (expect column_rule[:color]).to eql '222222'
      (expect column_rule[:width]).to eql 2
    end

    it 'should allow theme to add border', visual: true do
      pdf_theme = {
        admonition_border_width: 0.5,
        admonition_border_radius: 5,
        admonition_border_color: 'e0e0e0',
        admonition_column_rule_color: 'e0e0e0',
      }
      to_file = to_pdf_file <<~'EOS', 'admonition-border.pdf', pdf_theme: pdf_theme
      TIP: You can use the theme to add a border.
      EOS

      (expect to_file).to visually_match 'admonition-border.pdf'
    end

    it 'should allow theme to add background color', visual: true do
      pdf_theme = {
        admonition_background_color: 'eeeeee',
        admonition_border_radius: 3,
        admonition_column_rule_width: 0,
      }
      to_file = to_pdf_file <<~'EOS', 'admonition-background-color.pdf', pdf_theme: pdf_theme
      TIP: You can use the theme to add a background color.
      EOS

      (expect to_file).to visually_match 'admonition-background-color.pdf'
    end

    it 'should allow theme to disable column rule by setting color to nil' do
      pdf_theme = { admonition_column_rule_color: nil }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
      TIP: You can use the theme to add a background color.
      EOS

      (expect pdf.lines).to be_empty
    end
  end
end
