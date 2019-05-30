require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Table' do
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
  end if asciidoctor_2_or_better?

  it 'should apply stripes to specified group of rows as specified by stripes attribute', integration: true do
    to_file = to_pdf_file <<~'EOS', 'table-stripes-odd.pdf', attributes: 'nofooter'
    [cols=3*,stripes=odd]
    |===
    |A1 |B1 |C1
    |A2 |B2 |C2
    |A3 |B3 |C3
    |===
    EOS

    (expect to_file).to visually_match 'table-stripes-odd.pdf'
  end if asciidoctor_1_5_7_or_better?

  it 'should not fail to fit text in cell' do
    pdf = to_pdf <<~'EOS', analyze: true
    |===
    |Aaaaa Bbbbb Ccccc |*{zwsp}* Aaaaa_Bbbbb_Ccccc |Aaaaa_Bbbbb_Ccccc |Aaaaa_Bbbbb_Ccccc |A
    |===
    EOS
    (expect pdf.strings.index 'Aaaaa Bbbbb').to eql 0
    (expect pdf.strings.index 'Ccccc').to eql 1
  end

  it 'should not break words in head row when autowidth option is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    [%autowidth]
    |===
    |Operation |Operator
    
    |add
    |+
    
    |subtract
    |-
    
    |multiply
    |*
    
    |divide
    |/
    |===
    EOS

    (expect pdf.find_text 'Operation').not_to be_empty
    (expect pdf.find_text 'Operator').not_to be_empty
  end

  it 'should not break words in body rows when autowidth option is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    [%autowidth]
    |===
    |Op
    
    |add
    
    |subtract
    
    |multiply
    
    |divide
    |===
    EOS

    (expect pdf.find_text 'add').not_to be_empty
    (expect pdf.find_text 'subtract').not_to be_empty
    (expect pdf.find_text 'multiply').not_to be_empty
    (expect pdf.find_text 'divide').not_to be_empty
  end

  it 'should not accumulate cell padding between tables' do
    theme_overrides = { table_cell_padding: [5, 5, 5, 5] }
    pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    |===
    |A |B

    |A1
    |B1

    |A2
    |B2
    |===

    |===
    |A |B

    |A1
    |B1

    |A2
    |B2
    |===

    |===
    |A |B

    |A1
    |B1

    |A2
    |B2
    |===
    EOS

    first_a1_text = (pdf.find_text 'A1')[0]
    first_a2_text = (pdf.find_text 'A2')[0]
    last_a1_text = (pdf.find_text 'A1')[-1]
    last_a2_text = (pdf.find_text 'A2')[-1]
    (expect first_a1_text[:y] - first_a2_text[:y]).to eql (last_a1_text[:y] - last_a2_text[:y])
  end

  it 'should allocate remaining width to autowidth column' do
    pdf = to_pdf <<~'EOS', analyze: true
    [cols="10,~"]
    |===
    |0x00
    |UNSPECIFIED
    
    |0x01
    |OK
    |===
    EOS
    (expect pdf.strings).to eql %w(0x00 UNSPECIFIED 0x01 OK)
    unspecified_text = (pdf.find_text 'UNSPECIFIED')[0]
    (expect unspecified_text[:x]).to eql 101.12
    ok_text = (pdf.find_text 'OK')[0]
    (expect ok_text[:x]).to eql 101.12
  end if asciidoctor_1_5_7_or_better?

  context 'AsciiDoc table cell' do
    it 'should convert blocks in an AsciiDoc table cell' do
      pdf = to_pdf <<~'EOS', analyze: true
      |===
      a|
      [start=10]
      . ten
      . eleven
      . twelve

      [%hardbreaks]
      buckle
      my
      shoe
      |===
      EOS
      (expect pdf.lines).to eql ['10.ten', '11.eleven', '12.twelve', 'buckle', 'my', 'shoe']
    end
  end
end
