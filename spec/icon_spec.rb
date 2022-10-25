# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Icon' do
  it 'should display icon name if font-based icons are not enabled' do
    pdf = to_pdf 'I icon:heart[] AsciiDoc.', analyze: true
    (expect pdf.lines).to eql ['I [heart] AsciiDoc.']
  end

  it 'should read icon from image file when icons mode is image' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: :image
      :icons:
      :iconsdir: {imagesdir}

      Look for files with the icon:logo[] icon.
      EOS

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to eql 14.28
      (expect images[0][:x]).to be > 48.24
    end).to not_log_message
  end

  it 'should log warning if image file for icon not readable' do
    input = <<~'EOS'
    :icons:
    :icontype: svg

    I looked for icon:not-found[], but it was no where to be seen.
    EOS
    (expect do
      pdf = to_pdf input, analyze: :image
      images = pdf.images
      (expect images).to be_empty
    end).to log_message severity: :WARN, message: %(~image icon for 'not-found' not found or not readable: #{fixture_file 'icons/not-found.svg'})

    (expect do
      pdf = to_pdf input, analyze: true
      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql 'I looked for [not-found], but it was no where to be seen.'
    end).to log_message
  end

  it 'should use icon name from specified icon set' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font
    :icon-set: fas

    A icon:wrench[] ought to fix it.
    EOS
    wink_text = pdf.find_text ?\uf0ad
    (expect wink_text).to have_size 1
    (expect wink_text[0][:font_name]).to eql 'FontAwesome5Free-Solid'
  end

  it 'should support all available font-based icon sets' do
    supports_mdi = true unless (Gem::Version.new Prawn::Icon::VERSION) < (Gem::Version.new '3.1.0')
    [
      %W(fab twitter \uf099 FontAwesome5Brands-Regular),
      %W(far bell \uf0f3 FontAwesome5Free-Regular),
      %W(fas lock \uf023 FontAwesome5Free-Solid),
      %W(fi lock \uf16a fontcustom),
      %W(mdi alien \uf089 MaterialDesignIcons),
    ].each do |icon_set, icon_name, char_code, font_name|
      next if icon_set == 'mdi' && !supports_mdi
      pdf = to_pdf <<~EOS, analyze: true
      :icons: font
      :icon-set: #{icon_set}

      Look for the icon:#{icon_name}[] icon.
      EOS
      icon_text = pdf.text[1]
      (expect icon_text).not_to be_nil
      (expect icon_text[:string]).to eql char_code
      (expect icon_text[:font_name]).to eql font_name
    end
  end

  it 'should support icon set as suffix on icon name' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font

    A icon:wrench@fas[] ought to fix it.
    EOS
    wink_text = pdf.find_text ?\uf0ad
    (expect wink_text).to have_size 1
    (expect wink_text[0][:font_name]).to eql 'FontAwesome5Free-Solid'
  end

  it 'should support icon set as prefix on icon name' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font

    A icon:fas-wrench[] ought to fix it.
    EOS
    wink_text = pdf.find_text ?\uf0ad
    (expect wink_text).to have_size 1
    (expect wink_text[0][:font_name]).to eql 'FontAwesome5Free-Solid'
  end

  it 'should support icon set as prefix on icon name even if icon set is configured globally' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font
    :icon-set: fab

    A icon:fas-wrench[] ought to fix it.
    EOS
    wink_text = pdf.find_text ?\uf0ad
    (expect wink_text).to have_size 1
    (expect wink_text[0][:font_name]).to eql 'FontAwesome5Free-Solid'
  end

  it 'should not support icon set as prefix on icon name if explicit icon set is specified' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      A icon:fas-wrench[set=fab] ought to fix it.
      EOS
      wink_text = pdf.find_text ?\uf0ad
      (expect wink_text).to be_empty
    end).to log_message severity: :WARN, message: 'fas-wrench is not a valid icon name in the fab icon set'
  end

  it 'should apply larger font size to icon if size is lg' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font

    If the icon:wrench[] doesn't do it, try a icon:wrench[lg] one.
    EOS

    wrench_texts = pdf.find_text ?\uf0ad
    (expect wrench_texts).to have_size 2
    (expect wrench_texts[0][:font_size]).to eql 10.5
    (expect wrench_texts[0][:width]).to eql 10.5
    (expect wrench_texts[1][:font_size].round 2).to eql 14.0
    (expect wrench_texts[1][:width].round 2).to eql 14.0
  end

  it 'should apply specified custom font size to icon' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font

    I icon:fas-heart[1.2x] AsciiDoc
    EOS

    heart_text = pdf.find_unique_text ?\uf004
    (expect heart_text[:font_size]).to eql 12.6
  end

  it 'should use inherited size if font size is 1x' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font

    I icon:fas-heart[1x] AsciiDoc
    EOS

    heart_text = pdf.find_unique_text ?\uf004
    (expect heart_text[:font_size]).to eql pdf.text[0][:font_size]
  end

  it 'should reserve 1em of space for fw icon' do
    pdf = to_pdf <<~'EOS', analyze: true
    :icons: font
    :icon-set: fas

    *|* icon:arrows-alt-h[fw] *|* icon:arrows-alt-v[fw] *|*
    EOS
    guide_text = pdf.find_text '|', font_name: 'NotoSerif-Bold'
    first_icon_gap = (guide_text[1][:x] - guide_text[0][:x]).round 2
    second_icon_gap = (guide_text[2][:x] - guide_text[1][:x]).round 2
    (expect first_icon_gap).to eql second_icon_gap
  end

  it 'should align fw icon in center of 1em space', visual: true do
    to_file = to_pdf_file <<~'EOS', 'icon-fw.pdf'
    :icons: font
    :icon-set: fas

    *|* icon:arrows-alt-h[fw] *|* icon:arrows-alt-v[fw] *|*
    EOS
    (expect to_file).to visually_match 'icon-fw.pdf'
  end

  it 'should use icon name as alt text and warn if icon name not found in icon set' do
    [
      ['icon:no-such-icon[set=fas]', 'no such icon'],
      ['icon:no-such-icon@fas[]', 'no such icon@fas'],
      ['icon:fas-no-such-icon[]', 'fas no such icon'],
    ].each do |macro, alt|
      (expect do
        pdf = to_pdf <<~EOS, analyze: true
        :icons: font

        #{macro} will surely fail.
        EOS
        text = pdf.text
        (expect text).to have_size 1
        (expect text[0][:string]).to eql %([#{alt}] will surely fail.)
      end).to log_message severity: :WARN, message: 'no-such-icon is not a valid icon name in the fas icon set'
    end
  end

  it 'should remap legacy icon name if icon set is not specified and report remapping' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      Click the icon:hdd-o[] icon to see your files.
      EOS
      hdd_text = pdf.find_text ?\uf0a0
      (expect hdd_text).to have_size 1
      (expect hdd_text[0][:font_name]).to eql 'FontAwesome5Free-Regular'
    end).to log_message severity: :INFO, message: 'hdd-o icon found in deprecated fa icon set; using hdd from far icon set instead', using_log_level: :INFO
  end

  it 'should resolve non-legacy icon name if icon set is not specified and report icon set in which it was found' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      Time to upgrade your icon set icon:smile-wink[]
      EOS
      wink_text = pdf.find_text ?\uf4da
      (expect wink_text).to have_size 1
      (expect wink_text[0][:font_name]).to eql 'FontAwesome5Free-Regular'
    end).to log_message severity: :INFO, message: 'smile-wink icon not found in deprecated fa icon set; using match found in far icon set instead', using_log_level: :INFO
  end

  it 'should apply link to icon if link attribute is set and font-based icons are enabled' do
    input = <<~'EOS'
    :icons: font

    gem icon:download[link=https://rubygems.org/downloads/asciidoctor-pdf-1.5.4.gem, window=_blank]
    EOS

    pdf = to_pdf input
    annotations = get_annotations pdf, 1
    (expect annotations).to have_size 1
    link_annotation = annotations[0]
    (expect link_annotation[:Subtype]).to be :Link
    (expect link_annotation[:A][:URI]).to eql 'https://rubygems.org/downloads/asciidoctor-pdf-1.5.4.gem'

    pdf = to_pdf input, analyze: true
    link_text = (pdf.find_text ?\uf019)[0]
    (expect link_text).not_to be_nil
    (expect link_text[:font_name]).to eql 'FontAwesome5Free-Solid'
    (expect link_text[:font_color]).to eql '428BCA'
    link_text[:font_size] -= 1.5 # box appox is a little off
    (expect link_annotation).to annotate link_text
  end

  it 'should apply link to alt text if link attribute is set and font-based icons are not enabled' do
    input = <<~'EOS'
    gem icon:download[link=https://rubygems.org/downloads/asciidoctor-pdf-1.5.4.gem, window=_blank]
    EOS

    pdf = to_pdf input
    annotations = get_annotations pdf, 1
    (expect annotations).to have_size 1
    link_annotation = annotations[0]
    (expect link_annotation[:Subtype]).to be :Link
    (expect link_annotation[:A][:URI]).to eql 'https://rubygems.org/downloads/asciidoctor-pdf-1.5.4.gem'

    pdf = to_pdf input, analyze: true
    link_text = (pdf.find_text '[download]')[0]
    (expect link_text).not_to be_nil
    (expect link_text[:font_color]).to eql '428BCA'
    (expect link_annotation).to annotate link_text
  end

  it 'should apply styles from role to icon' do
    pdf = to_pdf <<~'EOS', pdf_theme: { role_red_font_color: 'FF0000' }, analyze: true
    :icons: font

    icon:heart[role=red]
    EOS

    heart_text = pdf.text[0]
    (expect heart_text[:string]).to eql ?\uf004
    (expect heart_text[:font_name]).to eql 'FontAwesome5Free-Regular'
    (expect heart_text[:font_color]).to eql 'FF0000'
  end

  it 'should parse icon inside kbd macro' do
    pdf = to_pdf <<~'EOS', analyze: true
    :experimental:
    :icons: font
    :icon-set: fas

    Press kbd:[Alt,icon:arrow-up[\]] to move the line up.
    EOS

    keyseq_text = pdf.text.find_all {|candidate| ['Alt', %(\u202f+\u202f), ?\uf062].include? candidate[:string] }
    (expect keyseq_text.size).to be 3
    (expect keyseq_text[0][:string]).to eql 'Alt'
    (expect keyseq_text[0][:font_name]).to eql 'mplus1mn-regular'
    (expect keyseq_text[1][:string]).to eql %(\u202f+\u202f)
    (expect keyseq_text[2][:string]).to eql ?\uf062
    (expect keyseq_text[2][:font_name]).to eql 'FontAwesome5Free-Solid'
  end
end
