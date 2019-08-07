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

    it 'should allow theme to customize bottom border of table head row', integration: true do
      theme_overrides = {
        table_head_border_bottom_width: 0.5,
        table_head_border_bottom_style: 'dashed',
        table_head_border_bottom_color: 'a9a9a9',
      }
      to_file = to_pdf_file <<~'EOS', 'table-head-border-bottom.pdf', pdf_theme: theme_overrides
      [frame=none,grid=rows]
      |===
      | Col A | Col B

      | A1
      | B1

      | A2
      | B2
      |===
      EOS

      (expect to_file).to visually_match 'table-head-border-bottom.pdf'
    end

    it 'should allow theme to set table border color to transparent' do
      theme_overrides = {
        table_border_color: 'transparent',
        table_head_border_bottom_color: 'transparent',
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

    it 'should not split cells in head row across pages' do
      hard_line_break = %( +\n)
      filler = (['filler'] * 40).join hard_line_break
      head_cell_1 = %w(this is a very tall cell in the head row of this table).join hard_line_break
      head_cell_2 = %w(this is an even taller cell also in the head row of this table).join hard_line_break
      pdf = to_pdf <<~EOS, analyze: true
      #{filler}

      [%header,cols=2*]
      |===
      |#{head_cell_1}
      |#{head_cell_2}

      |body cell
      |body cell
      |===
      EOS

      filler_page_nums = (pdf.find_text 'filler').map {|it| it[:page_number] }
      (expect filler_page_nums.uniq).to have_size 1
      (expect filler_page_nums[0]).to eql 1
      table_cell_page_nums = pdf.text.reject {|it| it[:string] == 'filler' }.map {|it| it[:page_number] }
      (expect table_cell_page_nums.uniq).to have_size 1
      (expect table_cell_page_nums[0]).to eql 2
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

  context 'Caption' do
    it 'should add title as caption above table by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      .Table description
      |===
      | Col A | Col B

      | A1
      | B1

      | A2
      | B2
      |===
      EOS

      caption_text = pdf.text[0]
      (expect caption_text[:string]).to eql 'Table 1. Table description'
      (expect caption_text[:font_name]).to eql 'NotoSerif-Italic'
      (expect caption_text[:y]).to be > (pdf.find_text 'Col A')[0][:y]
    end

    it 'should add title as caption below table if table_caption_side key in theme is bottom' do
      pdf = to_pdf <<~'EOS', pdf_theme: { table_caption_side: 'bottom' }, analyze: true
      .Table description
      |===
      | Col A | Col B

      | A1
      | B1

      | A2
      | B2
      |===
      EOS

      caption_text = pdf.text[-1]
      (expect caption_text[:string]).to eql 'Table 1. Table description'
      (expect caption_text[:y]).to be < (pdf.find_text 'B2')[0][:y]
    end

    it 'should confine caption to width of table by default', integration: true do
      to_file = to_pdf_file <<~'EOS', 'table-caption-width.pdf', pdf_theme: { caption_align: 'center' }
      .A rather long description for this table
      [%header%autowidth]
      |===
      | Col A | Col B

      | A1
      | B1

      | A2
      | B2
      |===

      .A rather long description for this table
      [%header%autowidth,align=center]
      |===
      | Col C | Col D

      | C1
      | D1

      | C2
      | D2
      |===

      .A rather long description for this table
      [%header%autowidth,align=right]
      |===
      | Col E | Col F

      | E1
      | F1

      | E2
      | F2
      |===
      EOS

      (expect to_file).to visually_match 'table-caption-width.pdf'
    end

    it 'should not confine caption to width of table if table_caption_max_width key in theme is none' do
      pdf = to_pdf <<~'EOS', pdf_theme: { caption_align: 'center', table_caption_max_width: 'none' }, analyze: true
      :table-caption!:

      .A rather long description for this table
      [%autowidth]
      |===
      | Col A | Col B

      | A1
      | B1

      | A2
      | B2
      |===

      .A rather long description for this table
      [%autowidth,align=center]
      |===
      | Col C | Col D

      | C1
      | D1

      | C2
      | D2
      |===

      .A rather long description for this table
      [%autowidth,align=right]
      |===
      | Col E | Col F

      | E1
      | F1

      | E2
      | F2
      |===
      EOS

      caption_texts = pdf.find_text 'A rather long description for this table'
      (expect caption_texts).to have_size 3
      (expect caption_texts.map {|it| it[:x] }.uniq).to have_size 1
    end
  end

  context 'Table alignment' do
    it 'should allow theme to customize default alignment of table ' do
      pdf = to_pdf <<~'EOS', pdf_theme: { table_align: 'right' }, analyze: true
      [cols=3*,width=50%]
      |===
      |RIGHT |B1 |C1
      |A2 |B2 |C2
      |A3 |B3 |C3
      |===

      [cols=3*,width=50%,align=left]
      |===
      |LEFT |B1 |C1
      |A2 |B2 |C2
      |A3 |B3 |C3
      |===
      EOS

      cell_right = (pdf.find_text 'RIGHT')[0]
      cell_left = (pdf.find_text 'LEFT')[0]

      (expect cell_right[:x]).to be > cell_left[:x]
    end

    it 'should allow position of table to be set using align attribute on table' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols=3*,width=50%]
      |===
      |LEFT |B1 |C1
      |A2 |B2 |C2
      |A3 |B3 |C3
      |===

      [cols=3*,width=50%,align=right]
      |===
      |RIGHT |B1 |C1
      |A2 |B2 |C2
      |A3 |B3 |C3
      |===
      EOS

      cell_right_text = (pdf.find_text 'RIGHT')[0]
      cell_left_text = (pdf.find_text 'LEFT')[0]

      (expect cell_right_text[:x]).to be > cell_left_text[:x]
    end

    it 'should not mangle margin box on subsequent pages if table with alignment crosses page boundary' do
      blank_line = %(\n\n)

      pdf = to_pdf <<~EOS, analyze: true
      #{(['filler'] * 25).join blank_line}

      [%autowidth,align=right]
      |===
      |A | B

      |A1
      |B1

      |A2
      |B2

      |A3
      |B3
      |===

      #{(['filler'] * 22).join blank_line}

      #{(['* list item'] * 6).join ?\n}
      EOS

      page_width = pdf.pages[0][:size][0]
      a1_text = (pdf.find_text 'A1')[0]
      a3_text = (pdf.find_text 'A3')[0]
      (expect a1_text[:x]).to be > (page_width * 0.5)
      (expect a1_text[:page_number]).to eql 1
      (expect a3_text[:x]).to be > (page_width * 0.5)
      (expect a3_text[:page_number]).to eql 2
      first_list_item_text = (pdf.find_text string: 'list item', page_number: 2)[0]
      last_list_item_text = (pdf.find_text string: 'list item', page_number: 3)[-1]
      # NOTE if this is off, the margin box got mangled
      (expect last_list_item_text[:x]).to eql first_list_item_text[:x]
    end

    it 'should set width of aligned table relative to bounds' do
      pdf = to_pdf <<~EOS, analyze: true
      [width=25%,align=right]
      |===
      |A | B

      |A1
      |B1

      |A2
      |B2
      |===
      ====
      ****

      [width=25%,align=right]
      |===
      |A | B

      |A1
      |B1

      |A2
      |B2
      |===
      ****
      ====
      EOS

      page_width = pdf.pages[0][:size][0]
      first_a1_text = (pdf.find_text 'A1')[0]
      second_a1_text = (pdf.find_text 'A1')[1]
      (expect first_a1_text[:x]).to be > (page_width * 0.5)
      (expect second_a1_text[:x]).to be > (page_width * 0.5)
      (expect first_a1_text[:x]).to be > second_a1_text[:x]
    end
  end
end
