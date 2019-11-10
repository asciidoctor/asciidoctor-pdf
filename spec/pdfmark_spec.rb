require_relative 'spec_helper'

describe Asciidoctor::PDF::Pdfmark do
  subject { described_class }

  it 'should generate pdfmark info from document' do
    doc = Asciidoctor.load <<~'EOS', safe: :safe
    = Materials Science and Engineering: An Introduction
    William D. Callister
    :doctype: book
    :docdatetime: 2018-01-17
    :localdatetime: 2018-01-17
    :subject: Materials Science
    :keywords: semiconductors, band gap
    EOS

    contents = (subject.new doc).generate
    (expect contents).to include '/Title (Materials Science and Engineering: An Introduction)'
    (expect contents).to include '/Author (William D. Callister)'
    (expect contents).to include '/Subject (Materials Science)'
    (expect contents).to include '/Keywords (semiconductors, band gap)'
    (expect contents).to include '/ModDate (D:20180117000000'
    (expect contents).to include '/CreationDate (D:20180117000000'
    (expect contents).to include '/Producer null'
    (expect contents).to end_with %(/DOCINFO pdfmark\n)
  end

  it 'should fallback to current date if dates are not parsable' do
    doc = Asciidoctor.load <<~'EOS', safe: :safe
    = Document Title
    Author Name
    :docdatetime: garbage
    :localdatetime: garbage

    body
    EOS

    expected_date = Time.now.to_pdf_object.slice 0, 11
    contents = (subject.new doc).generate
    (expect contents).to include '/Title (Document Title)'
    (expect contents).to include %(/ModDate #{expected_date})
    (expect contents).to include %(/CreationDate #{expected_date})
    (expect contents).to end_with %(/DOCINFO pdfmark\n)
  end
end
