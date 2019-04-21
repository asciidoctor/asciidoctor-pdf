require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Tables' do
  it 'should not fail to fit text in cell' do
    pdf = to_pdf <<~'EOS', analyze: :text
    |===
    |Aaaaa Bbbbb Ccccc |*{zwsp}* Aaaaa_Bbbbb_Ccccc |Aaaaa_Bbbbb_Ccccc |Aaaaa_Bbbbb_Ccccc |A
    |===
    EOS
    (expect pdf.strings.index 'Aaaaa Bbbbb').to eql 0
    (expect pdf.strings.index 'Ccccc').to eql 1
  end
end
