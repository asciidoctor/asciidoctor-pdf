# frozen_string_literal: true

require_relative 'spec_helper'

describe 'asciidoctor-pdf' do
  context 'Packaging' do
    it 'should install bin script named asciidoctor-pdf' do
      bin_script = (Pathname.new Gem.bindir) / 'asciidoctor-pdf'
      bin_script = Pathname.new Gem.bin_path 'asciidoctor-pdf', 'asciidoctor-pdf' unless bin_script.exist?
      (expect bin_script).to exist
    end
  end

  context 'Options' do
    it 'should print the version of Asciidoctor PDF to stdout when invoked with the -V flag', cli: true do
      out, _, res = run_command asciidoctor_pdf_bin, '-V'
      (expect res.exitstatus).to be 0
      (expect out).to include %(Asciidoctor PDF #{Asciidoctor::PDF::VERSION} using Asciidoctor #{Asciidoctor::VERSION})
    end

    it 'should enable sourcemap if --sourcemap option is specified', cli: true do
      with_tmp_file '.adoc', tmpdir: output_dir do |tmp_file|
        tmp_file.write <<~'EOS'
        before

        ****
        content
        EOS
        tmp_file.close
        out, err, res = run_command asciidoctor_pdf_bin, '--sourcemap', tmp_file.path
        (expect res.exitstatus).to be 0
        (expect out).to be_empty
        (expect err.chomp).to eql %(asciidoctor: WARNING: #{File.basename tmp_file.path}: line 3: unterminated sidebar block)
      end
    end
  end

  context 'Require', if: (defined? Bundler) do
    it 'should load converter if backend is pdf and require is asciidoctor-pdf', cli: true do
      out, err, res = run_command asciidoctor_bin, '-r', 'asciidoctor-pdf', '-b', 'pdf', '-D', output_dir, (fixture_file 'hello.adoc'), use_bundler: true
      (expect res.exitstatus).to be 0
      (expect out).to be_empty
      (expect err).to be_empty
      (expect Pathname.new output_file 'hello.pdf').to exist
    end

    it 'should load converter if backend is pdf and require is asciidoctor/pdf', cli: true do
      out, err, res = run_command asciidoctor_bin, '-r', 'asciidoctor/pdf', '-b', 'pdf', '-D', output_dir, (fixture_file 'hello.adoc'), use_bundler: true
      (expect res.exitstatus).to be 0
      (expect out).to be_empty
      (expect err).to be_empty
      (expect Pathname.new output_file 'hello.pdf').to exist
    end
  end

  context 'Theme' do
    it 'should use theme specified by pdf-theme attribute', cli: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, '-a', %(pdf-theme=#{fixture_file 'custom-theme.yml'}), (fixture_file 'hello.adoc')
      (expect res.exitstatus).to be 0
      (expect out).to be_empty
      (expect err).to be_empty
      to_file = Pathname.new output_file 'hello.pdf'
      (expect to_file).to exist
      pdf = TextInspector.analyze to_file
      hello_text = pdf.find_unique_text 'hello'
      (expect hello_text[:font_name]).to eql 'Times-Roman'
    end

    it 'should use theme specified by --theme option', cli: true do
      [true, false].each do |adjoin_value|
        args = ['-D', output_dir]
        if adjoin_value
          args << %(--theme=#{fixture_file 'custom-theme.yml'})
        else
          args << '--theme'
          args << (fixture_file 'custom-theme.yml')
        end
        args << (fixture_file 'hello.adoc')
        out, err, res = run_command asciidoctor_pdf_bin, *args
        (expect res.exitstatus).to be 0
        (expect out).to be_empty
        (expect err).to be_empty
        to_file = Pathname.new output_file 'hello.pdf'
        (expect to_file).to exist
        pdf = TextInspector.analyze to_file
        hello_text = pdf.find_unique_text 'hello'
        (expect hello_text[:font_name]).to eql 'Times-Roman'
      end
    end
  end

  context 'Examples' do
    it 'should convert the basic example', cli: true, visual: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, (example_file 'basic-example.adoc')
      (expect res.exitstatus).to be 0
      (expect out).to be_empty
      (expect err).to be_empty
      reference_file = File.absolute_path example_file 'basic-example.pdf'
      (expect output_file 'basic-example.pdf').to visually_match reference_file
    end

    it 'should convert the chronicles example', cli: true, visual: true, unless: Gem.loaded_specs['rouge'].version < (Gem::Version.new '2.1.0'), &(proc do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, (example_file 'chronicles-example.adoc')
      (expect res.exitstatus).to be 0
      (expect out).to be_empty
      (expect err).to be_empty
      reference_file = File.absolute_path example_file 'chronicles-example.pdf'
      (expect output_file 'chronicles-example.pdf').to visually_match reference_file
    end)
  end

  context 'redirection', unless: windows? && jruby? do
    it 'should be able to write output to file via stdout', cli: true do
      run_command asciidoctor_pdf_bin, '-o', '-', (fixture_file 'book.adoc'), out: (to_file = output_file 'book.pdf')
      (expect Pathname.new to_file).to exist
      (expect { PDF::Reader.new to_file }).not_to raise_exception
    end
  end

  context 'nogmagick' do
    it 'should unregister Gmagick handler if asciidoctor/pdf/nogmagick is required', cli: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, '-r', 'asciidoctor/pdf/nogmagick', (fixture_file 'interlaced-png.adoc'), use_bundler: true
      (expect out).to be_empty
      (expect err).not_to be_empty
      (expect err).to include 'PNG uses unsupported interlace method'
      (expect res.exitstatus).to be 0
    end

    it 'should unregister Gmagick handler for PNG images if asciidoctor/pdf/nopngmagick is required', cli: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, '-r', 'asciidoctor/pdf/nopngmagick', (fixture_file 'interlaced-png.adoc'), use_bundler: true
      (expect out).to be_empty
      (expect err).not_to be_empty
      (expect err).to include 'PNG uses unsupported interlace method'
      (expect res.exitstatus).to be 0
    end

    it 'should unregister Gmagick handler only for PNG images if asciidoctor/pdf/nopngmagick is required', cli: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, '-r', 'asciidoctor/pdf/nopngmagick', (fixture_file 'bmp.adoc'), use_bundler: true
      (expect out).to be_empty
      (expect err).to be_empty
      (expect res.exitstatus).to be 0
    end
  end if defined? GMagick::Image

  context 'pdfmark' do
    it 'should generate pdfmark file if pdfmark attribute is set', cli: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, '-a', 'pdfmark', (fixture_file 'book.adoc')
      (expect res.exitstatus).to be 0
      (expect out).to be_empty
      (expect err).to be_empty
      pdfmark_file = Pathname.new output_file 'book.pdfmark'
      (expect pdfmark_file).to exist
      pdfmark_contents = pdfmark_file.read
      (expect pdfmark_contents).to include '/Title (Book Title)'
      (expect pdfmark_contents).to include '/Author (Author Name)'
      (expect pdfmark_contents).to include '/DOCINFO pdfmark'
    end
  end

  context 'keep artifacts' do
    it 'should generate scratch file if KEEP_ARTIFACTS environment variable is set', cli: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, (fixture_file 'dry-run-block.adoc'), env: { 'KEEP_ARTIFACTS' => 'true' }
      (expect res.exitstatus).to be 0
      (expect out).to be_empty
      (expect err).to be_empty
      scratch_file = Pathname.new output_file 'dry-run-block-scratch.pdf'
      (expect scratch_file).to exist
      (expect { PDF::Reader.new scratch_file }).not_to raise_exception
    end
  end
end
