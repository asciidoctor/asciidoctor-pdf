# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Icon' do
  it 'should display icon name if font-based icons are not set' do
    pdf = to_pdf 'I icon:heart[] AsciiDoc.', analyze: true
    (expect pdf.lines).to eql ['I [heart] AsciiDoc.']
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
