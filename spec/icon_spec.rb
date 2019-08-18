require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Icon' do
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

  it 'should use icon name as alt text and warn if icon name not found in icon set' do
    (expect {
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font
      :icon-set: fas

      icon:no-such-icon[] will surely fail.
      EOS
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql '[no such icon] will surely fail.'
    }).to log_message severity: :WARN, message: 'no-such-icon is not a valid icon name in the fas icon set'
  end

  it 'should remap legacy icon name if icon set is not specified and report remapping' do
    (expect {
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      Click the icon:hdd-o[] icon to see your files.
      EOS
      hdd_text = pdf.find_text ?\uf0a0
      (expect hdd_text).to have_size 1
      (expect hdd_text[0][:font_name]).to eql 'FontAwesome5Free-Regular'
    }).to log_message severity: :INFO, message: 'hdd-o icon found in deprecated fa icon set; using hdd from far icon set instead', using_log_level: :INFO
  end

  it 'should resolve non-legacy icon name if icon set is not specified and report icon set in which it was found' do
    (expect {
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      Time to upgrade your icon set icon:smile-wink[]
      EOS
      wink_text = pdf.find_text ?\uf4da
      (expect wink_text).to have_size 1
      (expect wink_text[0][:font_name]).to eql 'FontAwesome5Free-Regular'
    }).to log_message severity: :INFO, message: 'smile-wink icon not found in deprecated fa icon set; using match found in far icon set instead', using_log_level: :INFO
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
    (expect keyseq_text.size).to eql 3
    (expect keyseq_text[0][:string]).to eql 'Alt'
    (expect keyseq_text[0][:font_name]).to eql 'mplus1mn-regular'
    (expect keyseq_text[1][:string]).to eql %(\u202f+\u202f)
    (expect keyseq_text[2][:string]).to eql ?\uf062
    (expect keyseq_text[2][:font_name]).to eql 'FontAwesome5Free-Solid'
  end
end
