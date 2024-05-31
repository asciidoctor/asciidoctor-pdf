# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - PDF Info' do
  context 'compliance' do
    it 'should generate a PDF 1.4-compatible document by default' do
      (expect (to_pdf 'hello').pdf_version).to eql 1.4
    end

    it 'should set PDF version specified by pdf-version attribute if valid' do
      (expect (to_pdf 'hello', attributes: { 'pdf-version' => '1.6' }).pdf_version).to eql 1.6
    end

    it 'should generate a PDF 1.4-compatible document if value of pdf-version attribute is not recognized' do
      (expect (to_pdf 'hello', attributes: { 'pdf-version' => '3.0' }).pdf_version).to eql 1.4
    end
  end

  context 'attribution' do
    it 'should set the Creator field to empty by default' do
      creator = (to_pdf 'hello').info[:Creator]
      (expect creator).to be_empty
    end

    it 'should set the Producer field to Asciidoctor PDF and Prawn by default' do
      producer = (to_pdf 'hello').info[:Producer]
      (expect producer).not_to be_nil
      (expect producer).to include %(Asciidoctor PDF #{Asciidoctor::PDF::VERSION})
      (expect producer).to include %(Prawn #{Prawn::VERSION})
    end

    it 'should allow Producer field to be overridden using producer attribute' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :producer: ACME

      hello
      EOS
      producer = pdf.info[:Producer]
      (expect producer).not_to be_nil
      (expect producer).to eql 'ACME'
    end

    it 'should set the Creator field to the author if author is specified' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      Author Name

      hello
      EOS
      creator = pdf.info[:Creator]
      (expect creator).to eql 'Author Name'
    end

    it 'should set Author and Creator field to value of author attribute if set' do
      ['Author Name', ':author: Author Name'].each do |author_line|
        pdf = to_pdf <<~EOS
        = Document Title
        #{author_line}

        content
        EOS
        (expect pdf.info[:Author]).to eql 'Author Name'
        (expect pdf.info[:Creator]).to eql pdf.info[:Author]
      end
    end

    it 'should set Author and Creator field to value of author attribute if set to multiple authors' do
      ['Author Name; Assistant Name', ':authors: Author Name; Assistant Name'].each do |author_line|
        pdf = to_pdf <<~EOS
        = Document Title
        #{author_line}

        [%hardbreaks]
        First Author: {author_1}
        Second Author: {author_2}
        EOS
        lines = ((pdf.page 1).text.split ?\n).map(&:strip)
        (expect pdf.info[:Author]).to eql 'Author Name, Assistant Name'
        (expect pdf.info[:Creator]).to eql pdf.info[:Author]
        (expect lines).to include 'First Author: Author Name'
        (expect lines).to include 'Second Author: Assistant Name'
      end
    end

    it 'should set Author and Creator field using authors attribute with non-Latin characters' do
      ['Doc Writer; Antonín Dvořák', ':authors: Doc Writer; Antonín Dvořák'].each do |author_line|
        pdf = to_pdf <<~EOS
        = Document Title
        #{author_line}

        [%hardbreaks]
        First Author: {author_1}
        Second Author: {author_2}
        EOS
        lines = ((pdf.page 1).text.split ?\n).map(&:strip)
        (expect pdf.info[:Author]).to eql 'Doc Writer, Antonín Dvořák'
        (expect pdf.info[:Creator]).to eql pdf.info[:Author]
        (expect lines).to include 'First Author: Doc Writer'
        (expect lines).to include 'Second Author: Antonín Dvořák'
      end
    end

    it 'should set Author field to value of author attribute if locked by the API' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'author' => 'Doc Writer' }
      = Document Title
      Author Name

      content
      EOS
      (expect pdf.info[:Author]).to eql 'Doc Writer'
    end

    it 'should set Author field to value of authors attribute if locked by the API' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'authors' => 'Doc Writer' }
      = Document Title
      Author Name

      content
      EOS
      (expect pdf.info[:Author]).to eql 'Doc Writer'
    end

    it 'should set Author field to value of authors attribute if both author and authors attributes are locked by the API' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'authors' => 'Doc Writer', 'author' => 'Anonymous' }
      = Document Title
      Author Name

      content
      EOS
      (expect pdf.info[:Author]).to eql 'Doc Writer'
    end

    it 'should set Author field to value of author attribute if document has no doctitle' do
      pdf = to_pdf <<~'EOS'
      :author: Author Name

      == Section Title

      content
      EOS
      (expect pdf.info[:Author]).to eql 'Author Name'
    end

    it 'should set Author field to value of authors attribute if document has no doctitle' do
      pdf = to_pdf <<~'EOS'
      :authors: Author Name

      == Section Title

      content
      EOS
      (expect pdf.info[:Author]).to eql 'Author Name'
    end

    it 'should set Creator field to value of publisher attribute if set' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      Author Name
      :publisher: Big Cheese

      content
      EOS
      (expect pdf.info[:Author]).to eql 'Author Name'
      (expect pdf.info[:Creator]).to eql 'Big Cheese'
    end

    it 'should set Subject field to value of subject attribute if set' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :subject: Cooking

      content
      EOS
      (expect pdf.info[:Subject]).to eql 'Cooking'
    end

    it 'should set Keywords field to value of subject attribute if set' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :keywords: cooking, diet, plants

      content
      EOS
      (expect pdf.info[:Keywords]).to eql 'cooking, diet, plants'
    end

    it 'should sanitize values of Author, Subject, Keywords, and Producer fields' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      D&#95;J Allen
      :subject: Science &amp; Math
      :keywords: mass&#8211;energy equivalence
      :publisher: Schr&#246;dinger&#8217;s Cat

      content
      EOS

      pdf_info = pdf.info
      (expect pdf_info[:Author]).to eql 'D_J Allen'
      (expect pdf_info[:Subject]).to eql 'Science & Math'
      (expect pdf_info[:Keywords]).to eql 'mass–energy equivalence'
      (expect pdf_info[:Creator]).to eql 'Schrödinger’s Cat'
    end

    it 'should parse date attributes as local date objects' do
      pdf = to_pdf 'content', attribute_overrides: { 'docdatetime' => '2019-01-15', 'localdatetime' => '2019-01-15' }
      (expect pdf.info[:ModDate]).not_to be_nil
      (expect pdf.info[:ModDate]).to start_with 'D:20190115000000'
      (expect pdf.info[:CreationDate]).not_to be_nil
      (expect pdf.info[:CreationDate]).to start_with 'D:20190115000000'
    end

    it 'should set date attributes to same current date when date attributes cannot be parsed' do
      pdf = to_pdf 'content', attribute_overrides: { 'docdatetime' => 'garbage', 'localdatetime' => 'garbage' }
      (expect pdf.info[:ModDate]).not_to be_nil
      (expect pdf.info[:ModDate]).to start_with 'D:'
      (expect pdf.info[:CreationDate]).not_to be_nil
      (expect pdf.info[:CreationDate]).to start_with 'D:'
      (expect pdf.info[:ModDate]).to eql pdf.info[:CreationDate]
    end

    it 'should use current date as fallback when docdatetime cannot be parsed' do
      expected = (Time.now.strftime '%s').to_i
      pdf = to_pdf 'content', attribute_overrides: { 'docdatetime' => 'garbage' }
      mod_date = pdf.info[:ModDate]
      (expect mod_date).not_to be_nil
      (expect mod_date).to start_with 'D:'
      actual = ((DateTime.parse (mod_date.slice 2, mod_date.length).gsub ?', '').strftime '%s').to_i
      (expect actual).to be_within(1).of(expected)
    end

    it 'should use current date as fallback when localdatetime cannot be parsed' do
      expected = (Time.now.strftime '%s').to_i
      pdf = to_pdf 'content', attribute_overrides: { 'localdatetime' => 'garbage' }
      creation_date = pdf.info[:CreationDate]
      (expect creation_date).not_to be_nil
      (expect creation_date).to start_with 'D:'
      actual = ((DateTime.parse (creation_date.slice 2, creation_date.length).gsub ?', '').strftime '%s').to_i
      (expect actual).to be_within(1).of(expected)
    end

    it 'should not add dates to document if reproducible attribute is set' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'reproducible' => '' }
      = Document Title
      Author Name

      content
      EOS

      (expect pdf.info[:ModDate]).to be_nil
      (expect pdf.info[:CreationDate]).to be_nil
    end

    it 'should not add software versions to document if reproducible attribute is set' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'reproducible' => '' }
      = Document Title
      Author Name

      content
      EOS

      (expect pdf.info[:Producer]).to eql 'Asciidoctor PDF, based on Prawn'
    end

    it 'should set mod and creation dates to match SOURCE_DATE_EPOCH environment variable' do
      old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
      ENV['SOURCE_DATE_EPOCH'] = '1234123412'
      pdf = to_pdf 'content'
      (expect pdf.info[:ModDate]).to eql 'D:20090208200332+00\'00\''
      (expect pdf.info[:CreationDate]).to eql 'D:20090208200332+00\'00\''
    ensure
      if old_source_date_epoch
        ENV['SOURCE_DATE_EPOCH'] = old_source_date_epoch
      else
        ENV.delete 'SOURCE_DATE_EPOCH'
      end
    end
  end

  context 'document title' do
    it 'should set Title field to value of untitled-label attribute if doctitle is not set' do
      pdf = to_pdf 'body'
      (expect pdf.info[:Title]).to eql 'Untitled'
    end

    it 'should not set Title field if untitled-label attribute is unset and doctitle is not set' do
      pdf = to_pdf 'body', attribute_overrides: { 'untitled-label' => nil }
      (expect pdf.info).not_to have_key :Title
    end

    it 'should set Title field to value of document title if set' do
      pdf = to_pdf '= Document Title'
      (expect pdf.info[:Title]).to eql 'Document Title'
    end

    it 'should remove text formatting from document title before assigning to Title field' do
      pdf = to_pdf '= *Document* _Title_'
      (expect pdf.info[:Title]).to eql 'Document Title'
    end

    it 'should decode character references in document title before assigning to Title field' do
      pdf = to_pdf '= ACME(TM) Catalog <&#8470; 1>'
      (expect pdf.info[:Title]).to eql %(ACME\u2122 Catalog <\u2116 1>)
    end

    it 'should hex encode non-ASCII characters in Title field' do
      doctitle = 'Guide de démarrage rapide'
      pdf = to_pdf %(= #{doctitle})
      (expect pdf.info[:Title]).to eql doctitle
      encoded_doctitle = pdf.objects[pdf.objects.trailer[:Info]][:Title].unpack 'H*'
      (expect encoded_doctitle).to eql (doctitle.encode Encoding::UTF_16).unpack 'H*'
    end
  end

  context 'compress' do
    it 'should not compress streams by default' do
      pdf = to_pdf 'foobar'
      objects = pdf.objects
      pages = pdf.objects.values.find {|it| Hash === it && it[:Type] == :Pages }
      stream = objects[objects[pages[:Kids][0]][:Contents]]
      (expect stream.hash[:Filter]).to be_nil
      (expect stream.data).to include '/DeviceRGB'
    end

    it 'should compress streams if compress attribute is set on document' do
      pdf = to_pdf 'foobar', attribute_overrides: { 'compress' => '' }
      objects = pdf.objects
      pages = pdf.objects.values.find {|it| Hash === it && it[:Type] == :Pages }
      stream = objects[objects[pages[:Kids][0]][:Contents]]
      (expect stream.hash[:Filter]).to eql [:FlateDecode]
      (expect stream.data).not_to include '/DeviceRGB'
    end

    it 'should not compress streams when compress attribute is set on document and page is imported' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'compress' => '' }
      before

      image::red-green-blue.pdf[page=1]

      after
      EOS
      objects = pdf.objects
      pages = pdf.objects.values.find {|it| Hash === it && it[:Type] == :Pages }
      objects[pages[:Kids][1]][:Contents].map {|it| objects[it] }.each do |stream|
        (expect stream.hash[:Filter]).to be_nil
        (expect stream.data).to include '/DeviceRGB'
      end

      stream = objects[objects[pages[:Kids][0]][:Contents]]
      (expect stream.hash[:Filter]).to be_nil
      (expect stream.data).to include '/DeviceRGB'

      stream = objects[objects[pages[:Kids][2]][:Contents]]
      (expect stream.hash[:Filter]).to be_nil
      (expect stream.data).to include '/DeviceRGB'
    end
  end
end
