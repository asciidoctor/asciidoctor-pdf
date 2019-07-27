require_relative 'spec_helper'

describe Asciidoctor::PDF::Converter do
  context 'legacy module name' do
    it 'should map Asciidoctor::Pdf module to Asciidoctor::PDF' do
      (expect Asciidoctor::Pdf).to be Asciidoctor::PDF
      (expect Asciidoctor::Pdf::VERSION).to be Asciidoctor::PDF::VERSION
      (expect Asciidoctor::Pdf::Converter).to be Asciidoctor::PDF::Converter
      (expect Asciidoctor::Pdf::ThemeLoader).to be Asciidoctor::PDF::ThemeLoader
    end
  end

  context '.register_for' do
    it 'should self register to handle pdf backend' do
      registered = asciidoctor_2_or_better? ? (Asciidoctor::Converter.for 'pdf') : (Asciidoctor::Converter::Factory.resolve 'pdf')
      (expect registered).to be Asciidoctor::PDF::Converter
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

  context '#convert' do
    it 'should not fail to convert empty string' do
      (expect to_pdf '').to_not be_nil
    end

    it 'should not fail to convert empty file' do
      pdf = to_pdf Pathname.new fixture_file 'empty.adoc'
      (expect Pathname.new output_file 'empty.pdf').to exist
      (expect pdf.page_count).to be > 0
    end

    it 'should ensure data-uri attribute is set' do
      doc = Asciidoctor.load <<~'EOS', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      image::logo.png[]
      EOS
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end if asciidoctor_2_or_better?

    it 'should ignore data-uri attribute entry in document' do
      doc = Asciidoctor.load <<~'EOS', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      :!data-uri:

      image::logo.png[]
      EOS
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end if asciidoctor_2_or_better?

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
      pdf = Asciidoctor.convert <<~'EOS', backend: 'pdf', pdf_theme: theme
      content
      EOS

      (expect pdf.instance_variable_get :@theme).to be theme
    end

    it 'should log error if theme cannot be found or loaded' do
      (expect {
        Asciidoctor.convert 'foo', backend: 'pdf', attributes: { 'pdf-theme' => 'foo' }
      }).to (raise_exception Errno::ENOENT) & (log_message severity: :ERROR, message: '~could not locate or load the built-in pdf theme `foo\'')
    end

    it 'should convert background position to options' do
      converter = asciidoctor_2_or_better? ? (Asciidoctor::Converter.create 'pdf') : (Asciidoctor::Converter::Factory.create 'pdf')
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
end
