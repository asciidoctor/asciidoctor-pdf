# frozen_string_literal: true

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

  it 'should set date to Unix epoch in UTC if reproducible attribute is set' do
    doc = Asciidoctor.load <<~'EOS', safe: :safe
    = Document Title
    Author Name
    :reproducible:

    body
    EOS

    contents = (subject.new doc).generate
    (expect contents).to include '/Title (Document Title)'
    (expect contents).to include '/ModDate (D:19700101000000+00\'00\')'
    (expect contents).to include '/CreationDate (D:19700101000000+00\'00\')'
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

  it 'should set mod and creation dates to match SOURCE_DATE_EPOCH environment variable' do
    old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
    begin
      ENV['SOURCE_DATE_EPOCH'] = '1234123412'
      doc = Asciidoctor.load 'content', safe: :safe
      contents = (subject.new doc).generate
      (expect contents).to include '/ModDate (D:20090208200332+00\'00\')'
      (expect contents).to include '/CreationDate (D:20090208200332+00\'00\')'
    ensure
      if old_source_date_epoch
        ENV['SOURCE_DATE_EPOCH'] = old_source_date_epoch
      else
        ENV.delete 'SOURCE_DATE_EPOCH'
      end
    end
  end
end
