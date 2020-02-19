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

    it 'should convert file in secure mode' do
      input_file = fixture_file 'secure.adoc'
      output_file = output_file 'secure.pdf'
      doc = Asciidoctor.convert_file input_file, backend: 'pdf', to_dir: output_dir, safe: 'secure'
      (expect doc.attr 'outfile').to be_nil
      pdf = PDF::Reader.new output_file
      (expect pdf.pages).to have_size 2
      (expect pdf.pages[0].text).to include 'Book Title'
      (expect pdf.pages[1].text).to include 'Chapter'
      images = get_images pdf
      (expect images).to have_size 1
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
        }.each do |value, expected|
          (expect converter.resolve_background_position value).to eql expected
        end
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
