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
      (expect {
        pdf = to_pdf 'image::no-such-image.png[Missing Image]', analyze: true
        (expect pdf.lines).to eql ['[Missing Image] | no-such-image.png']
      }).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end

    it 'should resolve target of inline image relative to imagesdir', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image:sample-logo.jpg[ACME,12] ACME products are the best!
      EOS

      (expect to_file).to visually_match 'image-inline.pdf'
    end

    it 'should replace inline image with alt text if image is missing' do
      (expect {
        pdf = to_pdf 'You cannot see that which is image:not-there.png[not there].', analyze: true
        (expect pdf.lines).to eql ['You cannot see that which is [not there].']
      }).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end
  end

  context 'SVG' do
    it 'should not leave gap around SVG that specifies viewBox but no width' do
      input = <<~'EOS'
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::square-viewbox-only.svg[]

      after
      EOS

      pdf = to_pdf input, analyze: :rect
      (expect pdf.rectangles).to have_size 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'after'
      (expect text[0][:y]).to eql 176.036
    end

    it 'should not leave gap around constrained SVG that specifies viewBox but no width' do
      input = <<~'EOS'
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::square-viewbox-only.svg[pdfwidth=50%]

      after
      EOS

      pdf = to_pdf input, analyze: :rect
      (expect pdf.rectangles).to have_size 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'after'
      (expect text[0][:y]).to eql 276.036
    end

    it 'should embed local image' do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-local-image.pdf'
      A sign of a good writer: image:svg-with-local-image.svg[]
      EOS

      (expect to_file).to visually_match 'image-svg-with-image.pdf'
    end

    it 'should embed remote image if allow allow-uri-read attribute is set' do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-remote-image.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      A sign of a good writer: image:svg-with-remote-image.svg[]
      EOS

      (expect to_file).to visually_match 'image-svg-with-image.pdf'
    end

    it 'should not embed remote image if allow allow-uri-read attribute is not set' do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-remote-image-disabled.pdf'
      A sign of a good writer: image:svg-with-remote-image.svg[]
      EOS

      (expect to_file).to visually_match 'image-svg-with-missing-image.pdf'
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
      (expect {
        pdf = to_pdf 'image::waterfall.bmp[Waterfall,240]', analyze: true
        (expect pdf.lines).to eql ['[Waterfall] | waterfall.bmp']
      }).to log_message severity: :WARN, message: '~could not embed image'
    end
  end

  context 'PDF' do
    it 'should insert page at location of block macro if target is a PDF' do
      pdf = to_pdf <<~'EOS', attributes: { 'imagesdir' => fixtures_dir }, analyze: true
      before

      image::blue-letter.pdf[]

      after
      EOS

      pages = pdf.pages
      (expect pages).to have_size 3
      (expect pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
      (expect pages[0][:text][-1][:string]).to eql '1'
      (expect pages[1][:size]).to eql PDF::Core::PageGeometry::SIZES['LETTER']
      # NOTE no running content on imported pages
      (expect pages[1][:text]).to be_empty
      (expect pages[2][:text][-1][:string]).to eql '3'
    end
  end
end
