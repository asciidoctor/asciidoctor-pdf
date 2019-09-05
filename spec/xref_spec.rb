require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Xref' do
  context 'Interdocument' do
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
    end

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
    end
  end
end
