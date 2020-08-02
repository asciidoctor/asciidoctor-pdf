# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Table' do
  it 'should not crash if table has no rows' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: :line
      |===
      |===
      EOS

      (expect pdf.lines).to have_size 4
    end).to not_raise_exception & (log_message severity: :WARN, message: 'no rows found in table')
  end

  it 'should not crash if cols and table cells are mismatched' do
    (expect do
      pdf = to_pdf <<~'EOS', analyze: :line
      [cols="1,"]
      |===
      | cell
      |===
      EOS

      (expect pdf.lines).to have_size 8
    end).to not_raise_exception & (log_message severity: :WARN, message: 'no rows found in table')
  end

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
    end

    it 'should allow theme to control table stripe color using table_body_stripe_background_color key', visual: true do
      pdf_theme = {
        table_body_background_color: 'FDFDFD',
        table_body_stripe_background_color: 'EFEFEF',
      }
      to_file = to_pdf_file <<~'EOS', 'table-stripes-even.pdf', pdf_theme: pdf_theme
      [stripes=even]
      |===
      |fee
      |fi
      |fo
      |fum
      |===
      EOS

      (expect to_file).to visually_match 'table-stripes-even.pdf'
    end

    it 'should apply stripes to odd rows as specified by stripes attribute', visual: true do
      to_file = to_pdf_file <<~'EOS', 'table-stripes-odd.pdf'
      [cols=3*,stripes=odd]
      |===
      |A1 |B1 |C1
      |A2 |B2 |C2
      |A3 |B3 |C3
      |===
      EOS

      (expect to_file).to visually_match 'table-stripes-odd.pdf'
    end

    it 'should apply stripes to all rows as specified by stripes attribute', visual: true do
      to_file = to_pdf_file <<~'EOS', 'table-stripes-all.pdf'
      [cols=3*,stripes=all]
      |===
      |A1 |B1 |C1
      |A2 |B2 |C2
      |A3 |B3 |C3
      |===
      EOS

      (expect to_file).to visually_match 'table-stripes-all.pdf'
    end

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

    it 'should apply thicker bottom border to last table head row when table has multiple head rows' do
      tree_processor_impl = proc do
        process do |doc|
          table = doc.blocks[0]
          table.rows[:head] << table.rows[:body].shift
        end
      end
      opts = { extension_registry: Asciidoctor::Extensions.create { tree_processor(&tree_processor_impl) } }
      pdf = to_pdf <<~'EOS', (opts.merge analyze: :line)
      [%header,frame=none,grid=rows]
      |===
      | Columns
      | Col A

      | A1

      | A2
      |===
      EOS

      lines = pdf.lines.uniq
      ys = lines.map {|l| l[:from][:y] }.sort.reverse.uniq
      (expect ys).to have_size 3
      head_dividing_lines = lines.select {|l| l[:width] == 1.25 }
      (expect head_dividing_lines).to have_size 1
      (expect head_dividing_lines[0][:from][:y]).to eql head_dividing_lines[0][:to][:y]
      (expect head_dividing_lines[0][:from][:y]).to eql ys[1]
    end

    it 'should retain border on bottom of table head when grid and frame are disabled' do
      input = <<~'EOS'
      [grid=none,frame=none]
      |===
      |A |B

      |A1
      |B1

      |A2
      |B2
      |===
      EOS

      pdf = to_pdf input, analyze: :line

      (expect pdf.lines).to have_size 2
      line_y = pdf.lines[0][:from][:y]
      (expect pdf.lines[0][:to][:y]).to eql line_y
      (expect pdf.lines[1][:from][:y]).to eql line_y
      (expect pdf.lines[1][:to][:y]).to eql line_y
      (expect pdf.lines[0][:width]).to eql 1.25
      (expect pdf.lines[1][:width]).to eql 1.25

      pdf = to_pdf input, analyze: true
      a_text = pdf.find_unique_text 'A'
      a1_text = pdf.find_unique_text 'A1'
      (expect a_text[:y]).to be > line_y
      (expect a1_text[:y]).to be < line_y
    end

    it 'should allow theme to customize bottom border of table head row', visual: true do
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

    it 'should repeat multiple head rows on subsequent pages' do
      tree_processor_impl = proc do
        process do |doc|
          table = doc.blocks[0]
          table.rows[:head] << table.rows[:body].shift
        end
      end
      opts = { extension_registry: Asciidoctor::Extensions.create { tree_processor(&tree_processor_impl) } }
      pdf = to_pdf <<~EOS, (opts.merge analyze: true)
      [%header]
      |===
      2+^| Columns
      ^| Column A ^| Column B
      #{['| cell | cell'] * 40 * ?\n}
      |===
      EOS

      [1, 2].each do |page_number|
        col_a_text = (pdf.find_text page_number: page_number, string: 'Column A')[0]
        col_b_text = (pdf.find_text page_number: page_number, string: 'Column B')[0]
        (expect col_a_text).not_to be_nil
        (expect col_a_text[:font_name]).to eql 'NotoSerif-Bold'
        (expect col_b_text).not_to be_nil
        (expect col_b_text[:font_name]).to eql 'NotoSerif-Bold'
      end
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

    it 'should allow theme to specify table border color as CMYK array' do
      cmyk_color = [19, 9, 0, 60].extend Asciidoctor::PDF::ThemeLoader::CMYKColorValue
      theme_overrides = {
        table_border_color: cmyk_color,
        table_head_border_bottom_color: cmyk_color,
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
        (expect line[:color]).to eql cmyk_color.map(&:to_f)
      end
    end

    it 'should allow theme to set color, width, and style of grid' do
      pdf_theme = {
        table_grid_color: 'BBBBBB',
        table_grid_width: 2,
        table_grid_style: 'dotted',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
      [frame=none,grid=all]
      |===
      | A | B
      | C | D
      |===
      EOS

      # NOTE: it appears Prawn table is drawing the same grid line multiple times
      lines = pdf.lines.uniq
      (expect lines).to have_size 4
      lines.each do |line|
        (expect line[:color]).to eql 'BBBBBB'
        (expect line[:width]).to eql 2
        (expect line[:style]).to eql :dotted
      end
    end

    it 'should allow theme to set color, width, and style of frame' do
      pdf_theme = {
        table_border_color: 'AAAAAA',
        table_border_width: 3,
        table_border_style: 'dashed',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
      [frame=all,grid=none]
      |===
      | A | B
      | C | D
      |===
      EOS

      lines = pdf.lines
      (expect lines).to have_size 8
      lines.each do |line|
        (expect line[:color]).to eql 'AAAAAA'
        (expect line[:width]).to eql 3
        (expect line[:style]).to eql :dashed
      end
    end

    it 'should honor cellbgcolor attribute in table cell to set background color of cell', visual: true do
      to_file = to_pdf_file <<~'EOS', 'table-cellbgcolor.pdf'
      :attribute-undefined: drop

      [%autowidth,cols=3*]
      |===
      | default background color
      | {set:cellbgcolor:#FF0000}red background color
      | {set:cellbgcolor!}default background color again
      |===
      EOS

      (expect to_file).to visually_match 'table-cellbgcolor.pdf'
    end

    it 'should allow value of cellbgcolor attribute in table cell to be transparent', visual: true do
      to_file = to_pdf_file <<~'EOS', 'table-cellbgcolor.pdf'
      [%autowidth,cols=3*]
      |===
      | default background color
      | {set:cellbgcolor:#FF0000}red background color
      | {set:cellbgcolor:transparent}default background color again
      |===
      EOS

      (expect to_file).to visually_match 'table-cellbgcolor.pdf'
    end

    it 'should ignore cellbgcolor attribute if not a valid hex color', visual: true do
      to_file = to_pdf_file <<~'EOS', 'table-cellbgcolor-invalid.pdf'
      [%autowidth,cols=3*]
      |===
      | {set:cellbgcolor:#f00}default background color
      | {set:cellbgcolor:#ff0000}red background color
      | {set:cellbgcolor:bogus}default background color again
      |===
      EOS

      (expect to_file).to visually_match 'table-cellbgcolor.pdf'
    end

    it 'should use value of cellbgcolor attribute in table cell to override background color set by theme', visual: true do
      to_file = to_pdf_file <<~'EOS', 'table-cellbgcolor-override.pdf', pdf_theme: { table_body_background_color: 'CCCCCC' }
      :attribute-undefined: drop

      [%autowidth,cols=3*]
      |===
      | default background color
      | {set:cellbgcolor:#FF0000}red background color
      | {set:cellbgcolor!}default background color again
      |===
      EOS

      (expect to_file).to visually_match 'table-cellbgcolor-override.pdf'
    end
  end

  context 'Dimensions' do
    it 'should throw exception if no width is assigned to column' do
      (expect do
        to_pdf <<~'EOS'
        [cols=",50%,50%"]
        |===
        | Column A | Column B | Column C
        |===
        EOS
      end).to raise_exception Prawn::Errors::CannotFit
    end

    it 'should not fail to fit text in cell' do
      pdf = to_pdf <<~'EOS', analyze: true
      |===
      |Aaaaa Bbbbb Ccccc |*{zwsp}* Aaaaa_Bbbbb_Ccccc |Aaaaa_Bbbbb_Ccccc |Aaaaa_Bbbbb_Ccccc |A
      |===
      EOS
      (expect pdf.strings.index 'Aaaaa Bbbbb').to be 0
      (expect pdf.strings.index 'Ccccc').to be 1
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

      if (Gem::Version.new Prawn::Table::VERSION) > (Gem::Version.new '0.2.2')
        (expect pdf.find_text 'Operation').not_to be_empty
        (expect pdf.find_text 'Operator').not_to be_empty
      else
        (expect pdf.find_text 'Operation').to be_empty
        (expect pdf.find_text 'Operatio').not_to be_empty
        (expect pdf.find_text 'Operator').to be_empty
        (expect pdf.find_text 'Operato').not_to be_empty
      end
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

    it 'should wrap text by character when autowidth option is set and cell forces table to page boundary' do
      pdf = to_pdf <<~'EOS', analyze: true
      [%autowidth,cols=3*]
      |===
      | 100
      | Label1
      | Lorem ipsum dolor sit amet, elit fusce duis, voluptatem ut,
      mauris tempor orci odio sapien viverra ut, deserunt luctus.
      |===
      EOS

      (expect pdf.lines).to eql ['10', '0', 'Label', '1', 'Lorem ipsum dolor sit amet, elit fusce duis, voluptatem ut, mauris tempor orci odio', 'sapien viverra ut, deserunt luctus.']
    end

    it 'should stretch table to width of bounds by default' do
      pdf = to_pdf <<~'EOS', analyze: :line
      [grid=none,frame=sides]
      |===
      |A |B
      |===
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0][:from][:x]).to eql 48.24
      (expect lines[1][:from][:x]).to eql 547.04
    end

    it 'should not stretch autowidth table to width of bounds by default' do
      pdf = to_pdf <<~'EOS', analyze: :line
      [%autowidth,grid=none,frame=sides]
      |===
      |A |B
      |===
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0][:from][:x]).to eql 48.24
      (expect lines[1][:from][:x]).to be < 100
    end

    it 'should stretch autowidth table with stretch role to width of bounds' do
      pdf = to_pdf <<~'EOS', analyze: :line
      [%autowidth.stretch,grid=none,frame=sides]
      |===
      |A |B
      |===
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0][:from][:x]).to eql 48.24
      (expect lines[1][:from][:x]).to eql 547.04
    end

    it 'should set width of autowidth table if explicit width is specified' do
      input = <<~'EOS'
      [%autowidth,width=50%,grid=cols,frame=sides]
      |===
      |short |a much wider table column
      |===
      EOS

      pdf = to_pdf input, analyze: :line

      lines = pdf.lines.uniq
      (expect lines).to have_size 3
      col1_width = lines[1][:from][:x] - lines[0][:from][:x]
      col2_width = lines[2][:from][:x] - lines[1][:from][:x]
      (expect col2_width).to be > col1_width

      pdf = to_pdf input, analyze: true
      # NOTE: second column should not wrap
      (expect pdf.lines).to eql ['short a much wider table column']
    end

    it 'should apply equal width to columns by default when width attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: :line
      [frame=sides,grid=cols]
      |===
      |a | bbbbb | c
      |===
      EOS

      lines = pdf.lines.uniq {|it| [it[:from][:x], it[:from][:y], it[:to][:x], it[:to][:y]] }
      (expect lines).to have_size 4
      col1_width = (lines[1][:from][:x] - lines[0][:from][:x]).round 2
      col2_width = (lines[2][:from][:x] - lines[1][:from][:x]).round 2
      col3_width = (lines[3][:from][:x] - lines[2][:from][:x]).round 2
      (expect col1_width).to eql col2_width
      (expect col2_width).to eql col3_width
    end

    it 'should apply automatic width to columns by default when autowidth option is set and width attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: :line
      [%autowidth,frame=sides,grid=cols]
      |===
      |a | bbbbb | a
      |===
      EOS

      lines = pdf.lines.uniq {|it| [it[:from][:x], it[:from][:y], it[:to][:x], it[:to][:y]] }
      (expect lines).to have_size 4
      col1_width = (lines[1][:from][:x] - lines[0][:from][:x]).round 2
      col2_width = (lines[2][:from][:x] - lines[1][:from][:x]).round 2
      col3_width = (lines[3][:from][:x] - lines[2][:from][:x]).round 2
      (expect col1_width).to eql col3_width
      (expect col2_width).to be > col1_width
    end

    it 'should allocate remaining width to autowidth column' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols="10,>~"]
      |===
      |0x00
      |UNSPECIFIED

      |0x01
      |OK
      |===
      EOS
      (expect pdf.strings).to eql %w(0x00 UNSPECIFIED 0x01 OK)
      unspecified_text = (pdf.find_text 'UNSPECIFIED')[0]
      (expect unspecified_text[:x].floor).to be 476
      ok_text = (pdf.find_text 'OK')[0]
      (expect ok_text[:x].floor).to be 529
    end

    it 'should extend width of table to fit content in autowidth column when autowidth option is set on table' do
      pdf = to_pdf <<~'EOS', analyze: true
      [%autowidth,cols="10,>~"]
      |===
      |0x00
      |UNSPECIFIED

      |0x01
      |OK
      |===
      EOS
      (expect pdf.strings).to eql %w(0x00 UNSPECIFIED 0x01 OK)
      unspecified_text = (pdf.find_text 'UNSPECIFIED')[0]
      (expect unspecified_text[:x].floor).to be 81
      ok_text = (pdf.find_text 'OK')[0]
      (expect ok_text[:x].floor).to be 135
    end

    it 'should account for line metrics in cell padding' do
      input = <<~'EOS'
      |===
      |A |B

      |A1
      |B1

      |A2
      |B2
      |===
      EOS

      last_y = nil
      [5, [5, 5, 5, 5]].each do |cell_padding|
        pdf = to_pdf input, pdf_theme: { table_cell_padding: cell_padding }, analyze: true
        a2_text = (pdf.find_text 'A2')[0]
        (expect a2_text[:y]).to eql last_y if last_y
        last_y = a2_text[:y]
      end

      pdf = to_pdf input, pdf_theme: { base_line_height: 2, table_cell_padding: 5 }, analyze: true
      a2_text = (pdf.find_text 'A2')[0]
      (expect a2_text[:y]).to be < last_y
    end

    it 'should account for font size when computing padding' do
      input = <<~'EOS'
      |===
      |A |B

      |A1
      |B1

      |A2
      |B2
      |===
      EOS

      pdf = to_pdf input, pdf_theme: { table_font_size: 20 }, analyze: true
      a2_text = (pdf.find_text 'A2')[0]
      # we can't really use a reference here, so we'll check for an specific offset
      (expect a2_text[:y]).to be < 708
    end

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

      # NOTE: the line under the head row should moved down
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

      # NOTE: the first body row should be moved down
      (expect a1_text[:y]).to be < reference_a1_text[:y]
    end

    it 'should not split cells in head row across pages' do
      hard_line_break = %( +\n)
      filler = (['filler'] * 40).join hard_line_break
      head_cell1 = %w(this is a very tall cell in the head row of this table).join hard_line_break
      head_cell2 = %w(this is an even taller cell also in the head row of this table).join hard_line_break
      pdf = to_pdf <<~EOS, analyze: true
      #{filler}

      [%header,cols=2*]
      |===
      |#{head_cell1}
      |#{head_cell2}

      |body cell
      |body cell
      |===
      EOS

      filler_page_nums = (pdf.find_text 'filler').map {|it| it[:page_number] }
      (expect filler_page_nums.uniq).to have_size 1
      (expect filler_page_nums[0]).to be 1
      table_cell_page_nums = pdf.text.reject {|it| it[:string] == 'filler' }.map {|it| it[:page_number] }
      (expect table_cell_page_nums.uniq).to have_size 1
      (expect table_cell_page_nums[0]).to be 2
    end
  end

  context 'Basic table cell' do
    it 'should keep paragraphs in table cell separate' do
      pdf = to_pdf <<~'EOS', analyze: true
      |===
      |all one line

      |line 1 +
      line 2

      |paragraph 1

      paragraph 2
      |===
      EOS

      cell1_text = pdf.find_text 'all one line'
      (expect cell1_text).not_to be_empty
      cell2_text = pdf.find_text %r/^line (?:1|2)/
      (expect cell2_text).to have_size 2
      (expect cell2_text[0][:y]).to be > cell2_text[1][:y]
      cell3_text = pdf.find_text %r/^paragraph (?:1|2)/
      (expect cell3_text).to have_size 2
      (expect cell3_text[0][:y]).to be > cell3_text[1][:y]
      (expect cell3_text[0][:y] - cell3_text[1][:y]).to be > (cell2_text[0][:y] - cell2_text[1][:y])
    end

    it 'should normalize newlines and whitespace' do
      pdf = to_pdf <<~EOS, analyze: true
      |===
      |He's  a  real  nowhere  man,
      Sitting in his nowhere land,
      Making all his nowhere plans\tfor nobody.
      |===
      EOS
      (expect pdf.text).to have_size 1
      text = pdf.text[0][:string]
      (expect text).not_to include '  '
      (expect text).not_to include ?\t
      (expect text).not_to include ?\n
      (expect text).to include 'man, Sitting'
    end

    it 'should strip whitespace after applying substitutions' do
      ['%autowidth', '%header%autowidth'].each do |table_attrs|
        pdf = to_pdf <<~EOS, analyze: :line
        [#{table_attrs}]
        |===
        | text
        |===

        <<<

        [#{table_attrs}]
        |===
        | text {empty}
        |===

        <<<

        [#{table_attrs}]
        |===
        | {empty} text
        |===
        EOS

        lines_by_page = pdf.lines.each_with_object Hash.new do |line, accum|
          (accum[line.delete :page_number] ||= []) << line
        end
        (expect lines_by_page[1]).to have_size 4
        (2..3).each do |rownum|
          (expect lines_by_page[1]).to eql lines_by_page[rownum]
        end
      end
    end

    it 'should transform non-ASCII letters when text transform is uppercase' do
      pdf = to_pdf <<~'EOS', pdf_theme: { table_head_text_transform: 'uppercase' }, analyze: true
      |===
      |über |étudier

      |cell
      |cell
      |===
      EOS

      text = pdf.text
      (expect text[0][:string]).to eql 'ÜBER'
      (expect text[1][:string]).to eql 'ÉTUDIER'
    end

    it 'should apply text transform for head to heading cell' do
      {
        'uppercase' => ['HEADING IN HEAD', 'HEADING IN BODY'],
        'lowercase' => ['heading in head', 'heading in body'],
        'none' => ['Heading in head', 'Heading in body'],
      }.each do |transform, expected|
        pdf = to_pdf <<~'EOS', pdf_theme: { table_head_text_transform: transform }, analyze: true
        |===
        |Heading in head

        h|Heading in body
        |===
        EOS

        text = pdf.text
        (expect text[0][:string]).to eql expected[0]
        (expect text[1][:string]).to eql expected[1]
      end
    end

    it 'should honor horizontal alignment on cell' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols="1,>1"]
      |===
      |a |z
      |===
      EOS

      page_width = pdf.pages[0][:size][0]
      midpoint = page_width * 0.5
      a_text = (pdf.find_text 'a')[0]
      z_text = (pdf.find_text 'z')[0]
      (expect a_text[:x]).to be < midpoint
      (expect z_text[:x]).to be > midpoint
    end

    it 'should truncate cell that exceeds the height of a single page' do
      (expect do
        blank_line = %(\n\n)

        pdf = to_pdf <<~EOS, analyze: true
        |===
        |before
        |start

        #{(['middle'] * 23).join blank_line}

        end
        |after
        |===
        EOS

        (expect pdf.pages.size).to eql 3
        before_text = (pdf.find_text 'before')[0]
        (expect before_text[:page_number]).to eql 1
        start_text = (pdf.find_text 'start')[0]
        (expect start_text[:page_number]).to eql 2
        end_text = (pdf.find_text 'end')[0]
        (expect end_text).to be_nil
        (expect (pdf.find_text 'middle').map {|it| it[:page_number] }.uniq).to eql [2]
        after_text = (pdf.find_text 'after')[0]
        (expect after_text[:page_number]).to eql 3
      end).to log_message severity: :ERROR, message: 'the table cell on page 2 has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page'
    end
  end

  context 'Strong table cell' do
    it 'should style text a strong table cell as bold' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols=2*,width=50%]
      |===
      |Item 1
      |$10

      |Item 2
      |$5

      >s|Total
      |$15
      |===
      EOS

      item_text = (pdf.find_text 'Item 1')[0]
      total_text = (pdf.find_text 'Total')[0]
      (expect total_text[:font_name]).to eql 'NotoSerif-Bold'
      (expect total_text[:x]).to be > item_text[:x]
    end
  end

  context 'Monospaced table cell' do
    it 'should apply literal style to text in a monospaced table cell' do
      pdf = to_pdf <<~'EOS', pdf_theme: { literal_font_size: 10.25 }, analyze: true
      [cols="1m,1",width=50%]
      |===
      m|site.title
      |The title of the site.

      m|site.url
      |The URL of the site.
      |===
      EOS

      literal_text = (pdf.find_text 'site.title')[0]
      (expect literal_text[:font_name]).to eql 'mplus1mn-regular'
      (expect literal_text[:font_color]).to eql 'B12146'
      (expect literal_text[:font_size]).to eql 10.25
    end
  end

  context 'Header table cell' do
    it 'should style a header table cell like a cell in the head row by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      [%autowidth,cols="1h,3"]
      |===
      | Vendor
      | Samsung

      | Model
      | Galaxy s10

      | OS
      | Android 9.0 Pie

      | Resolution
      | 3040x1440
      |===
      EOS

      vendor_text = (pdf.find_text 'Vendor')[0]
      (expect vendor_text[:font_name]).to eql 'NotoSerif-Bold'
      model_text = (pdf.find_text 'Model')[0]
      (expect model_text[:font_name]).to eql 'NotoSerif-Bold'
    end

    it 'should allow theme to modify style of header cell in table body independent of cell in table head' do
      pdf_theme = {
        table_head_font_color: '222222',
        table_header_cell_font_style: 'italic',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      [%header%autowidth,cols="1h,3"]
      |===
      | Feature | Value

      | Vendor
      | Samsung

      | Model
      | Galaxy s10

      | OS
      | Android 9.0 Pie

      | Resolution
      | 3040x1440
      |===
      EOS

      feature_text = (pdf.find_text 'Feature')[0]
      (expect feature_text[:font_color]).to eql '222222'
      (expect feature_text[:font_name]).to eql 'NotoSerif-Bold'
      vendor_text = (pdf.find_text 'Vendor')[0]
      (expect vendor_text[:font_color]).to eql '222222'
      (expect vendor_text[:font_name]).to eql 'NotoSerif-Italic'
      model_text = (pdf.find_text 'Model')[0]
      (expect model_text[:font_color]).to eql '222222'
      (expect model_text[:font_name]).to eql 'NotoSerif-Italic'
      samsung_text = (pdf.find_text 'Samsung')[0]
      (expect samsung_text[:font_color]).to eql '333333'
      (expect samsung_text[:font_name]).to eql 'NotoSerif'
    end

    it 'should not set background color on header cell if theme sets background color of table to nil', visual: true do
      pdf_theme = {
        page_background_color: 'CCCCCC',
        table_background_color: nil,
      }

      to_file = to_pdf_file <<~'EOS', 'table-transparent-header-cell.pdf', pdf_theme: pdf_theme
      [%header%autowidth,cols="1h,3"]
      |===
      | Feature | Value

      | Vendor
      | Samsung

      | Model
      | Galaxy s10

      | OS
      | Android 9.0 Pie

      | Resolution
      | 3040x1440
      |===
      EOS

      (expect to_file).to visually_match 'table-transparent-header-cell.pdf'
    end
  end

  context 'Foot' do
    it 'should allow theme to configure font properties of foot' do
      pdf_theme = {
        table_foot_font_style: 'bold',
        table_foot_font_size: 11,
        table_foot_font_family: 'Helvetica',
        table_foot_font_color: '5d5d5d',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true

      [%footer]
      |===
      |Item |Quantity

      |Item 1
      |1

      |Item 2
      |2

      |Item 3
      |3

      |Total |6
      |===
      EOS

      total_text = pdf.find_unique_text 'Total'
      (expect total_text[:font_name]).to eql 'Helvetica-Bold'
      (expect total_text[:font_size]).to eql 11
      (expect total_text[:font_color]).to eql '5D5D5D'
    end
  end

  context 'Literal table cell' do
    it 'should not apply substitutions' do
      pdf = to_pdf <<~'EOS', analyze: true
      |===
      l|{asciidoctor-version} foo--bar
      |===
      EOS

      (expect pdf.lines[0]).to eql '{asciidoctor-version} foo--bar'
    end

    it 'should expand tabs and preserve indentation' do
      pdf = to_pdf <<~EOS, analyze: true
      |===
      l|
      here
      \twe
      \t\tgo
      again
      |===
      EOS

      lines = pdf.lines
      (expect lines).to have_size 4
      (expect lines[1]).to eql %(\u00a0   we)
      (expect lines[2]).to eql %(\u00a0       go)
    end

    it 'should not double escape specialchars' do
      pdf = to_pdf <<~'EOS', analyze: true
      |===
      l|< and >
      |===
      EOS

      (expect pdf.lines).to eql ['< and >']
    end

    it 'should scale font size by same amount as applied to table' do
      pdf_theme = {
        table_font_size: 8,
        code_font_size: 10.5,
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      |===
      |normal cell l|literal cell
      |===
      EOS

      (expect (pdf.find_text 'normal cell')[0][:font_size].to_f).to eql 8.0
      (expect (pdf.find_text 'literal cell')[0][:font_size].to_f).to eql 8.0
    end
  end

  context 'Verse table cell' do
    it 'should support verse if supported by core' do
      pdf = to_pdf <<~'EOS', analyze: true
      |===
      v|foo
        bar
      |===
      EOS

      foobar_text = (pdf.find_text 'foo bar')[0]
      (expect foobar_text).not_to be_nil
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
      (expect pdf.lines).to eql ['10. ten', '11. eleven', '12. twelve', 'buckle', 'my', 'shoe']
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
      (expect pdf.lines[1]).to eql 'Nested table cell 1 Nested table cell 2'
      nested_cell1 = (pdf.find_text 'Nested table cell 1')[0]
      nested_cell2 = (pdf.find_text 'Nested table cell 2')[0]
      (expect nested_cell1[:y]).to eql nested_cell2[:y]
      (expect nested_cell1[:x]).to be < nested_cell2[:x]
    end

    it 'should not fail to fit content in table cell and create blank page when margin bottom is 0' do
      pdf_theme = {
        base_font_family: 'M+ 1mn',
        prose_margin_bottom: 0,
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      |===
      a|
      * abc
      |===
      EOS

      p1_lines = pdf.lines (pdf.page 1)[:text]
      (expect p1_lines).to eql ['• abc']
      (expect pdf.pages).to have_size 1
    end

    it 'should not fail to fit content in table cell and create blank page when margin bottom is positive' do
      pdf_theme = {
        base_font_family: 'M+ 1mn',
        prose_margin_bottom: 2,
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      before

      |===
      a|
      * abc
      * xyz
      |===

      after
      EOS

      p1_lines = pdf.lines (pdf.page 1)[:text]
      (expect p1_lines).to eql ['before', '• abc', '• xyz', 'after']
      (expect pdf.pages).to have_size 1
    end

    it 'should draw border around entire delimited block with text that wraps' do
      pdf_theme = {
        code_background_color: 'transparent',
        code_border_radius: 0,
      }

      input = <<~EOS
      [cols="1,1a",frame=none,grid=none]
      |===
      | cell
      |
      before block

      ----
      #{lorem_ipsum '1-sentence'}
      #{lorem_ipsum '1-sentence'}
      #{lorem_ipsum '1-sentence'}
      #{lorem_ipsum '1-sentence'}
      ----

      after block
      |===
      EOS

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 4
      border_bottom_y = lines[2][:from][:y]

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true

      last_block_text = (pdf.find_text font_name: 'mplus1mn-regular')[-1]

      (expect border_bottom_y).to be < last_block_text[:y]

      after_block_text = (pdf.find_text 'after block')[0]

      (expect after_block_text[:y]).to be < border_bottom_y
    end

    it 'should honor vertical alignment' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols=2*]
      |===
      | 1 +
      2 +
      3 +
      4

      .^a|
      AsciiDoc cell
      |===
      EOS

      ref_below = (pdf.find_text '2')[0][:y]
      ref_above = (pdf.find_text '3')[0][:y]
      asciidoc_y = (pdf.find_text 'AsciiDoc cell')[0][:y]
      (expect asciidoc_y).to be < ref_below
      (expect asciidoc_y).to be > ref_above
    end

    it 'should coerce middle vertical alignment on head cell to center' do
      pdf = to_pdf <<~'EOS', analyze: true
      [%header,width=50%]
      |===
      ^.^| Short ^.^| Something Rather Long ^.^| Last
      |===
      EOS

      long_text = pdf.find_unique_text 'Something'
      short_text = pdf.find_unique_text 'Short'
      (expect long_text[:y]).to be > short_text[:y]
    end

    it 'should apply cell padding to AsciiDoc table cell' do
      pdf = to_pdf <<~'EOS', pdf_theme: { table_cell_padding: 10 }, analyze: true
      |===
      | a a| b | c
      | a | b | c
      |===
      EOS

      a_texts = pdf.find_text 'a'
      b_texts = pdf.find_text 'b'
      (expect a_texts[0][:y]).to eql b_texts[0][:y]
      (expect b_texts[0][:x]).to eql b_texts[1][:x]
    end

    it 'should inherit font properties from table' do
      pdf_theme = {
        table_font_size: 8.5,
        table_font_color: 'AA0000',
        table_font_style: 'italic',
        table_font_family: 'Helvetica',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      |===
      | normal table cell a| AsciiDoc table cell
      |===
      EOS

      normal_text = (pdf.find_text 'normal table cell')[0]
      (expect normal_text[:font_name]).to eql 'Helvetica-Oblique'
      (expect normal_text[:font_color]).to eql 'AA0000'
      (expect normal_text[:font_size]).to eql 8.5
      asciidoc_text = (pdf.find_text 'AsciiDoc table cell')[0]
      (expect asciidoc_text[:font_name]).to eql 'Helvetica-Oblique'
      (expect asciidoc_text[:font_color]).to eql 'AA0000'
      (expect asciidoc_text[:font_size]).to eql 8.5
    end

    it 'should scale font size of nested blocks proportionally' do
      pdf_theme = {
        table_font_size: 8.5,
        table_font_family: 'Helvetica',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      ....
      literal block outside table
      ....

      |===
      a|
      ....
      literal block inside table
      ....
      |===
      EOS

      outside_text = (pdf.find_text 'literal block outside table')[0]
      (expect outside_text[:font_name]).to eql 'mplus1mn-regular'
      (expect outside_text[:font_size]).to eql 11
      inside_text = (pdf.find_text 'literal block inside table')[0]
      (expect inside_text[:font_name]).to eql 'mplus1mn-regular'
      (expect inside_text[:font_size]).to be < 9
    end

    it 'should scale font size of nested blocks consistently, even if table is nested inside a block' do
      pdf_theme = {
        base_font_size: 12,
        code_font_size: 10,
        sidebar_font_size: 8,
        table_font_size: 9,
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      |===
      a|
      ....
      literal block outside sidebar
      ....
      |===

      ====
      |===
      a|
      ....
      literal block inside sidebar
      ....
      |===
      ====
      EOS

      outside_text = (pdf.find_text 'literal block outside sidebar')[0]
      (expect outside_text[:font_name]).to eql 'mplus1mn-regular'
      (expect outside_text[:font_size]).to eql 7.5
      inside_text = (pdf.find_text 'literal block inside sidebar')[0]
      (expect inside_text[:font_name]).to eql 'mplus1mn-regular'
      (expect outside_text[:font_size]).to eql 7.5
    end

    it 'should not inherit font properties from table if table_asciidoc_cell_style key is set to initial in theme' do
      pdf_theme = {
        table_asciidoc_cell_style: 'initial',
        table_font_size: 8.5,
        table_font_color: 'AA0000',
        table_font_style: 'italic',
        table_font_family: 'Helvetica',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      |===
      | normal table cell a| AsciiDoc table cell
      |===
      EOS

      normal_text = (pdf.find_text 'normal table cell')[0]
      (expect normal_text[:font_name]).to eql 'Helvetica-Oblique'
      (expect normal_text[:font_color]).to eql 'AA0000'
      (expect normal_text[:font_size]).to eql 8.5
      asciidoc_text = (pdf.find_text 'AsciiDoc table cell')[0]
      (expect asciidoc_text[:font_name]).to eql 'NotoSerif'
      (expect asciidoc_text[:font_color]).to eql '333333'
      (expect asciidoc_text[:font_size]).to eql 10.5
    end

    it 'should not allow AsciiDoc table cell to bleed into footer' do
      pdf_theme = {
        footer_columns: '<100%',
        footer_recto_center_content: 'footer text',
        footer_verso_center_content: 'footer text',
        footer_padding: 0,
      }

      (expect do
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, enable_footer: true, analyze: true
        |===
        |before
        a|start

        #{['* middle'] * 34 * ?\n}

        end
        |after
        |===
        EOS

        (expect pdf.pages.size).to eql 3
        p2_text = pdf.find_text page_number: 2
        footer_text = p2_text.find {|it| it[:string] == 'footer text' }
        p2_text = p2_text.reject {|it| it == footer_text }
        (expect p2_text[-1][:y]).to be > footer_text[:y]
      end).to log_message severity: :ERROR, message: 'the table cell on page 2 has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page'
    end

    it 'should truncate cell that exceeds the height of a single page' do
      (expect do
        blank_line = %(\n\n)

        pdf = to_pdf <<~EOS, analyze: true
        |===
        |before
        a|start

        #{(['middle'] * 30).join blank_line}

        end
        |after
        |===
        EOS

        (expect pdf.pages.size).to eql 3
        before_text = (pdf.find_text 'before')[0]
        (expect before_text[:page_number]).to eql 1
        start_text = (pdf.find_text 'start')[0]
        (expect start_text[:page_number]).to eql 2
        end_text = (pdf.find_text 'end')[0]
        (expect end_text).to be_nil
        (expect (pdf.find_text 'middle').map {|it| it[:page_number] }.uniq).to eql [2]
        after_text = (pdf.find_text 'after')[0]
        (expect after_text[:page_number]).to eql 3
      end).to log_message severity: :ERROR, message: 'the table cell on page 2 has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page'
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

    it 'should restrict caption to width of table by default', visual: true do
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

    it 'should not restrict caption to width of table if table_caption_max_width key in theme is none' do
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

    it 'should set caption to percentage of table width as specified by argument to fit-content function' do
      pdf = to_pdf <<~'EOS', pdf_theme: { table_caption_max_width: 'fit-content(50%)' }, analyze: true
      :!table-caption:

      .A rather long description for this table
      [width=30%]
      |===
      | Col A | Col B | Col C | Col D
      |===
      EOS

      expected_lines = <<~'EOS'.lines.map(&:chomp)
      A rather long
      description for
      this table
      Col A Col B Col C Col D
      EOS

      (expect pdf.lines).to eql expected_lines

      page_width = (get_page_size pdf)[0]
      caption_text = (pdf.find_text 'A rather long')[0]
      content_area_width = page_width - (caption_text[:x] * 2)
      (expect caption_text[:width]).to be < (content_area_width * 0.15)
    end

    it 'should be able to control alignment of caption box and text independently using theme' do
      pdf_theme = {
        table_caption_align: 'center',
        table_caption_text_align: 'left',
        table_caption_max_width: '15%',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      :table-caption!:

      .A rather long description for this table
      [%autowidth]
      |===
      | Col A | Col B
      |===
      EOS

      caption_texts = pdf.find_text font_name: 'NotoSerif-Italic'
      (expect caption_texts).to have_size 3
      (expect caption_texts.map {|it| it[:x] }.uniq).to have_size 1
    end

    it 'should allow theme to constrain caption to fixed width' do
      [144, '144'].each do |it|
        pdf_theme = { table_caption_max_width: it }
        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        :table-caption!:

        .A rather long description for this table
        |===
        | Col A | Col B
        |===
        EOS

        caption_lines = pdf.lines pdf.find_text font_name: 'NotoSerif-Italic'
        (expect caption_lines).to eql ['A rather long description for', 'this table']
      end
    end

    it 'should allow theme to set caption alignment to inherit from table' do
      pdf = to_pdf <<~'EOS', pdf_theme: { table_caption_align: 'inherit' }, analyze: true
      .Right-aligned caption
      [width=25%,align=right]
      |===
      |1 |2
      |3 |4
      |===
      EOS

      first_cell_text = (pdf.find_text '1')[0]
      caption_text = (pdf.find_text %r/^Table 1\./)[0]
      (expect caption_text[:x]).to be > first_cell_text[:x]
    end

    it 'should allow theme to set caption alignment to right and text alignment to left' do
      pdf_theme = {
        table_caption_align: 'right',
        table_caption_text_align: 'left',
        table_caption_max_width: 'fit-content(50%)',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      .Right-aligned caption
      [width=25%,align=right]
      |===
      |1 |2
      |3 |4
      |===
      EOS

      caption_prefix_text = pdf.find_unique_text 'Table 1.'
      caption_wrap_text = pdf.find_unique_text 'caption'
      cell2_text = pdf.find_unique_text '2'
      (expect caption_prefix_text[:x]).to be_within(3).of(cell2_text[:x])
      (expect caption_prefix_text[:x]).to eql caption_wrap_text[:x]
    end

    it 'should allow theme to set caption alignment to right and inherit text alignment' do
      pdf_theme = {
        table_caption_align: 'right',
        table_caption_text_align: 'inherit',
        table_caption_max_width: 'fit-content(50%)',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      .Right-aligned caption
      [width=25%,align=right]
      |===
      |1 |2
      |3 |4
      |===
      EOS

      caption_prefix_text = pdf.find_unique_text 'Table 1.'
      caption_wrap_text = pdf.find_unique_text 'caption'
      cell2_text = pdf.find_unique_text '2'
      (expect caption_prefix_text[:x] - 5).to be > cell2_text[:x]
      (expect caption_wrap_text[:x]).to be > caption_prefix_text[:x]
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
      (expect a1_text[:page_number]).to be 1
      (expect a3_text[:x]).to be > (page_width * 0.5)
      (expect a3_text[:page_number]).to be 2
      first_list_item_text = (pdf.find_text 'list item', page_number: 2)[0]
      last_list_item_text = (pdf.find_text 'list item', page_number: 3)[-1]
      # NOTE: if this is off, the margin box got mangled
      (expect last_list_item_text[:x]).to eql first_list_item_text[:x]
    end

    it 'should set width of aligned table relative to bounds' do
      pdf = to_pdf <<~'EOS', analyze: true
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

    it 'should break line on any CJK character if value of scripts attribute is cjk' do
      pdf = to_pdf <<~'EOS', analyze: true
      :scripts: cjk
      :pdf-theme: default-with-fallback-font

      |===
      | AsciiDoc 是一个人类可读的文件格式，语义上等同于 DocBook 的 XML，但使用纯文本标记了约定。可以使用任何文本编辑器创建文件把 AsciiDoc 和阅读“原样”，或呈现为HTML 或由 DocBook 的工具链支持的任何其他格式，如 PDF，TeX 的，Unix 的手册页，电子书，幻灯片演示等。
      | AsciiDoc は、意味的には DocBook XML のに相当するが、プレーン·テキスト·マークアップの規則を使用して、人間が読めるドキュメントフォーマット、である。 AsciiDoc は文書は、任意のテキストエディタを使用して作成され、「そのまま"または、HTML や DocBook のツールチェーンでサポートされている他のフォーマット、すなわち PDF、TeX の、Unix の man ページ、電子書籍、スライドプレゼンテーションなどにレンダリングすることができます。
      |===
      EOS
      lines = pdf.lines
      (expect lines).to have_size 8
      (expect lines[0]).to end_with '任何'
      (expect lines[1]).to start_with '文本'
      (expect lines[3]).to end_with '使用'
      (expect lines[4]).to start_with 'して'
    end
  end

  context 'Cell spanning' do
    it 'should honor colspan on cell in head row' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols=2*^]
      |===
      2+|Columns

      |cell
      |cell
      |===
      EOS

      page_width = (get_page_size pdf)[0]
      midpoint = page_width * 0.5
      columns_text = (pdf.find_text 'Columns')[0]
      (expect columns_text[:x]).to be < midpoint
      (expect columns_text[:x] + columns_text[:width]).to be > midpoint
      (expect pdf.find_text 'cell').to have_size 2
    end

    it 'should honor colspan on cell in body row' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols=2*^]
      |===
      |cell
      |cell

      2+|one big cell
      |===
      EOS

      page_width = (get_page_size pdf)[0]
      midpoint = page_width * 0.5
      big_cell_text = (pdf.find_text 'one big cell')[0]
      (expect big_cell_text[:x]).to be < midpoint
      (expect big_cell_text[:x] + big_cell_text[:width]).to be > midpoint
      (expect pdf.find_text 'cell').to have_size 2
    end

    it 'should honor rowspan on cell in body row' do
      pdf = to_pdf <<~'EOS', analyze: true
      [cols=2*^.^]
      |===
      .2+|one big cell
      |cell

      |cell
      |===
      EOS

      big_cell_text = (pdf.find_text 'one big cell')[0]
      top_cell_text, bottom_cell_text = pdf.find_text 'cell'
      (expect top_cell_text[:x]).to eql bottom_cell_text[:x]
      (expect top_cell_text[:y]).to be > bottom_cell_text[:y]
      (expect big_cell_text[:x]).to be < top_cell_text[:x]
      (expect big_cell_text[:y]).to be < top_cell_text[:y]
      (expect big_cell_text[:y]).to be > bottom_cell_text[:y]
    end
  end
end
