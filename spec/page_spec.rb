require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Page' do
  context 'Size' do
    it 'should set page size specified by theme by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql [595.28, 841.89]
    end

    it 'should set page size specified by pdf-page-size attribute using predefined name' do
      pdf = to_pdf <<~'EOS', analyze: true
      :pdf-page-size: Letter

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql [612.0, 792.0]
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in pt' do
      pdf = to_pdf <<~'EOS', analyze: true
      :pdf-page-size: [600, 800]

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql [600.0, 800.0]
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in in' do
      pdf = to_pdf <<~'EOS', analyze: true
      :pdf-page-size: [8.5in, 11in]

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql [612.0, 792.0]
    end

    it 'should set page size specified by pdf-page-size attribute using dimension string in in' do
      pdf = to_pdf <<~'EOS', analyze: true
      :pdf-page-size: 8.5in x 11in

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size]).to eql [612.0, 792.0]
    end
  end

  context 'Layout' do
    it 'should use layout specified in theme by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size][0]).to be < pdf.pages[0][:size][1]
    end

    it 'should use layout specified by pdf-page-layout attribute' do
      pdf = to_pdf <<~'EOS', analyze: true
      :pdf-page-layout: landscape

      content
      EOS
      (expect pdf.pages.size).to eql 1
      (expect pdf.pages[0][:size][0]).to be > pdf.pages[0][:size][1]
    end
  end

  context 'Margin' do
    it 'should use the margin specified in theme by default' do
      pdf = to_pdf <<~'EOS', analyze: :text
      content
      EOS
      (expect pdf.positions[0]).to eql [48.24, 793.926]
    end

    it 'should use the margin specified by the pdf-page-margin attribute as array' do
      pdf = to_pdf <<~'EOS', analyze: :text
      :pdf-page-margin: [0, 0, 0, 0]

      content
      EOS
      (expect pdf.positions[0]).to eql [0.0, 829.926]
    end

    it 'should use the margin specified by the pdf-page-margin attribute as string' do
      pdf = to_pdf <<~'EOS', analyze: :text
      :pdf-page-margin: 1in

      content
      EOS
      (expect pdf.positions[0]).to eql [72.0, 757.926]
    end
  end
end
