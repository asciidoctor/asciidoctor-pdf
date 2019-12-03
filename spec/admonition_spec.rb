require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Admonition' do
  it 'should advance block to next page to avoid splitting it if it will fit' do
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

  context 'Text' do
    it 'should show bold admonition label by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      TIP: Look for the warp zone under the bridge.
      EOS

      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql 'TIPLook for the warp zone under the bridge.'
      text = pdf.text
      (expect text).to have_size 2
      label_text = text[0]
      (expect label_text[:string]).to eql 'TIP'
      (expect label_text[:font_name]).to eql 'NotoSerif-Bold'
      content_text = text[1]
      (expect content_text[:string]).to eql 'Look for the warp zone under the bridge.'
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
      (expect lines[0]).to eql %(\uf0ebLook for the warp zone under the bridge.)
      text = pdf.text
      (expect text).to have_size 2
      label_text = text[0]
      (expect label_text[:string]).to eql ?\uf0eb
      (expect label_text[:font_name]).to eql 'FontAwesome5Free-Regular'
      content_text = text[1]
      (expect content_text[:string]).to eql 'Look for the warp zone under the bridge.'
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
      (expect lines[0]).to eql %(\uf3d1Look for the warp zone under the bridge.)
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
      (expect icon_text[:font_size]).to eql 20
      question_text = (pdf.find_text 'Are you following along?')
      (expect question_text).not_to be_nil
    end
  end
end
