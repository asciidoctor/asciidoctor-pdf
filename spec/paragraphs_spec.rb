require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Paragraphs' do
  it 'should normalize whitespace' do
    pdf = to_pdf <<~EOS, analyze: :text
    He's  a  real  nowhere  man,
    Sitting in his nowhere land,
    Making all his nowhere plans\tfor nobody.
    EOS
    text = pdf.text
    (expect text.size).to eql 1
    (expect text).not_to include '  '
    (expect text).not_to include ?\t
    (expect text).not_to include ?\n
  end
end
