require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Image' do
  context 'Local' do
    it 'should replace image with poster image if specified', integration: true do
      to_file = to_pdf_file <<~'EOS', 'video-local-file-poster.pdf'
      video::asciidoctor.mp4[logo.png,200,200]
      EOS

      (expect to_file).to visually_match 'video-local-file-poster.pdf'
    end
  end

  context 'YouTube' do
    it 'should replace image with poster image if allow-uri-read attribute is set', integration: true do
      to_file = to_pdf_file <<~'EOS', 'video-youtube-poster.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      video::49tpIMDy9BE[youtube,pdfwidth=100%]
      EOS

      (expect to_file).to visually_match 'video-youtube-poster.pdf'
    end
  end

  context 'Vimeo' do
    it 'should replace image with poster image if allow-uri-read attribute is set', integration: true do
      to_file = to_pdf_file <<~'EOS', 'video-vimeo-poster.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      video::300817511[vimeo,pdfwidth=100%]
      EOS

      (expect to_file).to visually_match 'video-vimeo-poster.pdf'
    end
  end
end
