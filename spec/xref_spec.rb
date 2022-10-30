# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Xref' do
  context 'internal' do
    it 'should create reference to a section by title' do
      pdf = to_pdf <<~'END'
      = Document Title
      :doctype: book

      == Chapter A

      You can find details in <<Chapter B>>.

      == Chapter B

      Here are the details you're looking for.
      END

      names = get_names pdf
      (expect names).to have_key '_chapter_a'
      (expect names).to have_key '_chapter_b'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql '_chapter_b'
      (expect (pdf.page 2).text).to include 'Chapter B'
    end

    it 'should create reference to a section by implicit ID' do
      pdf = to_pdf <<~'END'
      = Document Title
      :doctype: book

      == Chapter A

      You can find details in <<_chapter_b>>.

      == Chapter B

      Here are the details you're looking for.
      END

      names = get_names pdf
      (expect names).to have_key '_chapter_a'
      (expect names).to have_key '_chapter_b'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql '_chapter_b'
      (expect (pdf.page 2).text).to include 'Chapter B'
    end

    it 'should create reference to a section by explicit ID' do
      pdf = to_pdf <<~'END'
      = Document Title
      :doctype: book

      [#a]
      == Chapter A

      You can find details in <<b>>.

      [#b]
      == Chapter B

      Here are the details you're looking for.
      END

      names = get_names pdf
      (expect names).to have_key 'a'
      (expect names).to have_key 'b'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'b'
      (expect (pdf.page 2).text).to include 'Chapter B'
    end

    it 'should short-circuit circular reference in section title' do
      pdf = to_pdf <<~'END', analyze: true
      [#a]
      == A <<b>>

      [#b]
      == B <<a>>
      END

      (expect pdf.lines).to eql ['A B [a]', 'B [a]']
      lines = pdf.text.map {|it| it[:y] }.uniq
      (expect pdf.find_unique_text 'B [a]', font_color: '428BCA', y: lines[0]).not_to be_nil
      (expect pdf.find_unique_text '[a]', font_color: '428BCA', y: lines[1]).not_to be_nil
    end

    it 'should reference section with ID that contains non-ASCII characters' do
      pdf = to_pdf <<~'END'
      == Über Étudier

      See <<_über_étudier>>.
      END

      hex_encoded_id = %(0x#{('_über_étudier'.unpack 'H*')[0]})
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql hex_encoded_id
      (expect (pdf.page 1).text).to include 'See Über Étudier.'
    end

    it 'should create reference to a block by explicit ID' do
      pdf = to_pdf <<~'END'
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
      END

      names = get_names pdf
      (expect names).to have_key 'observed-values'
      annotations = get_annotations pdf, 2
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'observed-values'
      (expect (pdf.page 2).text).to include 'table'
    end

    it 'should create reference to an anchor in a paragraph' do
      pdf = to_pdf <<~'END'
      Jump to the <<explanation>>.

      <<<

      [[explanation,explanation]]This is the explanation.
      END

      names = get_names pdf
      (expect names).to have_key 'explanation'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'explanation'
      (expect (pdf.page 1).text).to include 'explanation'
    end

    it 'should create reference to a list item with an anchor' do
      pdf = to_pdf <<~'END'
      Jump to the <<first-item>>.

      <<<

      * [[first-item,first item]]list item
      END

      names = get_names pdf
      (expect names).to have_key 'first-item'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'first-item'
      (expect (pdf.page 1).text).to include 'first item'
    end

    it 'should create reference to a table cell with an anchor' do
      pdf = to_pdf <<~'END'
      Jump to the <<first-cell>>.

      <<<

      |===
      |[[first-cell,first cell]]table cell
      |===
      END

      names = get_names pdf
      (expect names).to have_key 'first-cell'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'first-cell'
      (expect (pdf.page 1).text).to include 'first cell'
    end

    it 'should show ID enclosed in square brackets if reference cannot be resolved' do
      pdf = to_pdf <<~'END'
      Road to <<nowhere>>.
      END

      (expect (pdf.page 1).text).to eql 'Road to [nowhere].'
      names = get_names pdf
      (expect names).not_to have_key 'nowhere'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'nowhere'
    end
  end

  context 'interdocument' do
    it 'should convert interdocument xref to PDF link' do
      input_file = Pathname.new fixture_file 'reference-to-sibling.adoc'
      pdf = to_pdf input_file
      p2_annotations = get_annotations pdf, 2
      (expect p2_annotations).to have_size 2
      book_ref = p2_annotations[0]
      (expect book_ref[:Subtype]).to be :Link
      (expect book_ref[:A][:S]).to eql :URI
      (expect book_ref[:A][:URI]).to eql 'book.pdf'
    end

    it 'should convert deep interdocument xref to PDF link with fragment' do
      input_file = Pathname.new fixture_file 'reference-to-sibling.adoc'
      pdf = to_pdf input_file
      p2_annotations = get_annotations pdf, 2
      (expect p2_annotations).to have_size 2
      first_steps_ref = p2_annotations[1]
      (expect first_steps_ref[:Subtype]).to be :Link
      (expect first_steps_ref[:A][:S]).to eql :URI
      (expect first_steps_ref[:A][:URI]).to eql 'book.pdf#_first_steps'
    end

    it 'should use path as fallback text for interdocument xref' do
      pdf = to_pdf 'Refer to the xref:admin-guide.adoc[] to learn how to configure the system.'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      admin_guide_ref = annotations[0]
      (expect admin_guide_ref[:Subtype]).to be :Link
      (expect admin_guide_ref[:A][:S]).to eql :URI
      (expect admin_guide_ref[:A][:URI]).to eql 'admin-guide.pdf'
      (expect (pdf.page 1).text).to eql 'Refer to the admin-guide.pdf to learn how to configure the system.'
    end

    it 'should convert interdocument xrefs included in current document to internal references' do
      input_file = Pathname.new fixture_file 'book.adoc'
      pdf = to_pdf input_file
      p2_annotations = get_annotations pdf, 2
      (expect p2_annotations).to have_size 1
      chapter_2_ref = p2_annotations[0]
      (expect chapter_2_ref[:Subtype]).to be :Link
      (expect chapter_2_ref[:Dest]).to eql '_chapter_2'
      p3_annotations = get_annotations pdf, 3
      first_steps_ref = p3_annotations[0]
      (expect first_steps_ref[:Subtype]).to be :Link
      (expect first_steps_ref[:Dest]).to eql '_first_steps'
    end

    it 'should link self-referencing interdocument xref with text to built-in __anchor-top ref' do
      pdf = to_pdf Pathname.new fixture_file 'reference-to-self.adoc'
      (expect Pathname.new output_file 'reference-to-self.pdf').to exist
      annotations = get_annotations pdf
      (expect annotations).to have_size 2
      (expect annotations[0][:Dest]).to eql '__anchor-top'
      (expect (pdf.page 3).text).to eql 'go to top'
    end

    it 'should link self-referencing interdocument xref without text to built-in __anchor-top ref' do
      pdf = to_pdf Pathname.new fixture_file 'reference-to-self.adoc'
      (expect Pathname.new output_file 'reference-to-self.pdf').to exist
      annotations = get_annotations pdf
      (expect annotations).to have_size 2
      (expect annotations[1][:Dest]).to eql '__anchor-top'
      (expect (pdf.page 4).text).to eql '[^top]'
    end
  end

  context 'xrefstyle' do
    it 'should refer to part by label and number when xrefstyle is short' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :partnums:
      :xrefstyle: short

      = Beginner

      == Basic Lesson

      Now you are ready for <<_advanced>>!

      = Advanced

      == Advanced Lesson

      If you are so advanced, why do you even need a lesson?
      END

      (expect pdf.lines).to include 'Now you are ready for Part II!'
    end

    it 'should refer to part by name when xrefstyle is basic' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :partnums:
      :xrefstyle: basic

      = Beginner

      == Basic Lesson

      Now you are ready for <<_advanced>>!

      = Advanced

      == Advanced Lesson

      If you are so advanced, why do you even need a lesson?
      END

      (expect pdf.lines).to include 'Now you are ready for Advanced!'
    end

    it 'should refer to part by label, number, and title when xrefstyle is full' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :partnums:
      :xrefstyle: full

      = Beginner

      == Basic Lesson

      Now you are ready for <<_advanced>>!

      = Advanced

      == Advanced Lesson

      If you are so advanced, why do you even need a lesson?
      END

      (expect pdf.lines).to include 'Now you are ready for Part II, “Advanced”!'
    end

    it 'should refer to chapter by label and number when xrefstyle is short' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: short

      Start with <<_a>>.

      == A
      END

      (expect pdf.lines).to include 'Start with Chapter 1.'
    end

    it 'should refer to chapter title and number when xrefstyle is basic' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: basic

      Start with <<_a>>.

      == A
      END

      (expect pdf.lines).to include 'Start with A.'
    end

    it 'should refer to chapter label, number and title when xrefstyle is full' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: full

      Start with <<_a>>.

      == A
      END

      (expect pdf.lines).to include 'Start with Chapter 1, A.'
    end

    it 'should use xrefstyle specified on xref macro' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :sectnums:
      :xrefstyle: short

      Start with xref:_a[xrefstyle=full].

      == A
      END

      (expect pdf.lines).to include 'Start with Chapter 1, A.'
    end

    it 'should refer to image with title by title by default' do
      pdf = to_pdf <<~'END', analyze: true
      See <<img>>.

      .Title of Image
      [#img]
      image::tux.png[]
      END

      (expect pdf.lines[0]).to eql 'See Title of Image.'
    end

    it 'should refer to image with title by reference signifier, number, and title when xrefstyle is full' do
      pdf = to_pdf <<~'END', analyze: true
      :xrefstyle: full

      See <<img>>.

      .Title of Image
      [#img]
      image::tux.png[]
      END

      (expect pdf.lines[0]).to eql 'See Figure 1, “Title of Image”.'
    end

    it 'should refer to image with title by reference signifier and number when xrefstyle is short' do
      pdf = to_pdf <<~'END', analyze: true
      :xrefstyle: short

      See <<img>>.

      .Title of Image
      [#img]
      image::tux.png[]
      END

      (expect pdf.lines[0]).to eql 'See Figure 1.'
    end

    it 'should show ID of reference enclosed in square brackets if reference has no xreftext' do
      pdf = to_pdf <<~'END'
      :xrefstyle: full

      Jump to the <<first-item>>.

      <<<

      * [[first-item]]list item
      END

      names = get_names pdf
      (expect names).to have_key 'first-item'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'first-item'
      (expect (pdf.page 1).text).to include '[first-item]'
    end
  end
end
