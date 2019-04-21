require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Sections' do
  it 'should apply font size according to section level' do
    pdf = to_pdf <<~'EOS', analyze: :text
    = Document Title

    == Level 1

    === Level 2

    section content

    == Back To Level 1
    EOS
    (expect pdf.strings).to eql ['Document Title', 'Level 1', 'Level 2', 'section content', 'Back To Level 1']
    (expect pdf.font_settings.map {|it| it[:size] }).to eql [27, 22, 18, 10.5, 22]
  end
end
