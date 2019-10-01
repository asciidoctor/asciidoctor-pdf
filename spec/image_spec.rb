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

    it 'should warn instead of crash if block image is unreadable' do
      image_file = fixture_file 'logo.png'
      old_mode = (File.stat image_file).mode
      begin
        (expect {
          FileUtils.chmod 0000, image_file
          pdf = to_pdf 'image::logo.png[Unreadable Image]', analyze: true
          (expect pdf.lines).to eql ['[Unreadable Image] | logo.png']
        }).to log_message severity: :WARN, message: '~image to embed not found or not readable'
      ensure
        FileUtils.chmod old_mode, image_file
      end
    end unless windows?

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

    it 'should respect value of imagesdir if changed mid-document' do
      pdf = to_pdf <<~EOS, attributes: { 'nofooter' => '' }
      :imagesdir: #{fixtures_dir}

      image::tux.png[tux]

      :imagesdir: #{examples_dir}

      image::wolpertinger.jpg[wolpertinger]
      EOS

      (expect get_images pdf).to have_size 2
    end

    it 'should warn instead of crash if inline image is unreadable' do
      image_file = fixture_file 'logo.png'
      old_mode = (File.stat image_file).mode
      begin
        (expect {
          FileUtils.chmod 0000, image_file
          pdf = to_pdf 'image:logo.png[Unreadable Image,16] Company Name', analyze: true
          (expect pdf.lines).to eql ['[Unreadable Image] Company Name']
        }).to log_message severity: :WARN, message: '~image to embed not found or not readable'
      ensure
        FileUtils.chmod old_mode, image_file
      end
    end unless windows?
  end

  context 'Alignment' do
    it 'should not crash when converting block image if theme is blank' do
      image_data = File.binread example_file 'wolpertinger.jpg'
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => (fixture_file 'extends-nil-empty-theme.yml'), 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[]
      EOS
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].data).to eql image_data
    end

    it 'should align block image to value of align attribute on macro', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-align-right-attribute.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[align=right]
      EOS
      
      (expect to_file).to visually_match 'image-align-right.pdf'
    end

    it 'should align block image to value of image_align key in theme if alignment not specified on image', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-align-right-theme.pdf', pdf_theme: { image_align: 'right' }, attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[]
      EOS
      
      (expect to_file).to visually_match 'image-align-right.pdf'
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

    it 'should replace unrecognized font family with base font family' do
      pdf = to_pdf <<~'EOS', analyze: true
      image::svg-with-text.svg[]
      EOS

      text = pdf.find_text 'This text uses the default SVG font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'NotoSerif'
      (expect text[0][:font_size]).to eql 12.0
    end

    it 'should replace unrecognized font family with svg font family if specified in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { svg_fallback_font_family: 'Times-Roman' }, analyze: true
      image::svg-with-text.svg[pdfwidth=100%]
      EOS

      text = pdf.find_text 'This text uses the default SVG font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'Times-Roman'
      (expect text[0][:font_size]).to eql 12.0
    end

    it 'should embed local image', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-local-image.pdf'
      A sign of a good writer: image:svg-with-local-image.svg[]
      EOS

      (expect to_file).to visually_match 'image-svg-with-image.pdf'
    end

    it 'should embed remote image if allow allow-uri-read attribute is set', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-remote-image.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      A sign of a good writer: image:svg-with-remote-image.svg[]
      EOS

      (expect to_file).to visually_match 'image-svg-with-image.pdf'
    end

    it 'should not embed remote image if allow allow-uri-read attribute is not set', integration: true do
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

    it 'should scale down image if height exceeds available space' do
      to_file = to_pdf_file <<~'EOS', 'image-png-scale-to-fit.pdf'
      :pdf-page-layout: landscape

      image::tux.png[pdfwidth=100%]
      EOS

      (expect to_file).to visually_match 'image-png-scale-to-fit.pdf'
    end

    it 'should use the numeric width defined in the theme if an explicit width is not specified', integration: true do
      [72, '72'].each do |image_width|
        to_file = to_pdf_file <<~'EOS', 'image-numeric-fallback-width.pdf', pdf_theme: { image_width: image_width }
        image::tux.png[pdfwidth=204px]

        image::tux.png[,204]

        image::tux.png[]
        EOS

        (expect to_file).to visually_match 'image-numeric-fallback-width.pdf'
      end
    end

    it 'should use the percentage width defined in the theme if an explicit width is not specified', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-percentage-fallback-width.pdf', pdf_theme: { image_width: '50%' }
      image::tux.png[]
      EOS

      (expect to_file).to visually_match 'image-percentage-fallback-width.pdf'
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
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'nofooter' => nil }, analyze: true
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

    it 'should replace empty page at location of block macro if target is a PDF' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'nofooter' => nil }, analyze: true
      :page-background-image: image:bg.png[]

      before

      <<<

      image::blue-letter.pdf[]

      <<<

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

    it 'should only import first page of multi-page PDF file by default' do
      pdf = to_pdf 'image::red-green-blue.pdf[]'
      (expect pdf.pages).to have_size 1
      page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '1.0 0.0 0.0 scn']
    end

    it 'should import specified page from PDF file' do
      pdf = to_pdf 'image::red-green-blue.pdf[page=2]'
      (expect pdf.pages).to have_size 1
      page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 1.0 0.0 scn']
    end

    it 'should not insert blank page between consecutive PDF page imports' do
      pdf = to_pdf <<~'EOS'
      image::red-green-blue.pdf[page=1]
      image::red-green-blue.pdf[page=2]
      EOS
      (expect pdf.pages).to have_size 2
      p1_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (p1_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '1.0 0.0 0.0 scn']
      p2_contents = pdf.objects[(pdf.page 2).page_object[:Contents][0]].data
      (expect (p2_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 1.0 0.0 scn']
    end
  end

  context 'Data URI' do
    it 'should embed block image if target is a JPG data URI' do
      image_data = File.binread fixture_file 'square.jpg'
      encoded_image_data = Base64.strict_encode64 image_data
      pdf = to_pdf %(image::data:image/jpg;base64,#{encoded_image_data}[])
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to eql 5
      (expect images[0].hash[:Height]).to eql 5
      (expect images[0].data).to eql image_data
    end

    it 'should embed inline image if target is a JPG data URI' do
      image_data = File.binread fixture_file 'square.jpg'
      encoded_image_data = Base64.strict_encode64 image_data
      pdf = to_pdf %(image:data:image/jpg;base64,#{encoded_image_data}[] base64)
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to eql 5
      (expect images[0].hash[:Height]).to eql 5
      (expect images[0].data).to eql image_data
    end
  end

  context 'allow-uri-read' do
    it 'should warn if image is remote and allow-uri-read is not set' do
      (expect {
        pdf = to_pdf 'image::https://raw.githubusercontent.com/asciidoctor/asciidoctor-pdf/master/spec/fixtures/logo.png[Remote Image]', analyze: true
        (expect pdf.lines).to eql ['[Remote Image] | https://raw.githubusercontent.com/asciidoctor/asciidoctor-pdf/master/spec/fixtures/logo.png']
      }).to log_message severity: :WARN, message: '~allow-uri-read is not enabled; cannot embed remote image'
    end

    it 'should read remote image if allow-uri-read is set' do
      pdf = to_pdf 'image::https://raw.githubusercontent.com/asciidoctor/asciidoctor-pdf/master/spec/fixtures/logo.png[Remote Image]', attribute_overrides: { 'allow-uri-read' => '' }
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect (pdf.page 1).text).to be_empty
    end

    it 'should use image format specified by format attribute' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'allow-uri-read' => '' }, analyze: :rect
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::https://raw.githubusercontent.com/asciidoctor/asciidoctor-pdf/master/spec/fixtures/square.svg?v=1[format=svg,pdfwidth=100%]
      EOS
      (expect pdf.rectangles).to have_size 1
      rect = pdf.rectangles[0]
      (expect rect[:point]).to eql [0.0, 200.0]
      (expect rect[:width]).to eql 200.0
      (expect rect[:height]).to eql 200.0
    end
  end

  context 'Inline' do
    it 'should convert multiple images on the same line', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-multiple-inline.pdf'
      image:logo.png[Asciidoctor,12] is developed on image:tux.png[Linux,12].
      EOS

      (expect to_file).to visually_match 'image-multiple-inline.pdf'
    end

    it 'should increase line height if height if image height is more than 1.5x line height', integration: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline-extends-line-height.pdf'
      see tux run +
      see image:tux.png[tux] run +
      see tux run
      EOS

      (expect to_file).to visually_match 'image-inline-extends-line-height.pdf'
    end

    it 'should not increase line height if image height does not exceed 1.5x line height', integration: true do
      pdf = to_pdf <<~'EOS', analyze: true
      see tux run +
      see tux run +
      see image:tux.png[tux,24] run
      EOS

      text = pdf.text
      line1_spacing = (text[0][:y] - text[1][:y]).round 2
      line2_spacing = (text[1][:y] - text[2][:y]).round 2
      (expect line1_spacing).to eql line2_spacing
    end
  end

  context 'Link' do
    it 'should add link around block raster image if link attribute is set' do
      pdf = to_pdf <<~'EOS'
      image::tux.png[pdfwidth=1in,link=https://www.linuxfoundation.org/projects/linux/]
      EOS

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to eql :Link
      (expect link_annotation[:A][:URI]).to eql 'https://www.linuxfoundation.org/projects/linux/'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 72.0
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 84.7
      (expect link_rect[0]).to eql 48.24
    end

    it 'should add link around block SVG image if link attribute is set' do
      pdf = to_pdf <<~'EOS'
      image::square.svg[pdfwidth=1in,link=https://example.org]
      EOS

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to eql :Link
      (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 72.0
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 72.0
      (expect link_rect[0]).to eql 48.24
    end

    it 'should add link around inline image if link attribute is set' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'imagesdir' => examples_dir }
      image:sample-logo.jpg[ACME,pdfwidth=12pt,link=https://example.org] is a sign of quality!
      EOS

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to eql :Link
      (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 12.0
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 14.3
      (expect link_rect[0]).to eql 48.24
    end
  end

  context 'Border' do
    it 'should draw border around PNG image if border width and border color are set in the theme', integration: true do
      pdf_theme = {
        image_border_width: 0.5,
        image_border_color: 'DDDDDD',
        image_border_radius: 2,
      }

      to_file = to_pdf_file <<~'EOS', 'image-border.pdf', pdf_theme: pdf_theme
      .Tux
      image::tux.png[align=center]
      EOS

      (expect to_file).to visually_match 'image-border.pdf'
    end

    it 'should stretch border around PNG image to bounds if border align key is justify', integration: true do
      pdf_theme = {
        image_border_width: 0.5,
        image_border_color: 'DDDDDD',
        image_border_radius: 2,
        image_border_fit: 'auto',
      }

      to_file = to_pdf_file <<~'EOS', 'image-border-fit-page.pdf', pdf_theme: pdf_theme
      .Tux
      image::tux.png[align=center]
      EOS

      (expect to_file).to visually_match 'image-border-fit-page.pdf'
    end

    it 'should draw border around SVG if border width and border color are set in the theme', integration: true do
      pdf_theme = {
        image_border_width: 1,
        image_border_color: '000000',
      }

      to_file = to_pdf_file <<~'EOS', 'image-svg-border.pdf', pdf_theme: pdf_theme
      .Square
      image::square.svg[align=center,pdfwidth=25%]
      EOS

      (expect to_file).to visually_match 'image-svg-border.pdf'
    end

    it 'should stretch border around SVG to bounds if border align key is justify', integration: true do
      pdf_theme = {
        image_border_width: 1,
        image_border_color: '000000',
        image_border_fit: 'auto',
      }

      to_file = to_pdf_file <<~'EOS', 'image-svg-border-fit-page.pdf', pdf_theme: pdf_theme
      .Square
      image::square.svg[align=center,pdfwidth=25%]
      EOS

      (expect to_file).to visually_match 'image-svg-border-fit-page.pdf'
    end

    it 'should not draw border around image if noborder role is present', integration: true do
      pdf_theme = {
        image_border_width: 1,
        image_border_color: '000000',
      }
      to_file = to_pdf_file <<~'EOS', 'image-noborder.pdf', pdf_theme: pdf_theme, attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[pdfwidth=25%,role=specimen noborder]
      EOS

      (expect to_file).to visually_match 'image-wolpertinger.pdf'
    end
  end
end
