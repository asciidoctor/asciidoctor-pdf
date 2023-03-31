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
        doc = Asciidoctor.load <<~'END', backend: 'pdf', safe: :safe, attributes: { 'nofooter' => '' }
        before

        1,2,3

        after
        END
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
        doc = Asciidoctor.load <<~'END', backend: 'pdf', safe: :safe, attributes: { 'nofooter' => '' }
        before

        [%unbreakable]
        --
        1,2,3
        --

        after
        END
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
      doc = Asciidoctor.load <<~'END', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      image::logo.png[]
      END
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end

    it 'should ignore data-uri attribute entry in document' do
      doc = Asciidoctor.load <<~'END', backend: 'pdf', base_dir: fixtures_dir, safe: :safe
      :!data-uri:

      image::logo.png[]
      END
      (expect doc.attr? 'data-uri').to be true
      doc.convert
      (expect doc.attr? 'data-uri').to be true
    end

    it 'should not fail to remove tmp files if already removed' do
      image_data = File.read (fixture_file 'square.jpg'), mode: 'r:UTF-8'
      encoded_image_data = Base64.strict_encode64 image_data
      doc = Asciidoctor.load <<~END, backend: 'pdf'
      :page-background-image: image:data:image/png;base64,#{encoded_image_data}[Square,fit=cover]
      END
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
        doc = Asciidoctor.load <<~END, backend: 'pdf'
        :page-background-image: image:data:image/png;base64,#{encoded_image_data}[Square,fit=cover]
        END
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
        tmp_file_paths.each {|path| (Pathname.new path).rmtree secure: true }
      end).to log_message severity: :WARN, message: '~could not delete temporary file'
    end

    it 'should keep tmp files if KEEP_ARTIFACTS environment variable is set' do
      image_data = File.read (fixture_file 'square.jpg'), mode: 'r:UTF-8'
      encoded_image_data = Base64.strict_encode64 image_data
      doc = Asciidoctor.load <<~END, backend: 'pdf'
      :page-background-image: image:data:image/png;base64,#{encoded_image_data}[Square,fit=cover]
      END
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
        with_pdf_theme_file <<~'END' do |theme_path|
        base:
          font-color: ff0000
        END
          pdf = to_pdf <<~END, analyze: true
          = Document Title
          :pdf-theme: #{theme_path}

          red text
          END

          (expect pdf.find_text font_color: 'FF0000').to have_size pdf.text.size
        end
      end

      it 'should only load theme from pdf-themesdir if pdf-theme attribute specified' do
        [nil, 'default'].each do |theme|
          to_pdf_opts = { analyze: true }
          to_pdf_opts[:attribute_overrides] = { 'pdf-theme' => theme } if theme
          pdf = to_pdf <<~END, to_pdf_opts
          = Document Title
          :pdf-themesdir: #{fixtures_dir}

          body text
          END

          expected_font_color = theme ? 'AA0000' : '333333'
          body_text = (pdf.find_text 'body text')[0]
          (expect body_text).not_to be_nil
          (expect body_text[:font_color]).to eql expected_font_color
        end
      end

      it 'should apply the named theme specified by pdf-theme located in the specified pdf-themesdir' do
        with_pdf_theme_file <<~'END' do |theme_path|
        base:
          font-color: ff0000
        END
          pdf = to_pdf <<~END, analyze: true
          = Document Title
          :pdf-theme: #{File.basename theme_path, '-theme.yml'}
          :pdf-themesdir: #{File.dirname theme_path}

          red text
          END

          (expect pdf.find_text font_color: 'FF0000').to have_size pdf.text.size
        end
      end

      it 'should resolve pdf-themesdir relative to the current working directory' do
        input_file = Pathname.new fixture_file 'hello-with-custom-theme.adoc'
        relative_themesdir = fixture_file '.', relative: true
        pdf = to_pdf input_file, analyze: true, attribute_overrides: { 'pdf-themesdir' => relative_themesdir }
        (expect pdf.find_text font_name: 'Times-Roman').to have_size pdf.text.size
      end

      it 'should replace {docdir} token in value of pdf-themesdir' do
        input_file = Pathname.new fixture_file 'hello-with-custom-theme.adoc'
        pdf = to_pdf input_file, analyze: true, attribute_overrides: { 'pdf-themesdir' => '{docdir}' }
        (expect pdf.find_text font_name: 'Times-Roman').to have_size pdf.text.size
      end

      it 'should resolve theme at root of classloader when pdf-themesdir is uri:classloader:/', if: RUBY_ENGINE == 'jruby' do
        require fixture_file 'pdf-themes.jar'
        pdf = to_pdf <<~'END', attribute_overrides: { 'pdf-themesdir' => 'uri:classloader:/', 'pdf-theme' => 'custom' }, analyze: true
        hi there
        END

        text = pdf.find_unique_text 'hi there'
        (expect text[:font_color]).to eql '0000FF'
      end

      it 'should resolve theme from folder in classloader when pdf-themesdir starts with uri:classloader:', if: RUBY_ENGINE == 'jruby' do
        require fixture_file 'pdf-themes.jar'
        pdf = to_pdf <<~'END', attribute_overrides: { 'pdf-themesdir' => 'uri:classloader:/pdf-themes', 'pdf-theme' => 'another-custom' }, analyze: true
        hi there
        END

        text = pdf.find_unique_text 'hi there'
        (expect text[:font_color]).to eql 'FF0000'
      end

      it 'should set text color to black when default-for-print theme is specified' do
        pdf = to_pdf <<~END, analyze: true
        = Document Title
        :pdf-theme: default-for-print

        black `text`

        > loud quote
        END

        (expect pdf.find_text font_color: '000000').to have_size pdf.text.size
      end

      it 'should set font family to Noto Sans when default-sans themme is specified' do
        pdf = to_pdf <<~END, analyze: true
        = Document Title
        :pdf-theme: default-sans

        We don't like those _pesky_ serifs in these here parts.
        END

        text = pdf.text
        sans_text = text.select {|it| it[:font_name].start_with? 'NotoSans' }
        (expect sans_text).to have_size text.size
      end

      it 'should use theme passed in through :pdf_theme option' do
        theme = Asciidoctor::PDF::ThemeLoader.load_theme 'custom', fixtures_dir
        theme.base_font_size = 14
        theme.base_font_color = '1a1a1a'
        pdf = Asciidoctor.convert 'content', backend: 'pdf', pdf_theme: theme
        converter_theme = pdf.instance_variable_get :@theme
        (expect converter_theme.base_font_size).to eql theme.base_font_size
        (expect converter_theme.base_font_color).to eql theme.base_font_color
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
        end).to log_message severity: :ERROR, message: /could not locate or load the built-in pdf theme `foo' because of .*?; reverting to default theme/
      end

      it 'should log error if user theme cannot be found or loaded' do
        (expect do
          Asciidoctor.convert 'foo', backend: 'pdf', attributes: { 'pdf-theme' => 'foo', 'pdf-themesdir' => fixtures_dir }
        end).to log_message severity: :ERROR, message: /could not locate or load the pdf theme `foo' in #{Regexp.escape fixtures_dir} because of .*?; reverting to default theme/
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
        pdf = to_pdf <<~'END', attribute_overrides: { 'pdf-theme' => (fixture_file 'bare-theme.yml') }, analyze: true
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

        ----
        key=val <1>
        ----
        <1> A variable assignment

        NOTE: That's all, folks!
        END

        (expect pdf.pages).to have_size 3
        (expect pdf.find_text font_name: 'Helvetica', font_size: 12).not_to be_empty
        (expect (pdf.find_text 'Document Title')[0]).not_to be_nil
        (expect (pdf.find_text 'Chapter Title')[0]).not_to be_nil
        (expect (pdf.find_text 'Section Title')[0]).not_to be_nil
        (expect (pdf.find_text 'ulist')[0]).not_to be_nil
        (expect (pdf.find_text 'one')[0]).not_to be_nil
      end

      it 'should not crash if theme does not specify any keys when converting chronicles example' do
        input_path = Pathname.new example_file 'chronicles-example.adoc'
        pdf = to_pdf input_path, attribute_overrides: { 'imagesdir' => '@', 'pdf-theme' => (fixture_file 'bare-theme.yml'), 'source-highlighter' => nil }
        (expect pdf.pages).to have_size 14
        (expect (pdf.page 1).text).to include 'Documentation Chronicles'
      end

      it 'should not warn when using dark theme to convert chronicles example' do
        input_path = Pathname.new example_file 'chronicles-example.adoc'
        pdf = to_pdf input_path, attribute_overrides: { 'imagesdir' => '@', 'pdf-theme' => 'chronicles-dark', 'source-highlighter' => nil }, analyze: true
        (expect pdf.pages).to have_size 17
        gs_p1 = pdf.pages[0][:raw_content]
        (expect gs_p1).to start_with %(q\n/DeviceRGB cs\n0.0 0.0 0.0 scn\n0.0 0.0 595.28 841.89 re\n)
        doctitle = pdf.find_text page_number: 1, string: 'Documentation Chronicles'
        (expect doctitle).to have_size 1
        (expect doctitle[0][:font_color]).to eql '666666'
        p4_text = pdf.find_text page_number: 4
        heading_text = p4_text[0]
        paragraph_text = p4_text[1]
        link_text = p4_text[2]
        (expect heading_text[:font_color]).to eql 'CCCCCC'
        (expect paragraph_text[:font_color]).to eql 'CCCCCC'
        (expect link_text[:font_color]).to eql 'BD7435'
      end

      it 'should allow all border colors to be set using base-border-color when extending base theme' do
        [
          %(****\ncontent\n****),
          %(====\ncontent\n====),
          %([cols=2*]\n|===\n|a|b\n|c|d\n|===),
          %(____\ncontent\n____),
          %([verse]\n____\ncontent\n____),
          %(----\ncontent\n----),
          '---',
          'NOTE: content',
        ].each do |input|
          pdf = to_pdf input, pdf_theme: { extends: 'base', base_border_color: '0000EE' }, analyze: :line
          (expect pdf.lines.map {|it| it[:color] }.uniq).to eql %w(0000EE)
        end
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
          (expect converter.send :resolve_background_position, value, nil).to eql expected
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
      input = <<~'END'
      foo
      {undefined}
      bar
      END
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

    it 'should return previous integer as string when pred is invoked on integer string' do
      {
        '1' => '0',
        '10' => '9',
        '0' => '-1',
        '-9' => '-10',
      }.each do |curr, pred|
        (expect curr.pred).to eql pred
      end
    end

    it 'should not delegate to formatter when parse_text is called without options' do
      doc = Asciidoctor.load 'text', backend: :pdf
      converter = doc.converter
      converter.init_pdf doc
      result = converter.parse_text 'text'
      (expect result).to eql [text: 'text']
    end

    it 'should not delegate to formatter with default options when parse_text is called with inline_format: true' do
      doc = Asciidoctor.load 'text', backend: :pdf
      converter = doc.converter
      converter.init_pdf doc
      result = converter.parse_text %(foo\n<strong>bar</strong>), inline_format: true
      (expect result).to eql [{ text: %(foo\n) }, { text: 'bar', styles: [:bold].to_set }]
    end

    it 'should not delegate to formatter with specified options when parse_text is called with inline_format: Array' do
      doc = Asciidoctor.load 'text', backend: :pdf
      converter = doc.converter
      converter.init_pdf doc
      result = converter.parse_text %(foo\n<strong>bar</strong>), inline_format: [normalize: true]
      (expect result).to eql [{ text: 'foo ' }, { text: 'bar', styles: [:bold].to_set }]
    end

    it 'should restore current column after float yields to current block' do
      doc = Asciidoctor.load 'text', backend: :pdf
      converter = doc.converter
      actual_column = nil
      last_visited_column = nil
      converter.instance_exec do
        init_pdf doc
        start_new_page
        column_box [bounds.left, cursor], width: bounds.width, columns: 2 do
          float do
            ink_prose 'before'
            bounds.move_past_bottom
            ink_prose 'after'
            last_visited_column = bounds.instance_variable_get :@current_column
          end
          actual_column = bounds.instance_variable_get :@current_column
        end
      end
      (expect actual_column).to eql 0
      (expect last_visited_column).to eql 1
    end

    it 'should short-circuit formatted_text and log error if text cannot not fit on new page' do
      doc = Asciidoctor.load 'text', backend: :pdf
      last_page = last_page_number = nil
      (expect do
        doc.converter.instance_exec do
          init_pdf doc
          start_new_page
          ink_prose 'before'
          formatted_text [{ text: 'x', ascender: bounds.height, descender: font.descender }]
          last_page = page
          last_page_number = page_number
        end
      end).to log_message severity: :ERROR, message: 'cannot fit formatted text on page: x'
      (expect last_page).to be_empty
      (expect last_page_number).to eql 2
    end
  end

  describe '#next_enclosed_block' do
    let(:doc) { Asciidoctor.load input_source, backend: 'pdf' }
    let(:converter) { doc.converter }
    let(:result) { converter.next_enclosed_block start }

    context 'of document' do
      let(:input_source) { 'paragraph' }
      let(:start) { doc }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last block in document' do
      let(:input_source) { 'paragraph' }
      let(:start) { doc.blocks[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of block followed by block' do
      let :input_source do
        <<~'END'
        first paragraph

        second paragraph
        END
      end

      let(:start) { doc.blocks[0] }

      it('should be next block') { (expect result).to eql doc.blocks[1] }
    end

    context 'of last block in open block followed by block' do
      let :input_source do
        <<~'END'
        first paragraph

        --
        second paragraph
        --

        third paragraph
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[1] }

      it('should be next block adjacent to open block') { (expect result).to eql doc.blocks[2] }
    end

    context 'of last block before parent section' do
      let :input_source do
        <<~'END'
        == First Section

        paragraph

        == Second Section
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be next section') { (expect result).to eql doc.sections[1] }
    end

    context 'of last block before subsection' do
      let :input_source do
        <<~'END'
        == Section

        paragraph

        === Subsection
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be next section') { (expect result).to eql (doc.find_by context: :section)[-1] }
    end

    context 'of last block before grandparent section' do
      let :input_source do
        <<~'END'
        == First Section

        paragraph

        === Subsection

        paragraph

        == Last Section
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[-1] }

      it('should be next section') { (expect result).to eql (doc.find_by context: :section)[-1] }
    end

    context 'of preamble' do
      let :input_source do
        <<~'END'
        = Document Title

        preamble

        == First Section
        END
      end

      let(:start) { (doc.find_by context: :preamble)[0] }

      it('should be first section') { (expect result).to eql doc.sections[0] }
    end

    context 'of abstract' do
      let :input_source do
        <<~'END'
        = Document Title

        [abstract]
        --
        abstract
        --

        == First Section
        END
      end

      let(:start) { (doc.find_by context: :open, style: 'abstract')[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of abstract followed by more preamble' do
      let :input_source do
        <<~'END'
        = Document Title

        [abstract]
        --
        abstract
        --

        more preamble

        == First Section
        END
      end

      let(:start) { (doc.find_by context: :open, style: 'abstract')[0] }

      it('should be next block in preamble') { (expect result).to eql (doc.find_by context: :paragraph)[1] }
    end

    context 'of last block in abstract' do
      let :input_source do
        <<~'END'
        = Document Title

        [abstract]
        --
        abstract
        --

        == First Section
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last block inside abstract followed by more preamble' do
      let :input_source do
        <<~'END'
        = Document Title

        [abstract]
        --
        abstract
        --

        more preamble

        == First Section
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last block inside delimited block' do
      let :input_source do
        <<~'END'
        ****
        inside paragraph
        ****

        outside paragraph
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of list followed by block' do
      let :input_source do
        <<~'END'
        * list item

        paragraph
        END
      end

      let(:start) { doc.blocks[0] }

      it('should be next block adjacent to list') { (expect result).to eql doc.blocks[1] }
    end

    context 'of first list item in list' do
      let :input_source do
        <<~'END'
        * yin
        * yang
        END
      end

      let(:start) { doc.blocks[0].items[0] }

      it('should be next list item') { (expect result).to eql doc.blocks[0].items[1] }
    end

    context 'of last list item in list' do
      let :input_source do
        <<~'END'
        * yin
        * yang

        paragraph
        END
      end

      let(:start) { doc.blocks[0].items[-1] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last attached block in first item in list' do
      let :input_source do
        <<~'END'
        * moon
        +
        stars
        * sun
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be next list item') { (expect result).to eql doc.blocks[0].items[-1] }
    end

    context 'of last attached block in last item in list' do
      let :input_source do
        <<~'END'
        * sun
        * moon
        +
        stars

        paragraph
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last block in open block attached to first item in list' do
      let :input_source do
        <<~'END'
        * moon
        +
        --
        light side

        dark side
        --
        * sun
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[1] }

      it('should be next list item') { (expect result).to eql doc.blocks[0].items[-1] }
    end

    context 'of last item in nested list of first item in list' do
      let :input_source do
        <<~'END'
        * sun
         ** star
        * moon
        END
      end

      let(:start) { (doc.find_by context: :list_item)[1] }

      it('should be next top-level list item') { (expect result).to eql doc.blocks[0].items[-1] }
    end

    context 'of last item in nested list of last item in list' do
      let :input_source do
        <<~'END'
        * moon
        * sun
         ** star

        paragraph
        END
      end

      let(:start) { (doc.find_by context: :list_item)[2] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last item in deeply nested list of first item in list' do
      let :input_source do
        <<~'END'
        * foo
         ** bar
          *** baz
        * moon
        END
      end

      let(:start) { (doc.find_by context: :list_item)[2] }

      it('should be next top-level list item') { (expect result).to eql doc.blocks[0].items[-1] }
    end

    context 'of term of first item in dlist' do
      let :input_source do
        <<~'END'
        foo:: bar
        END
      end

      let(:start) { (doc.find_by context: :list_item)[0] }

      it('should be desc of current item') { (expect result).to eql (doc.find_by context: :list_item)[1] }
    end

    context 'of desc text of first item in dlist' do
      let :input_source do
        <<~'END'
        foo:: bar
        yin:: yang
        END
      end

      let(:start) { (doc.find_by context: :list_item)[1] }

      it('should be term of next item') { (expect result).to eql (doc.find_by context: :list_item)[2] }
    end

    context 'of desc text of last item in dlist' do
      let :input_source do
        <<~'END'
        foo:: bar
        yin:: yang

        paragraph
        END
      end

      let(:start) { (doc.find_by context: :list_item)[3] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of attached block in last item in dlist' do
      let :input_source do
        <<~'END'
        foo:: bar
        sun:: moon
        +
        stars

        paragraph
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of missing block' do
      let :input_source do
        <<~'END'
        foo:: bar
        yin:: yang
        END
      end

      let :start do
        list_items = (doc.find_by context: :list_item)
        list_items[0].parent.items[0].replace [[list_items[0].dup], list_items[1].dup]
        list_items[1]
      end

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of preamble followed by section' do
      let :input_source do
        <<~'END'
        = Document Title

        [abstract]
        --
        A glimpse at what is to come.
        --

        == Intro
        END
      end

      let(:start) { (doc.find_by context: :open)[0].parent }

      it('should be next section') { (expect result).to eql doc.sections[-1] }
    end

    context 'of paragraph in abstract followed by section' do
      let :input_source do
        <<~'END'
        = Document Title

        [abstract]
        --
        A glimpse at what is to come.
        --

        == Intro
        END
      end

      let(:start) { (doc.find_by context: :paragraph)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of quote block in abstract followed by section' do
      let :input_source do
        <<~'END'
        = Document Title

        [abstract]
        --
        ____
        A glimpse at what is to come.
        ____
        --

        == Intro
        END
      end

      let(:start) { (doc.find_by context: :quote)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last block in AsciiDoc table cell' do
      let :input_source do
        <<~'END'
        [cols=2*]
        |===
        a|
        foo

        bar

        ____
        quote
        ____

        | another cell
        |===

        after
        END
      end

      let(:start) { (doc.find_by context: :quote, traverse_documents: true)[0] }

      it('should be nil') { (expect result).to be_nil }
    end

    context 'of last block in description of first item in horizontal dlist' do
      example_group = self

      let :input_source do
        <<~'END'
        .Title
        [horizontal]
        term:: desc
        +
        [quote]
        capture:quote[]

        another term::
        END
      end

      let :doc do
        Asciidoctor.load input_source, backend: 'pdf', extensions: (proc do
          inline_macro :capture do
            process do |parent, target|
              example_group.let(:captured_block) { parent }
              create_inline parent, :quoted, target
            end
          end
        end)
      end

      let :start do
        doc.convert
        captured_block
      end

      it('should be next term') { (expect result).to eql (doc.find_by context: :list_item)[-1] }
    end

    context 'of last block in description of last item in horizontal dlist' do
      example_group = self

      let :input_source do
        <<~'END'
        .Title
        [horizontal]
        term:: desc
        +
        [quote]
        capture:quote[]

        after
        END
      end

      let :doc do
        Asciidoctor.load input_source, backend: 'pdf', extensions: (proc do
          inline_macro :capture do
            process do |parent, target|
              example_group.let(:captured_block) { parent }
              create_inline parent, :quoted, target
            end
          end
        end)
      end

      let :start do
        doc.convert
        captured_block
      end

      it('should be nil') { (expect result).to be_nil }
    end
  end

  describe 'Bounding Box' do
    it 'should use correct left value when creating bounding box', visual: true do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def traverse node
          return super unless node.context == :document
          column_box [0, cursor], columns: 2, width: bounds.width, reflow_margins: true, spacer: 12 do
            bounds.move_past_bottom
            super
          end
        end
      end

      pdf_theme = { caption_background_color: 'EEEEEE' }
      input = <<~'END'
      = Article Title

      * list item

      NOTE: admonition

      > quote

      .Block title
      ----
      code block <1>
      ----
      <1> Callout description
      END

      (expect to_pdf_file input, 'bounding-box-left.pdf', backend: backend, pdf_theme: pdf_theme).to visually_match 'bounding-box-left.pdf'
    end

    it 'should not reflow margins on column box if reflow_margins option is not set' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def traverse node
          return super unless node.context == :document
          column_box [0, cursor], columns: 2, width: bounds.width, spacer: 12 do
            super
          end
        end
      end

      input = <<~'END'
      = Article Title

      column 1, page 1

      [.column]
      <<<

      column 2, page 1

      [.column]
      <<<

      column 1, page 2
      END

      pdf = to_pdf input, backend: backend, analyze: true
      (expect (pdf.find_unique_text 'column 1, page 2')[:page_number]).to eql 2
      (expect (pdf.find_unique_text 'column 1, page 2')[:y]).to eql (pdf.find_unique_text 'column 1, page 1')[:y]
    end
  end

  describe 'extend' do
    it 'should use specified extended converter' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def convert_paragraph node
          layout_prose node.content, anchor: 'next-section'
        end
      end

      input = <<~'END'
      see next section

      [#next-section]
      == Next Section
      END

      pdf = to_pdf input, backend: backend, analyze: true
      para_text = pdf.find_unique_text 'see next section'
      (expect para_text[:font_color]).to eql '428BCA'

      pdf = to_pdf input, backend: backend
      (expect get_names pdf).to have_key 'next-section'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:Dest]).to eql 'next-section'
    end

    it 'should allow extended converter to invoke layout_heading without any opts' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def convert_paragraph node
          layout_heading %(#{node.role.capitalize} Heading) if node.role?
          super
        end
      end

      pdf = to_pdf <<~'END', backend: backend, pdf_theme: { heading_margin_bottom: 0, heading_margin_top: 100 }, analyze: true
      [.first]
      paragraph

      [.second]
      paragraph
      END

      first_heading_text = pdf.find_unique_text 'First Heading'
      (expect first_heading_text).not_to be_nil
      (expect first_heading_text[:font_size]).to eql 10.5
      (expect first_heading_text[:font_color]).to eql '333333'
      second_heading_text = pdf.find_unique_text 'Second Heading'
      (expect second_heading_text).not_to be_nil
      (expect second_heading_text[:font_size]).to eql 10.5
      (expect second_heading_text[:font_color]).to eql '333333'
      (expect second_heading_text[:y]).to be < 700
      text = pdf.text
      (expect text[0][:y] - text[1][:y]).to be < text[1][:y] - text[2][:y]
    end

    it 'should allow custom converter to invoke layout_heading with opts' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def convert_paragraph node
          if node.has_role? 'heading'
            layout_heading node.source, text_transform: 'uppercase', size: 100, color: 'AA0000', line_height: 1.2, margin: 20
          else
            super
          end
        end
      end

      pdf = to_pdf <<~'END', backend: backend, analyze: true
      before

      [.heading]
      heading

      paragraph
      END

      heading_text = pdf.find_unique_text 'HEADING'
      (expect heading_text).not_to be_nil
      (expect heading_text[:font_size]).to eql 100
      (expect heading_text[:font_color]).to eql 'AA0000'
      (expect heading_text[:y].floor).to eql 650
      (expect (pdf.find_unique_text 'paragraph')[:y].floor).to eql 588
    end

    it 'should allow custom converter to invoke layout_general_heading without any opts' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def convert_paragraph node
          layout_general_heading node, %(#{node.role.capitalize} Heading) if node.role?
          super
        end
      end

      pdf = to_pdf <<~'END', backend: backend, pdf_theme: { heading_margin_bottom: 0, heading_margin_top: 100 }, analyze: true
      [.first]
      paragraph

      [.second]
      paragraph
      END

      first_heading_text = pdf.find_unique_text 'First Heading'
      (expect first_heading_text).not_to be_nil
      (expect first_heading_text[:font_size]).to eql 10.5
      (expect first_heading_text[:font_color]).to eql '333333'
      second_heading_text = pdf.find_unique_text 'Second Heading'
      (expect second_heading_text).not_to be_nil
      (expect second_heading_text[:font_size]).to eql 10.5
      (expect second_heading_text[:font_color]).to eql '333333'
      (expect second_heading_text[:y]).to be < 700
      text = pdf.text
      (expect text[0][:y] - text[1][:y]).to be < text[1][:y] - text[2][:y]
    end

    it 'should allow custom converter to invoke layout_general_heading with opts' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def convert_paragraph node
          if node.has_role? 'heading'
            layout_general_heading node, node.source, text_transform: 'uppercase', size: 100, color: 'AA0000', line_height: 1.2, margin: 20
          else
            super
          end
        end
      end

      pdf = to_pdf <<~'END', backend: backend, analyze: true
      before

      [.heading]
      heading

      paragraph
      END

      heading_text = pdf.find_unique_text 'HEADING'
      (expect heading_text).not_to be_nil
      (expect heading_text[:font_size]).to eql 100
      (expect heading_text[:font_color]).to eql 'AA0000'
      (expect heading_text[:y].floor).to eql 650
      (expect (pdf.find_unique_text 'paragraph')[:y].floor).to eql 588
    end

    it 'should allow custom converter to override layout_general_heading for section title' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def layout_general_heading node, title, opts = {}
          layout_heading title, (opts.merge transform: (node.attr :transform).to_sym)
        end

        def layout_heading title, opts
          title = title.send opts.delete :transform
          super
        end
      end

      pdf = to_pdf <<~'END', backend: backend, analyze: true
      [transform=upcase]
      == Section Title
      END

      heading_text = pdf.find_unique_text 'SECTION TITLE'
      (expect heading_text).not_to be_nil
    end

    it 'should allow custom converter to override ink_general_heading for section title' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def ink_general_heading sect, title, opts = {}
          if (image_path = sect.attr 'image')
            image_attrs = { 'target' => image_path, 'pdfwidth' => '1in' }
            image_block = ::Asciidoctor::Block.new sect.document, :image, content_model: :empty, attributes: image_attrs
            convert_image image_block, relative_to_imagesdir: true, pinned: true
          end
          super
        end
      end

      pdf = to_pdf <<~'END', backend: backend, analyze: :image
      [image=tux.png]
      == Section Title
      END

      (expect pdf.images).to have_size 1
    end

    it 'should allow custom converter to override ink_general_heading for article doctitle' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
        def ink_general_heading _sect, title, opts = {}
          return super unless opts[:role] == :doctitle
          theme_font :heading_doctitle do
            ink_prose title, align: :center, margin: 0
          end
          theme_margin :heading_doctitle, :bottom
        end
      end

      pdf_theme = { heading_doctitle_font_color: '0000EE', heading_doctitle_margin_bottom: 24 }
      pdf = to_pdf <<~'END', backend: backend, pdf_theme: pdf_theme, analyze: true
      = Article Title

      First paragraph of body.
      First paragraph of body.
      First paragraph of body.
      First paragraph of body.
      END

      (expect pdf.pages).to have_size 1
      title_text = pdf.find_unique_text 'Article Title'
      (expect title_text[:font_color]).to eql '0000EE'
      para_text = pdf.text[1]
      (expect title_text[:y] - (para_text[:y] + para_text[:font_size])).to be > 24
    end

    it 'should remap layout_ methods added by prepended module' do
      backend = nil
      converter_class = create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)
      end
      converter_class.prepend (Module.new do
        def layout_prose string, opts = {}
          opts[:color] = 'FF0000'
          super
        end
      end)

      pdf = to_pdf 'color me red', backend: backend, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:font_color]).to eql 'FF0000'
    end

    it 'should allow extended converter to flag page as imported to suppress running content' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)

        def ink_part_title sect, title, opts
          super
          page.imported
        end
      end

      pdf = to_pdf <<~'END', backend: backend, enable_footer: true, analyze: true
      = Document Title
      :doctype: book

      = Part Title

      == Chapter
      END

      page_2_text = pdf.find_text page_number: 2
      (expect page_2_text).to have_size 1
      (expect page_2_text[0][:string]).to eql 'Part Title'
      (expect (pdf.find_text page_number: 3).last[:string]).to eql '2'
    end

    it 'should allow extended converter to override convert_listing_or_literal to handle calls to convert_listing and convert_literal' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)

        def convert_listing_or_literal node
          node.lines[0] = node.lines[0].sub 'Ruby', 'World'
          super
        end
      end

      pdf = to_pdf <<~'END', backend: backend, analyze: true
      [,ruby]
      ----
      puts "Hello, Ruby!"
      ----
      END

      (expect pdf.text[0][:string]).to eql 'puts "Hello, World!"'
    end

    it 'should allow extended converter to override convert_code to handle calls to convert_listing and convert_literal' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)

        def convert_code node
          node.lines[0] = node.lines[0].sub 'Ruby', 'World'
          super
        end
      end

      pdf = to_pdf <<~'END', backend: backend, analyze: true
      [,ruby]
      ----
      puts "Hello, Ruby!"
      ----
      END

      (expect pdf.text[0][:string]).to eql 'puts "Hello, World!"'
    end

    it 'should allow extended converter to temporarily override theme using save_theme' do
      backend = nil
      create_class (Asciidoctor::Converter.for 'pdf') do
        register_for (backend = %(pdf#{object_id}).to_sym)

        def convert_table node
          if node.role?
            save_theme do
              theme.table_border_color = theme.table_grid_color = '0000EE'
              super
            end
          else
            super
          end
        end
      end

      pdf = to_pdf <<~'END', backend: backend, analyze: :line
      [.custom,cols=2*]
      |===
      |a |b
      |c |d
      |===

      <<<

      [cols=2*]
      |===
      |a |b
      |c |d
      |===
      END

      lines = pdf.lines
      custom_lines = lines.select {|it| it[:color] == '0000EE' }
      default_lines = lines.reject {|it| it[:color] == '0000EE' }
      (expect custom_lines).to have_size 16
      (expect custom_lines[0][:page_number]).to eql 1
      (expect default_lines).to have_size 16
      (expect default_lines[0][:page_number]).to eql 2
    end
  end
end
