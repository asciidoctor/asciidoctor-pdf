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

  # TODO: this could use a deeper assertion
  it 'should compute width of label even when glyph is missing' do
    pdf = to_pdf <<~'EOS', analyze: true
    [NOTE,caption=⏻ Tip]
    Use bundler!
    EOS

    label_text = pdf.text[0]
    (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect label_text[:string]).to eql '⏻ TIP'
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

      icon_text = (pdf.find_text 'NOTE')[0]
      content_text = (pdf.find_text font_name: 'NotoSerif')[0]
      (expect icon_text[:y]).to be > content_text[:y]
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
      content_text = text[1]
      (expect content_text[:string]).to eql 'Look for the warp zone under the bridge.'
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

    it 'should allow icon to come from Foundation icon set' do
      pdf = to_pdf <<~'EOS', pdf_theme: { admonition_icon_warning: { name: 'fi-alert' } }, analyze: true
      :icons: font

      WARNING: Just don't do it.
      EOS

      icon_text = pdf.text[0]
      (expect icon_text[:font_name]).to eql 'fontcustom'
      (expect icon_text[:string]).to eql ?\uf101
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

      [TIP,icon=square.svg]
      ====
      Use the icon attribute to customize the image for an admonition block.
      ====
      EOS

      (expect to_file).to visually_match 'admonition-custom-svg-icon.pdf'
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
        admonition_icon_question: { name: 'question-circle', size: 20 },
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, extensions: extensions, analyze: true
      :icons: font

      [QUESTION]
      ====
      Are you following along?
      ====
      EOS

      icon_text = (pdf.find_text ?\uf059)[0]
      (expect icon_text).not_to be_nil
      (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      (expect icon_text[:font_size]).to be 20
      question_text = (pdf.find_text 'Are you following along?')
      (expect question_text).not_to be_nil
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
  end
end
