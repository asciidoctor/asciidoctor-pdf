require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Image' do
  context 'imagesdir' do
    it 'should resolve target of block image relative to imagesdir', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-wolpertinger.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[pdfwidth=25%]
      EOS

      (expect to_file).to visually_match 'image-wolpertinger.pdf'
    end

    it 'should replace block image with alt text if image is missing' do
      with_memory_logger do |logger|
        pdf = to_pdf <<~'EOS', analyze: true
        image::no-such-image.png[Missing Image]
        EOS

        (expect pdf.lines).to eql ['[Missing Image] | no-such-image.png']
        if logger
          (expect logger.messages.size).to eql 1
          (expect logger.messages[0][:severity]).to eql :WARN
          (expect logger.messages[0][:message]).to include 'image to embed not found or not readable'
        end
      end
    end

    it 'should resolve target of inline image relative to imagesdir', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image:sample-logo.jpg[ACME,12] ACME products are the best!
      EOS

      (expect to_file).to visually_match 'image-inline.pdf'
    end

    it 'should replace inline image with alt text if image is missing' do
      with_memory_logger do |logger|
        pdf = to_pdf <<~'EOS', analyze: true
        You cannot see that which is image:not-there.png[not there].
        EOS

        (expect pdf.lines).to eql ['You cannot see that which is [not there].']
        if logger
          (expect logger.messages.size).to eql 1
          (expect logger.messages[0][:severity]).to eql :WARN
          (expect logger.messages[0][:message]).to include 'image to embed not found or not readable'
        end
      end
    end
  end

  context 'SVG' do
    it 'should not leave gap around SVG that specifies viewBox but no width' do
      input = <<~'EOS'
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::viewbox-only.svg[]

      after
      EOS

      pdf = to_pdf input, analyze: :rect
      (expect pdf.rectangles.size).to eql 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, analyze: true
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

      pdf = to_pdf input, analyze: :rect
      (expect pdf.rectangles.size).to eql 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text.size).to eql 1
      (expect text[0][:string]).to eql 'after'
      (expect text[0][:y]).to eql 276.036
    end
  end

  context 'PNG' do
    it 'should scale image to width of page when pdfwidth=100vw and align-to-page option is set', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-full-width.pdf'
      image::square.png[pdfwidth=100vw,opts=align-to-page]
      EOS

      (expect to_file).to visually_match 'image-full-width.pdf'
    end
  end

  context 'BMP' do
    it 'should warn and replace block image with alt text if image format is unsupported' do
      with_memory_logger do |logger|
        pdf = to_pdf <<~'EOS', analyze: true
        image::waterfall.bmp[Waterfall,240]
        EOS

        (expect pdf.lines).to eql ['[Waterfall] | waterfall.bmp']
        if logger
          (expect logger.messages.size).to eql 1
          (expect logger.messages[0][:severity]).to eql :WARN
          (expect logger.messages[0][:message]).to include 'could not embed image'
        end
      end
    end
  end
end
