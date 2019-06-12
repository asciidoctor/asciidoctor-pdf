require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Page' do
  context 'Size' do
    it 'should set page size specified by theme by default' do
      pdf = to_pdf <<~'EOS', analyze: :page
      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should set page size specified by pdf-page-size attribute using predefined name' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: Letter

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in pt' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: [600, 800]

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql [600.0, 800.0]
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in in' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: [8.5in, 11in]

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end

    it 'should set page size specified by pdf-page-size attribute using dimension string in in' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: 8.5in x 11in

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end
  end

  context 'Layout' do
    it 'should use layout specified in theme by default' do
      pdf = to_pdf <<~'EOS'
      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0].orientation).to eql 'portrait'
    end

    it 'should use layout specified by pdf-page-layout attribute' do
      pdf = to_pdf <<~'EOS'
      :pdf-page-layout: landscape

      content
      EOS
      (expect pdf.pages.size).to eql 1
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
      theme_overrides = { page_background_color: 'ECFBF4' }
      to_file = to_pdf_file <<~'EOS', 'page-background-color.pdf', pdf_theme: (build_pdf_theme theme_overrides)
      = Document Title
      :doctype: book

      content
      EOS

      (expect to_file).to visually_match 'page-background-color.pdf'
    end

    it 'should set the background image specified by the page-background-image attribute' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image::bg.png[]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should alternate page background if both verso and recto background images are specified' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt.pdf'
      = Document Title
      :doctype: book
      :page-background-image-recto: image::recto-bg.png[]
      :page-background-image-verso: image::verso-bg.png[]

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt.pdf'
    end

    it 'should use background image as fallback if background image for side not specified' do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image::recto-bg.png[]
      :page-background-image-verso: image::verso-bg.png[]

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
