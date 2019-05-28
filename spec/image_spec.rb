require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Image' do
  context 'SVG' do
    it 'should not leave gap around SVG that specifies viewBox but no width' do
      input = <<~'EOS'
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::viewbox-only.svg[]

      after
      EOS

      pdf = to_pdf input, attributes: { 'imagesdir' => fixtures_dir, 'nofooter' => '' }, analyze: :rect
      (expect pdf.rectangles.size).to eql 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, attributes: { 'imagesdir' => fixtures_dir, 'nofooter' => '' }, analyze: true
      text = pdf.text
      (expect text.size).to eql 1
      (expect text[0][:string]).to eql 'after'
      (expect text[0][:y]).to eql 176.036
    end

    it 'should not leave gap around constrained SVG that specifies viewBox but no width' do
      input = <<~'EOS'
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::viewbox-only.svg[pdfwidth=50%]

      after
      EOS

      pdf = to_pdf input, attributes: { 'imagesdir' => fixtures_dir, 'nofooter' => '' }, analyze: :rect
      (expect pdf.rectangles.size).to eql 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, attributes: { 'imagesdir' => fixtures_dir, 'nofooter' => '' }, analyze: true
      text = pdf.text
      (expect text.size).to eql 1
      (expect text[0][:string]).to eql 'after'
      (expect text[0][:y]).to eql 276.036
    end
  end

  context 'PNG' do
    it 'should scale image to width of page when pdfwidth=100vw and align-to-page option is set', integration: true do
      to_file = to_pdf_file <<~'EOS', 'images-full-width.pdf', attributes: { 'imagesdir' => fixtures_dir, 'nofooter' => '' }
      image::square.png[pdfwidth=100vw,opts=align-to-page]
      EOS

      (expect to_file).to visually_match 'images-full-width.pdf'
    end
  end
end
