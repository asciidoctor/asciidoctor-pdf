# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::PDF::Converter do
  describe '.register_for' do
    it 'should self register to handle pdf backend' do
      registered = Asciidoctor::Converter.for 'pdf'
      (expect registered).to be described_class
    end

    it 'should convert AsciiDoc string to PDF object when backend is pdf' do
      (expect Asciidoctor.convert 'hello', backend: 'pdf').to be_a Prawn::Document
    end

    it 'should convert AsciiDoc file to PDF file when backend is pdf' do
      pdf = to_pdf Pathname.new fixture_file 'hello.adoc'
      (expect Pathname.new output_file 'hello.pdf').to exist
      (expect pdf.page_count).to be > 0
    end
  end

  describe '#convert' do
    it 'should not fail to convert empty string' do
      (expect to_pdf '').not_to be_nil
    end

    it 'should not fail to convert empty file' do
      pdf = to_pdf Pathname.new fixture_file 'empty.adoc'
      (expect Pathname.new output_file 'empty.pdf').to exist
      (expect pdf.page_count).to be > 0
    end

    it 'should convert file to target dir in secure mode' do
      input_file = fixture_file 'secure.adoc'
      target_file = output_file 'secure.pdf'
      doc = Asciidoctor.convert_file input_file, backend: 'pdf', to_dir: output_dir, safe: 'secure'
      (expect doc.attr 'outfile').to be_nil
      pdf = PDF::Reader.new target_file
      (expect pdf.pages).to have_size 2
      (expect pdf.pages[0].text).to include 'Book Title'
      (expect pdf.pages[1].text).to include 'Chapter'
      images = get_images pdf
      (expect images).to have_size 1
    end

    it 'should convert file to target file in secure mode' do
      input_file = fixture_file 'secure.adoc'
      target_file = output_file 'secure-alt.pdf'
      Asciidoctor.convert_file input_file, backend: 'pdf', to_file: target_file, safe: 'secure'
      (expect Pathname.new target_file).to exist
      pdf = PDF::Reader.new target_file
      (expect pdf.pages).to have_size 2
      (expect pdf.pages[0].text).to include 'Book Title'
      (expect pdf.pages[1].text).to include 'Chapter'
      images = get_images pdf
      (expect images).to have_size 1
    end

    it 'should be able to load, convert, and write in separate steps' do
      input_file = fixture_file 'hello.adoc'
      target_file = output_file 'hello.pdf'
      doc = Asciidoctor.load_file input_file, backend: 'pdf'
      doc.write doc.convert, target_file
      (expect Pathname.new target_file).to exist
      pdf = PDF::Reader.new target_file
      (expect pdf.pages).to have_size 1
    end

    it 'should be able to reuse instance of converter' do
      input_file = fixture_file 'book.adoc'
      doc = Asciidoctor.load_file input_file, backend: 'pdf', safe: :safe, attributes: { 'reproducible' => '' }
      converter = doc.converter
      pdf1 = doc.convert.render
      doc = Asciidoctor.load_file input_file, backend: 'pdf', safe: :safe, attributes: { 'reproducible' => '' }, converter: converter
      pdf2 = doc.convert.render
      (expect pdf1).to eql pdf2
    end

    it 'should warn if convert method is not found for node' do
      (expect do
        doc = Asciidoctor.load <<~'EOS', backend: 'pdf', safe: :safe, attributes: { 'nofooter' => '' }
        before

        1,2,3

        after
        EOS
        doc.blocks[1].context = :chart
        pdf_stream = StringIO.new
        doc.write doc.convert, pdf_stream
        pdf = PDF::Reader.new pdf_stream
        pages = pdf.pages
        (expect pages).to have_size 1
        lines = pdf.pages[0].text.lines.map(&:rstrip).reject(&:empty?)
        (expect lines).to eql %w(before after)
      end).to log_message severity: :WARN, message: 'missing convert handler for chart node in pdf backend'
    end

    it 'should not warn if convert method is not found for node in scratch document' do
      (expect do
        doc = Asciidoctor.load <<~'EOS', backend: 'pdf', safe: :safe, attributes: { 'nofooter' => '' }
        before

        [%unbreakable]
        --
        1,2,3
        --

        after
        EOS
        doc.blocks[1].blocks[0].context = :chart
        pdf_stream = StringIO.new
        doc.write doc.convert, pdf_stream
        pdf = PDF::Reader.new pdf_stream
        pages = pdf.pages
        (expect pages).to have_size 1
        lines = pdf.pages[0].text.lines.map(&:rstrip).reject(&:empty?)
        (expect lines).to eql %w(before after)
      end).to log_message severity: :WARN, message: 'missing convert handler for chart node in pdf backend'
    end

    it 'should ensure data-uri attribute is set' do
      doc = Asciidoctor.load <<~'EOS', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      image::logo.png[]
      EOS
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end

    it 'should ignore data-uri attribute entry in document' do
      doc = Asciidoctor.load <<~'EOS', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      :!data-uri:

      image::logo.png[]
      EOS
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end

    it 'should not fail to remove tmp files if already removed' do
      image_data = File.read (fixture_file 'square.jpg'), mode: 'r:UTF-8'
      encoded_image_data = Base64.strict_encode64 image_data
      doc = Asciidoctor.load <<~EOS, backend: 'pdf'
      :page-background-image: image:data:image/png;base64,#{encoded_image_data}[Square,fit=cover]
      EOS
      pdf_doc = doc.convert
      tmp_files = (converter = doc.converter).instance_variable_get :@tmp_files
      (expect tmp_files).to have_size 1
      tmp_files.each {|_, path| converter.send :unlink_tmp_file, path }
      doc.write pdf_doc, (pdf_io = StringIO.new)
      pdf = PDF::Reader.new pdf_io
      (expect get_images pdf).to have_size 1
    end

    it 'should not fail to remove tmp files if they are not writable' do
      (expect do
        image_data = File.read (fixture_file 'square.jpg'), mode: 'r:UTF-8'
        encoded_image_data = Base64.strict_encode64 image_data
        doc = Asciidoctor.load <<~EOS, backend: 'pdf'
        :page-background-image: image:data:image/png;base64,#{encoded_image_data}[Square,fit=cover]
        EOS
        pdf_doc = doc.convert
        tmp_files = doc.converter.instance_variable_get :@tmp_files
        (expect tmp_files).to have_size 1
        tmp_file_paths = tmp_files.map do |_, path|
          FileUtils.mv path, (tmp_path = %(#{path}-tmp))
          Dir.mkdir path
          FileUtils.mv tmp_path, (File.join path, (File.basename path))
          path
        end
        doc.write pdf_doc, (pdf_io = StringIO.new)
        pdf = PDF::Reader.new pdf_io
        (expect get_images pdf).to have_size 1
        tmp_file_paths.each {|path| FileUtils.rm_r path, force: true, secure: true }
      end).to log_message severity: :WARN, message: '~could not delete temporary file'
    end

    it 'should keep tmp files if KEEP_ARTIFACTS environment variable is set' do
      image_data = File.read (fixture_file 'square.jpg'), mode: 'r:UTF-8'
      encoded_image_data = Base64.strict_encode64 image_data
      doc = Asciidoctor.load <<~EOS, backend: 'pdf'
      :page-background-image: image:data:image/png;base64,#{encoded_image_data}[Square,fit=cover]
      EOS
      pdf_doc = doc.convert
      tmp_files = doc.converter.instance_variable_get :@tmp_files
      (expect tmp_files).to have_size 1
      ENV['KEEP_ARTIFACTS'] = 'true'
      doc.write pdf_doc, (pdf_io = StringIO.new)
      ENV.delete 'KEEP_ARTIFACTS'
      pdf = PDF::Reader.new pdf_io
      (expect get_images pdf).to have_size 1
      (expect tmp_files).to have_size 1
      tmp_files.each do |_, path|
        (expect Pathname.new path).to exist
        File.unlink path
      end
    end

    context 'theme' do
      it 'should apply the theme at the path specified by pdf-theme' do
        %w(theme style).each do |term|
          pdf = to_pdf <<~EOS, analyze: true
          = Document Title
          :pdf-#{term}: #{fixture_file 'red-theme.yml', relative: true}

          red text
          EOS

          (expect pdf.find_text font_color: 'FF0000').to have_size pdf.text.size
        end
      end

      it 'should only load theme from pdf-themesdir if pdf-theme attribute specified' do
        %w(theme style).each do |term|
          [nil, 'default'].each do |theme|
            to_pdf_opts = { analyze: true }
            to_pdf_opts[:attribute_overrides] = { %(pdf-#{term}) => theme } if theme
            pdf = to_pdf <<~EOS, to_pdf_opts
            = Document Title
            :pdf-#{term}sdir: #{fixtures_dir}

            body text
            EOS

            expected_font_color = theme ? 'AA0000' : '333333'
            body_text = (pdf.find_text 'body text')[0]
            (expect body_text).not_to be_nil
            (expect body_text[:font_color]).to eql expected_font_color
          end
        end
      end

      it 'should apply the named theme specified by pdf-theme located in the specified pdf-themesdir' do
        %w(theme style).each do |term|
          pdf = to_pdf <<~EOS, analyze: true
          = Document Title
          :pdf-#{term}: red
          :pdf-#{term}sdir: #{fixtures_dir}

          red text
          EOS

          (expect pdf.find_text font_color: 'FF0000').to have_size pdf.text.size
        end
      end

      it 'should use theme passed in through :pdf_theme option' do
        theme = Asciidoctor::PDF::ThemeLoader.load_theme 'custom', fixtures_dir
        pdf = Asciidoctor.convert 'content', backend: 'pdf', pdf_theme: theme
        (expect pdf.instance_variable_get :@theme).to be theme
      end

      it 'should set themesdir theme with __dir__ is passed via :pdf_theme option' do
        theme = Asciidoctor::PDF::ThemeLoader.load_base_theme
        theme.delete_field :__dir__
        pdf = Asciidoctor.convert 'content', backend: 'pdf', pdf_theme: theme
        (expect pdf.instance_variable_get :@themesdir).to eql Dir.pwd
      end

      it 'should log error if built-in theme cannot be found or loaded' do
        (expect do
          Asciidoctor.convert 'foo', backend: 'pdf', attributes: { 'pdf-theme' => 'foo' }
        end).to log_message severity: :ERROR, message: '~could not locate or load the built-in pdf theme `foo\'; reverting to default theme'
      end

      it 'should log error if user theme cannot be found or loaded' do
        (expect do
          Asciidoctor.convert 'foo', backend: 'pdf', attributes: { 'pdf-theme' => 'foo', 'pdf-themesdir' => fixtures_dir }
        end).to log_message severity: :ERROR, message: %(~could not locate or load the pdf theme `foo\' in #{fixtures_dir}; reverting to default theme)
      end

      it 'should log error with filename and reason if theme file cannot be parsed' do
        pdf_theme = fixture_file 'tab-indentation-theme.yml'
        (expect do
          pdf = to_pdf 'content', attribute_overrides: { 'pdf-theme' => pdf_theme }, analyze: true
          (expect pdf.pages).to have_size 1
        end).to log_message severity: :ERROR, message: /because of Psych::SyntaxError \(#{Regexp.escape pdf_theme}\): found character .*that cannot start any token.*; reverting to default theme/
      end

      it 'should log error with filename and reason if exception is thrown during theme compilation' do
        (expect do
          pdf = to_pdf 'content', attribute_overrides: { 'pdf-theme' => (fixture_file 'invalid-theme.yml') }, analyze: true
          (expect pdf.pages).to have_size 1
        end).to log_message severity: :ERROR, message: /because of NoMethodError undefined method `start_with\?' for 10:(Fixnum|Integer); reverting to default theme/
      end

      it 'should not crash if theme does not specify any keys' do
        pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => (fixture_file 'extends-nil-empty-theme.yml') }, analyze: true
        = Document Title
        :doctype: book

        This is the stark theme.

        == Chapter Title

        === Section Title

        .dlist
        term:: desc

        .ulist
        * one
        * two
        * three
        EOS

        (expect pdf.pages).to have_size 3
        (expect pdf.find_text font_name: 'Helvetica', font_size: 12).to have_size pdf.text.size
        (expect (pdf.find_text 'Document Title')[0]).not_to be_nil
        (expect (pdf.find_text 'Chapter Title')[0]).not_to be_nil
        (expect (pdf.find_text 'Section Title')[0]).not_to be_nil
        (expect (pdf.find_text 'ulist')[0]).not_to be_nil
        (expect (pdf.find_text 'one')[0]).not_to be_nil
      end

      it 'should convert background position to options' do
        converter = Asciidoctor::Converter.create 'pdf'
        {
          'center' => { position: :center, vposition: :center },
          'top' => { position: :center, vposition: :top },
          'bottom' => { position: :center, vposition: :bottom },
          'left' => { position: :left, vposition: :center },
          'right' => { position: :right, vposition: :center },
          'top left' => { position: :left, vposition: :top },
          'right top' => { position: :right, vposition: :top },
          'bottom left' => { position: :left, vposition: :bottom },
          'right bottom' => { position: :right, vposition: :bottom },
          'center right' => { position: :right, vposition: :center },
          'left center' => { position: :left, vposition: :center },
          'center center' => { position: :center, vposition: :center },
          'bogus' => nil,
          'bogus bogus' => nil,
        }.each do |value, expected|
          (expect converter.resolve_background_position value, nil).to eql expected
        end
      end

      it 'should expose theme as property on converter' do
        doc = Asciidoctor.load 'yo', backend: :pdf
        doc.convert
        (expect doc.converter.theme).not_to be_nil
        (expect doc.converter.theme.base_font_family).to eql 'Noto Serif'
      end
    end
  end

  describe 'helpers' do
    it 'should not drop lines with unresolved attributes when apply_subs_discretely is called without options' do
      input = <<~'EOS'
      foo
      {undefined}
      bar
      EOS
      doc = Asciidoctor.load 'yo', backend: :pdf
      converter = doc.converter
      converter.load_theme doc
      result = converter.apply_subs_discretely doc, input
      (expect result).to eql input
    end

    it 'should raise exception if an unsupported unit of measurement is passed to to_pt' do
      (expect do
        converter = (Asciidoctor.load 'yo', backend: :pdf).converter
        converter.to_pt 3, 'ft'
      end).to raise_exception ArgumentError, /unknown unit of measurement: ft/
    end
  end

  describe 'extend' do
    it 'should use specified extended converter' do
      class CustomPDFConverter < (Asciidoctor::Converter.for 'pdf') # rubocop:disable RSpec/LeakyConstantDeclaration
        register_for :mypdf
        def convert_paragraph node
          layout_prose node.content, anchor: 'next-section'
        end
      end

      input = <<~'EOS'
      see next section

      [#next-section]
      == Next Section
      EOS

      pdf = to_pdf input, backend: :mypdf, analyze: true
      para_text = pdf.find_unique_text 'see next section'
      (expect para_text[:font_color]).to eql '428BCA'

      pdf = to_pdf input, backend: :mypdf
      (expect get_names pdf).to have_key 'next-section'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:Dest]).to eql 'next-section'
    end
  end
end
