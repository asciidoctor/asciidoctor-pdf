require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Admonition' do
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
  end
end
