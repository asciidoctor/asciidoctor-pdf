require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Images' do
  context 'Local' do
    it 'should replace image with poster image if specified', integration: true do
      to_file = to_pdf_file <<~'EOS', 'videos-local-file-poster.pdf', attributes: { 'imagesdir' => fixtures_dir, 'nofooter' => '' }
      video::asciidoctor.mp4[logo.png,200,200]
      EOS

      (expect to_file).to visually_match 'videos-local-file-poster.pdf'
    end
  end
end
