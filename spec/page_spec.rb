require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Page' do
  context 'Size' do
    it 'should set page size specified by theme by default' do
      pdf = to_pdf <<~'EOS', analyze: :page
      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should set page size specified by pdf-page-size attribute using predefined name' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: Letter

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in pt' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: [600, 800]

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size]).to eql [600.0, 800.0]
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in in' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: [8.5in, 11in]

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end

    it 'should set page size specified by pdf-page-size attribute using dimension string in in' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: 8.5in x 11in

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end
  end

  context 'Layout' do
    it 'should use layout specified in theme by default' do
      pdf = to_pdf <<~'EOS'
      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0].orientation).to eql 'portrait'
    end

    it 'should use layout specified by pdf-page-layout attribute' do
      pdf = to_pdf <<~'EOS'
      :pdf-page-layout: landscape

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0].orientation).to eql 'landscape'
    end
  end

  context 'Initial Zoom' do
    it 'should set initial zoom to FitH by default' do
      pdf = to_pdf 'content'
      open_action = pdf.catalog[:OpenAction]
      (expect open_action).not_to be_nil
      (expect open_action).to have_size 3
      (expect pdf.objects[open_action[0]]).to eql (pdf.page 1).page_object
      (expect open_action[1]).to eql :FitH
      (expect open_action[2]).to eql (get_page_size pdf, 1)[1]
    end

    it 'should set initial zoom as specified by theme' do
      pdf = to_pdf 'content', pdf_theme: { page_initial_zoom: 'Fit' }
      open_action = pdf.catalog[:OpenAction]
      (expect open_action).not_to be_nil
      (expect open_action).to have_size 2
      (expect pdf.objects[open_action[0]]).to eql (pdf.page 1).page_object
      (expect open_action[1]).to eql :Fit
    end
  end

  context 'Margin' do
    it 'should use the margin specified in theme by default' do
      input = 'content'
      prawn = to_pdf input, analyze: :document
      pdf = to_pdf input, analyze: true

      (expect prawn.page_margin).to eql [36, 48.24, 48.24, 48.24]
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 48.24, 793.926]
    end

    it 'should use the margin specified by the pdf-page-margin attribute as array' do
      pdf = to_pdf <<~'EOS', analyze: true
      :pdf-page-margin: [0, 0, 0, 0]

      content
      EOS
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 0.0, 829.926]
    end

    it 'should use the margin specified by the pdf-page-margin attribute as string' do
      pdf = to_pdf <<~'EOS', analyze: true
      :pdf-page-margin: 1in

      content
      EOS
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 72.0, 757.926]
    end
  end

  context 'Background' do
    it 'should set page background color specified by page_background_color key in theme', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-color.pdf', pdf_theme: { page_background_color: 'ECFBF4' }
      = Document Title
      :doctype: book

      content
      EOS

      (expect to_file).to visually_match 'page-background-color.pdf'
    end

    it 'should set the background image using target of macro specified in page-background-image attribute', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-inline-macro.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:bg.png[]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should allow both background color and image to be set concurrently' do
      pdf_theme = {
        page_background_color: 'F9F9F9',
        page_background_image: %(image:#{fixture_file 'tux.png'}[pdfwidth=50%]),
      }
      to_file = to_pdf_file '{blank}', 'page-background-color-and-image.pdf', pdf_theme: pdf_theme

      (expect to_file).to visually_match 'page-background-color-and-image.pdf'
    end

    it 'should resolve attribute reference in image path in theme' do
      pdf_theme = {
        page_background_color: 'F9F9F9',
        page_background_image: 'image:{docdir}/tux.png[pdfwidth=50%]',
      }
      to_file = to_pdf_file '{blank}', 'page-background-color-and-image-relative-to-docdir.pdf', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }

      (expect to_file).to visually_match 'page-background-color-and-image.pdf'
    end

    it 'should recognize attribute value that use block macro syntax', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-block-macro.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:bg.png[]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should not crash if background image is a URI and the allow-uri-read attribute is not set' do
      (expect {
        to_pdf <<~'EOS'
        = Document Title
        :page-background-image: image:https://example.org/bg.svg[]

        content
        EOS
      }).to not_raise_exception & (log_message severity: :WARN, message: '~allow-uri-read is not enabled')
    end

    it 'should set the background image using path specified in page-background-image attribute', integration: true do
      to_file = to_pdf_file <<~EOS, 'page-background-image-path.pdf'
      = Document Title
      :doctype: book
      :page-background-image: #{fixture_file 'bg.png', relative: true}

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should scale background image until it reaches shortest side', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-max-height.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:square.png[]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-max-height.pdf'
    end

    it 'should set width of background image according to width attribute', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-width.pdf'
      = Document Title
      :page-background-image: image:square.png[bg,200]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-width.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if value is path', integration: true do
      to_file = to_pdf_file <<~EOS, 'page-background-image-svg-scale-up-from-path.pdf'
      = Document Title
      :page-background-image: #{fixture_file 'square.svg', relative: true}

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if value is macro', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-scale-up-from-macro.pdf'
      = Document Title
      :page-background-image: image:square.svg[]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if fit is contain', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-contain.pdf'
      = Document Title
      :page-background-image: image:square.svg[fit=contain]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if pdfwidth is 100%', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-pdfwidth.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:square.svg[pdfwidth=100%]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-contain.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if value is path', integration: true do
      to_file = to_pdf_file <<~EOS, 'page-background-image-svg-scale-down-from-path.pdf'
      = Document Title
      :page-background-image: #{fixture_file 'example-watermark.svg', relative: true}

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if value is macro', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-scale-down-from-macro.pdf'
      = Document Title
      :page-background-image: image:example-watermark.svg[]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if fit is scale-down', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-scale-down.pdf'
      = Document Title
      :page-background-image: image:example-watermark.svg[fit=scale-down]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should not scale background SVG with explicit width to fit boundaries of page if fit is scale-down and image fits', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-prescaled.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:green-bar.svg[pdfwidth=50%,fit=scale-down]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-prescaled.pdf'
    end

    it 'should not scale background SVG to fit boundaries of page if fit is none', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-none.pdf'
      = Document Title
      :page-background-image: image:example-watermark.svg[fit=none]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-unscaled.pdf'
    end

    it 'should scale up background SVG until it covers page if fit=cover', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-cover.pdf'
      = Document Title
      :page-background-image: image:square.svg[fit=cover]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-cover.pdf'
    end

    it 'should allow remote image in SVG to be read if allow-uri-read attribute is set', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-with-remote-image.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      :page-background-image: image:svg-with-remote-image.svg[fit=none,position=top]

      Asciidoctor
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-with-image.pdf'
    end

    it 'should not allow remote image in SVG to be read if allow-uri-read attribute is not set', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-with-remote-image-disabled.pdf'
      :page-background-image: image:svg-with-remote-image.svg[fit=none,position=top]

      Asciidoctor
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-with-image-disabled.pdf'
    end

    it 'should read local image relative to SVG', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-with-local-image.pdf'
      :page-background-image: image:svg-with-local-image.svg[fit=none,position=top]

      Asciidoctor
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-with-image.pdf'
    end

    it 'should position background image according to value of position attribute on macro', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-position.pdf'
      = Document Title
      :page-background-image: image:example-watermark.svg[pdfwidth=50%,position=bottom center]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image-position.pdf'
    end

    it 'should alternate page background if both verso and recto background images are specified', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt.pdf'
      = Document Title
      :doctype: book
      :page-background-image-recto: image:recto-bg.png[]
      :page-background-image-verso: image:verso-bg.png[]

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt.pdf'
    end

    it 'should alternate page background in landscape if both verso and recto background images are specified', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt-landscape.pdf'
      = Document Title
      :doctype: book
      :pdf-page-layout: landscape
      :page-background-image-recto: image:recto-bg-landscape.png[]
      :page-background-image-verso: image:verso-bg-landscape.png[]

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt-landscape.pdf'
    end

    it 'should use background image as fallback if background image for side not specified', integration: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:recto-bg.png[]
      :page-background-image-verso: image:verso-bg.png[]

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt.pdf'
    end

    it 'should allow background image to be disabled if side is set to none', integration: true do
      [
        { 'page-background-image' => 'image:recto-bg.png[]', 'page-background-image-verso' => 'none' },
        { 'page-background-image-recto' => 'image:recto-bg.png[]' },
      ].each do |attribute_overrides|
        to_file = to_pdf_file <<~EOS, 'page-background-image-recto-only.pdf', attribute_overrides: attribute_overrides
        = Document Title
        :doctype: book

        content

        <<<

        more content

        <<<

        the end
        EOS

        (expect to_file).to visually_match 'page-background-image-recto-only.pdf'
      end
    end

    it 'should use the specified image format', integration: true do
      source_file = (dest_file = fixture_file 'square') + '.svg'
      begin
        FileUtils.cp source_file, dest_file
        to_file = to_pdf_file <<~'EOS', 'page-background-image-format.pdf'
        = Document Title
        :page-background-image: image:square[format=svg]

        This page has a background image that is rather loud.
        EOS

        (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
      ensure
        File.unlink dest_file
      end
    end
  end
end
