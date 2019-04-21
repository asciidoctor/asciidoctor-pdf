require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Tables' do
  it 'should apply frame all and grid all by default' do
    pdf = to_pdf <<~'EOS', analyze: :line
    |===
    |1 |2
    |3 |4
    |===
    EOS

    (expect pdf.points.size).to eql 32
  end

  it 'should allow frame and grid to be specified on table using frame and grid attributes' do
    pdf = to_pdf <<~'EOS', analyze: :line
    [frame=ends,grid=cols]
    |===
    |1 |2
    |3 |4
    |===
    EOS

    (expect pdf.points.size).to eql 16
  end

  it 'should treat topbot value of frame attribute as an alias for ends' do
    pdf_a = to_pdf <<~'EOS', analyze: :line
    [frame=ends]
    |===
    |1 |2
    |3 |4
    |===
    EOS

    pdf_b = to_pdf <<~'EOS', analyze: :line
    [frame=topbot]
    |===
    |1 |2
    |3 |4
    |===
    EOS

    (expect pdf_a.points.size).to eql pdf_b.points.size
  end

  it 'should allow frame and grid to be set globally using table-frame and table-grid attributes' do
    pdf = to_pdf <<~'EOS', analyze: :line
    :table-frame: ends
    :table-grid: cols

    |===
    |1 |2
    |3 |4
    |===
    EOS

    (expect pdf.points.size).to eql 16
  end

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
