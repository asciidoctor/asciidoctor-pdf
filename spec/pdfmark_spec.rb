# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::PDF::Pdfmark do
  subject { described_class }

  context 'generator' do
    it 'should generate pdfmark info from document' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      = Materials Science and Engineering: An Introduction
      William D. Callister
      :doctype: book
      :docdatetime: 2018-01-17
      :localdatetime: 2018-01-17
      :subject: Materials Science
      :keywords: semiconductors, band gap
      END

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

    it 'should use value of untitled-label as title if document has no header' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      == Section

      content
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Title (Untitled)'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should sanitize values of Author, Subject, Keywords, and Producer fields' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      = Document Title
      D&#95;J Allen
      :subject: Science &amp; Math
      :keywords: mass&#8211;energy equivalence
      :publisher: Schr&#246;dinger&#8217;s Cat

      content
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Author (D_J Allen)'
      (expect contents).to include '/Subject (Science & Math)'
      (expect contents).to include '/Keywords <feff006d00610073007320130065006e00650072006700790020006500710075006900760061006c0065006e00630065>'
      (expect contents).to include '/Producer <feff005300630068007200f600640069006e006700650072201900730020004300610074>'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should set Author field to value of author attribute if locked by the API' do
      doc = Asciidoctor.load <<~'END', safe: :safe, attributes: { 'author' => 'Doc Writer' }
      = Document Title
      Author Name

      content
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Author (Doc Writer)'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should set Author field to value of authors attribute if locked by the API' do
      doc = Asciidoctor.load <<~'END', safe: :safe, attributes: { 'authors' => 'Doc Writer' }
      = Document Title
      Author Name

      content
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Author (Doc Writer)'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should set Author field to value of authors attribute if both author and authors attribute locked by the API' do
      doc = Asciidoctor.load <<~'END', safe: :safe, attributes: { 'authors' => 'Doc Writer', 'author' => 'Anonymous' }
      = Document Title
      Author Name

      content
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Author (Doc Writer)'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should set Author field to value of author attribute if document has no doctitle' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      :author: Author Name

      == Section Title

      content
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Author (Author Name)'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should set Author field to value of authors attribute if document has no doctitle' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      :authors: Author Name

      == Section Title

      content
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Author (Author Name)'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should set date to Unix epoch in UTC if reproducible attribute is set' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      = Document Title
      Author Name
      :reproducible:

      body
      END

      contents = (subject.new doc).generate
      (expect contents).to include '/Title (Document Title)'
      (expect contents).to include '/ModDate (D:19700101000000+00\'00\')'
      (expect contents).to include '/CreationDate (D:19700101000000+00\'00\')'
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should fallback to current date if dates are not parsable' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      = Document Title
      Author Name
      :docdatetime: garbage
      :localdatetime: garbage

      body
      END

      expected_date = Time.now.to_pdf_object.slice 0, 11
      contents = (subject.new doc).generate
      (expect contents).to include '/Title (Document Title)'
      (expect contents).to include %(/ModDate #{expected_date})
      (expect contents).to include %(/CreationDate #{expected_date})
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should fallback to current date if only localdatetime is not parsable' do
      doc = Asciidoctor.load <<~'END', safe: :safe
      = Document Title
      Author Name
      :localdatetime: garbage

      body
      END

      expected_date = Time.now.to_pdf_object.slice 0, 11
      contents = (subject.new doc).generate
      (expect contents).to include '/Title (Document Title)'
      (expect contents).to include %(/CreationDate #{expected_date})
      (expect contents).to end_with %(/DOCINFO pdfmark\n)
    end

    it 'should set mod and creation dates to match SOURCE_DATE_EPOCH environment variable' do
      old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
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

  context 'pdfmark file' do
    it 'should generate pdfmark file if pdfmark attribute is set' do
      input_file = Pathname.new fixture_file 'book.adoc'
      pdfmark_file = Pathname.new output_file 'book.pdfmark'
      to_pdf input_file, to_dir: output_dir, attribute_overrides: { 'pdfmark' => '' }
      (expect pdfmark_file).to exist
      pdfmark_contents = pdfmark_file.read
      (expect pdfmark_contents).to include '/Title (Book Title)'
      (expect pdfmark_contents).to include '/Author (Author Name)'
      (expect pdfmark_contents).to include '/DOCINFO pdfmark'
    ensure
      File.unlink pdfmark_file
    end

    it 'should hex encode title if contains non-ASCII character' do
      input_file = Pathname.new fixture_file 'pdfmark-non-ascii-title.adoc'
      pdfmark_file = Pathname.new output_file 'pdfmark-non-ascii-title.pdfmark'
      to_pdf input_file, to_dir: output_dir, attribute_overrides: { 'pdfmark' => '' }
      (expect pdfmark_file).to exist
      pdfmark_contents = pdfmark_file.read
      (expect pdfmark_contents).to include '/Title <feff004c006500730020004d0069007300e9007200610062006c00650073>'
      (expect pdfmark_contents).to include '/Author (Victor Hugo)'
      (expect pdfmark_contents).to include '/Subject (June Rebellion)'
      (expect pdfmark_contents).to include '/Keywords (france, poor, rebellion)'
      (expect pdfmark_contents).to include '/DOCINFO pdfmark'
    ensure
      File.unlink pdfmark_file
    end
  end
end
