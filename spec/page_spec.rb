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

    it 'should change layout if page break specifies page-layout attribute' do
      pdf = to_pdf <<~'EOS', analyze: true
      portrait

      [page-layout=landscape]
      <<<

      landscape
      EOS

      text = pdf.text
      (expect text.size).to eql 2
      (expect text[0].values_at :string, :page_number, :x, :y).to eq ['portrait', 1, 48.24, 793.926]
      (expect text[1].values_at :string, :page_number, :x, :y).to eq ['landscape', 2, 48.24, 547.316]
    end

    it 'should change layout if page break specifies layout role' do
      pdf = to_pdf <<~'EOS', analyze: true
      portrait

      [.landscape]
      <<<

      landscape
      EOS

      text = pdf.text
      (expect text.size).to eql 2
      (expect text[0].values_at :string, :page_number, :x, :y).to eq ['portrait', 1, 48.24, 793.926]
      (expect text[1].values_at :string, :page_number, :x, :y).to eq ['landscape', 2, 48.24, 547.316]
    end
  end

  context 'Margin' do
    it 'should use the margin specified in theme by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      content
      EOS
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
end
