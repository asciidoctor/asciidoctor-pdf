require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Xref' do
  context 'internal' do
    it 'should create reference to a section by title' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book

      == Chapter A

      You can find details in <<Chapter B>>.

      == Chapter B

      Here are the details you're looking for.
      EOS

      names = get_names pdf
      (expect names).to have_key '_chapter_a'
      (expect names).to have_key '_chapter_b'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql '_chapter_b'
      (expect (pdf.page 2).text).to include 'Chapter B'
    end

    it 'should create reference to a section by implicit ID' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book

      == Chapter A

      You can find details in <<_chapter_b>>.

      == Chapter B

      Here are the details you're looking for.
      EOS

      names = get_names pdf
      (expect names).to have_key '_chapter_a'
      (expect names).to have_key '_chapter_b'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql '_chapter_b'
      (expect (pdf.page 2).text).to include 'Chapter B'
    end

    it 'should create reference to a section by explicit ID' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book

      [#a]
      == Chapter A

      You can find details in <<b>>.

      [#b]
      == Chapter B

      Here are the details you're looking for.
      EOS

      names = get_names pdf
      (expect names).to have_key 'a'
      (expect names).to have_key 'b'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'b'
      (expect (pdf.page 2).text).to include 'Chapter B'
    end

    it 'should create reference to a block by explicit ID' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book

      == Summary

      You can find the observed values in the <<observed-values,table>>.

      == Data

      [#observed-values]
      |===
      | Subject | Count

      | foo
      | 2

      | bar
      | 1
      |===
      EOS

      names = get_names pdf
      (expect names).to have_key 'observed-values'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'observed-values'
      (expect (pdf.page 2).text).to include 'table'
    end

    it 'should create reference to a list item with an anchor' do
      pdf = to_pdf <<~'EOS'
      Jump to the <<first-item>>.

      <<<

      * [[first-item,first item]]list item
      EOS

      names = get_names pdf
      (expect names).to have_key 'first-item'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'first-item'
      if asciidoctor_1_5_7_or_better?
        (expect (pdf.page 1).text).to include 'first item'
      else
        (expect (pdf.page 1).text).to include '[first-item]'
      end
    end

    it 'should create reference to a table cell with an anchor' do
      pdf = to_pdf <<~'EOS'
      Jump to the <<first-cell>>.

      <<<

      |===
      |[[first-cell,first cell]]table cell
      |===
      EOS

      names = get_names pdf
      (expect names).to have_key 'first-cell'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'first-cell'
      if asciidoctor_1_5_7_or_better?
        (expect (pdf.page 1).text).to include 'first cell'
      else
        (expect (pdf.page 1).text).to include '[first-cell]'
      end
    end
  end

  context 'interdocument' do
    it 'should convert interdocument xrefs to internal references' do
      input_file = Pathname.new fixture_file 'book.adoc'
      pdf = to_pdf input_file
      p2_annotations = get_annotations pdf, 2
      (expect p2_annotations).to have_size 1
      chapter_2_ref = p2_annotations[0]
      (expect chapter_2_ref[:Subtype]).to eql :Link
      (expect chapter_2_ref[:Dest]).to eql '_chapter_2'
      p3_annotations = get_annotations pdf, 3
      first_steps_ref = p3_annotations[0]
      (expect first_steps_ref[:Subtype]).to eql :Link
      (expect first_steps_ref[:Dest]).to eql '_first_steps'
    end

    it 'should link self-referencing interdocument xref to built-in __anchor-top ref' do
      pdf = to_pdf Pathname.new fixture_file 'reference-to-self.adoc'
      (expect Pathname.new output_file 'reference-to-self.pdf').to exist
      annotations = get_annotations pdf
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql '__anchor-top'
    end
  end

  context 'xrefstyle' do
    it 'should refer to chapter by label and number when xrefstyle is short' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: short

      Start with <<_a>>.

      == A
      EOS

      (expect pdf.lines).to include 'Start with Chapter 1.'
    end if asciidoctor_1_5_7_or_better?

    it 'should refer to chapter title and number when xrefstyle is basic' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: basic

      Start with <<_a>>.

      == A
      EOS

      (expect pdf.lines).to include 'Start with A.'
    end

    it 'should refer to chapter label, number and title when xrefstyle is full' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: full

      Start with <<_a>>.

      == A
      EOS

      (expect pdf.lines).to include 'Start with Chapter 1, A.'
    end if asciidoctor_1_5_7_or_better?

    it 'should use xrefstyle specified on xref macro' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: short

      Start with xref:_a[xrefstyle=full].

      == A
      EOS

      (expect pdf.lines).to include 'Start with Chapter 1, A.'
    end if asciidoctor_1_5_7_or_better?

    it 'should refer to image with title by reference signifier and number when xrefstyle is short' do
      pdf = to_pdf <<~'EOS', analyze: true
      :xrefstyle: short

      See <<img>>.

      .Title of Image
      [#img]
      image::tux.png[]
      EOS

      (expect pdf.lines[0]).to eql 'See Figure 1.'
    end if asciidoctor_1_5_7_or_better?
  end
end
