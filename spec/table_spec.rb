require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Table' do
  context 'Decoration' do
    it 'should apply frame all and grid all by default' do
      pdf = to_pdf <<~'EOS', analyze: :line
      |===
      |1 |2
      |3 |4
      |===
      EOS

      (expect pdf.lines.uniq).to have_size 12
    end

    it 'should allow frame and grid to be specified on table using frame and grid attributes' do
      pdf = to_pdf <<~'EOS', analyze: :line
      [frame=ends,grid=cols]
      |===
      |1 |2
      |3 |4
      |===
      EOS

      (expect pdf.lines.uniq).to have_size 6
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

      (expect pdf_a.lines).to eql pdf_b.lines
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

      (expect pdf.lines.uniq).to have_size 6
    end if asciidoctor_2_or_better?

    it 'should apply stripes to specified group of rows as specified by stripes attribute', integration: true do
      to_file = to_pdf_file <<~'EOS', 'table-stripes-odd.pdf'
      [cols=3*,stripes=odd]
      |===
      |A1 |B1 |C1
      |A2 |B2 |C2
      |A3 |B3 |C3
      |===
      EOS

      (expect to_file).to visually_match 'table-stripes-odd.pdf'
    end if asciidoctor_1_5_7_or_better?

    it 'should apply thicker bottom border to table head row' do
      pdf = to_pdf <<~'EOS', analyze: :line
      [frame=none,grid=rows]
      |===
      | Col A | Col B

      | A1
      | B1

      | A2
      | B2
      |===
      EOS

      lines = pdf.lines.uniq
      (expect lines).to have_size 4
      (expect lines[0][:width]).to eql 1.25
      (expect lines[1][:width]).to eql 1.25
      (expect lines[0][:from][:y]).to eql lines[0][:to][:y]
      (expect lines[1][:from][:y]).to eql lines[1][:to][:y]
      (expect lines[0][:from][:y]).to eql lines[1][:from][:y]
      (expect lines[2][:width]).to eql 0.5
      (expect lines[3][:width]).to eql 0.5
    end

    it 'should allow theme to set table border color to transparent' do
      theme_overrides = {
        table_border_color: 'transparent'
      }

      pdf = to_pdf <<~'EOS', analyze: :line, pdf_theme: theme_overrides
      [frame=none,grid=rows]
      |===
      | Col A | Col B

      | A1
      | B1

      | A2
      | B2
      |===
      EOS

      pdf.lines.uniq.each do |line|
        (expect line[:color]).to eql '00000000'
      end
    end
  end

  context 'Dimensions' do
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

    it 'should not accumulate cell padding between tables' do
      pdf = to_pdf <<~'EOS', pdf_theme: { table_cell_padding: [5, 5, 5, 5] }, analyze: true
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

    it 'should set padding on head cells the same as body cells by default' do
      input = <<~'EOS'
      [frame=none,grid=rows]
      |===
      | Column A | Column B

      | A1
      | B1
      |===
      EOS

      reference_pdf = to_pdf input, analyze: :line
      pdf = to_pdf input, pdf_theme: { table_cell_padding: [10, 3, 10, 3] }, analyze: :line

      # NOTE the line under the head row should moved down
      (expect pdf.lines[0][:from][:y]).to be < reference_pdf.lines[0][:from][:y]
    end

    it 'should set padding on head cells as specified by table_head_cell_padding theme key' do
      input = <<~'EOS'
      [frame=none,grid=rows]
      |===
      | Column A | Column B

      | A1
      | B1
      |===
      EOS

      reference_pdf = to_pdf input, analyze: true
      pdf = to_pdf input, pdf_theme: { table_head_cell_padding: [10, 3, 10, 3] }, analyze: true
      
      reference_a1_text = (reference_pdf.find_text 'A1')[0]
      a1_text = (pdf.find_text 'A1')[0]

      # NOTE the first body row should be moved down
      (expect a1_text[:y]).to be < reference_a1_text[:y]
    end
  end

  context 'Basic table cell' do
    it 'should keep paragraphs in table cell separate' do
      pdf = to_pdf <<~'EOS', analyze: true
      |===
      |all one
      line

      |line 1 +
      line 2

      |paragraph 1

      paragraph 2
      |===
      EOS

      cell_1_text = pdf.find_text 'all one line'
      (expect cell_1_text).not_to be_empty
      cell_2_text = pdf.find_text %r/^line (?:1|2)/
      (expect cell_2_text).to have_size 2
      (expect cell_2_text[0][:y]).to be > cell_2_text[1][:y]
      cell_3_text = pdf.find_text %r/^paragraph (?:1|2)/
      (expect cell_3_text).to have_size 2
      (expect cell_3_text[0][:y]).to be > cell_3_text[1][:y]
      (expect cell_3_text[0][:y] - cell_3_text[1][:y]).to be > (cell_2_text[0][:y] - cell_2_text[1][:y])
    end
  end

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

    it 'should convert nested table' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols="1,2a"]
      |===
      |Normal cell
      |Cell with nested table
      [cols="2,1"]
      !===
      !Nested table cell 1 !Nested table cell 2
      !===
      |===
      EOS

      (expect pdf.lines.find {|l| l.include? '!' }).to be_nil
      (expect pdf.lines).to have_size 2
      (expect pdf.lines[1]).to eql 'Nested table cell 1Nested table cell 2'
      nested_cell_1 = (pdf.find_text 'Nested table cell 1')[0]
      nested_cell_2 = (pdf.find_text 'Nested table cell 2')[0]
      (expect nested_cell_1[:y]).to eql nested_cell_2[:y]
      (expect nested_cell_1[:x]).to be < nested_cell_2[:x]
    end
  end
end
