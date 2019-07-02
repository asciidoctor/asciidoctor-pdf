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
    it 'should set page background color specified by page_background_color key in theme' do
      to_file = to_pdf_file <<~'EOS', 'page-background-color.pdf', pdf_theme: { page_background_color: 'ECFBF4' }
      = Document Title
      :doctype: book

      content
      EOS

      (expect to_file).to visually_match 'page-background-color.pdf'
    end

    it 'should set the background image using target of macro specified in page-background-image attribute' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-inline-macro.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:bg.png[]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should recognize attribute value that use block macro syntax' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-block-macro.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:bg.png[]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should set the background image using path specified in page-background-image attribute' do
      to_file = to_pdf_file <<~EOS, 'page-background-image-path.pdf'
      = Document Title
      :doctype: book
      :page-background-image: #{fixture_file 'bg.png', relative: true}

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should scale background image until it reaches shortest side' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-max-height.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:square.png[]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-max-height.pdf'
    end

    it 'should set width of background image according to width attribute' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-width.pdf'
      = Document Title
      :page-background-image: image:square.png[bg,200]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-width.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if value is path' do
      to_file = to_pdf_file <<~EOS, 'page-background-image-svg-scale-up-from-path.pdf'
      = Document Title
      :page-background-image: #{fixture_file 'square.svg', relative: true}

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if value is macro' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-scale-up-from-macro.pdf'
      = Document Title
      :page-background-image: image:square.svg[]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if fit is contain' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-contain.pdf'
      = Document Title
      :page-background-image: image:square.svg[fit=contain]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if pdfwidth is 100%' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-pdfwidth.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:square.svg[pdfwidth=100%]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-cover.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if value is path' do
      to_file = to_pdf_file <<~EOS, 'page-background-image-svg-scale-down-from-path.pdf'
      = Document Title
      :page-background-image: #{fixture_file 'example-watermark.svg', relative: true}

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if value is macro' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-scale-down-from-macro.pdf'
      = Document Title
      :page-background-image: image:example-watermark.svg[]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if fit is scale-down' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-scale-down.pdf'
      = Document Title
      :page-background-image: image:example-watermark.svg[fit=scale-down]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should not scale background SVG with explicit width to fit boundaries of page if fit is scale-down and image fits' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-prescaled.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:green-bar.svg[pdfwidth=50%,fit=scale-down]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-prescaled.pdf'
    end

    it 'should not scale background SVG to fit boundaries of page if fit is none' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-none.pdf'
      = Document Title
      :page-background-image: image:example-watermark.svg[fit=none]

      This page has a watermark.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-unscaled.pdf'
    end

    it 'should alternate page background if both verso and recto background images are specified' do
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

    it 'should alternate page background in landscape if both verso and recto background images are specified' do
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

    it 'should use background image as fallback if background image for side not specified' do
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
  end
end
