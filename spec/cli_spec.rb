require_relative 'spec_helper'

describe 'asciidoctor-pdf' do
  context 'Options' do
    it 'should print the version of Asciidoctor PDF to stdout when invoked with the -V flag' do
      out, _, res = run_command asciidoctor_pdf_bin, '-V'
      (expect res.exitstatus).to eql 0
      (expect out).to include %(Asciidoctor PDF #{Asciidoctor::PDF::VERSION} using Asciidoctor #{Asciidoctor::VERSION})
    end
  end

  context 'Examples' do
    it 'should convert the basic example', integration: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, (example_file 'basic-example.adoc')
      (expect res.exitstatus).to eql 0
      (expect out).to be_empty
      (expect err).to be_empty
      reference_file = File.absolute_path example_file 'basic-example.pdf'
      (expect output_file 'basic-example.pdf').to visually_match reference_file
    end

    it 'should convert the chronicles example', integration: true do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, (example_file 'chronicles-example.adoc')
      (expect res.exitstatus).to eql 0
      (expect out).to be_empty
      (expect err).to be_empty
      reference_file = File.absolute_path example_file 'chronicles-example.pdf'
      (expect output_file 'chronicles-example.pdf').to visually_match reference_file
    end unless ENV['ROUGE_VERSION'] && ENV['ROUGE_VERSION'].split[-1] < '2.1.0'
  end

  # NOTE cannot test pdfmark using API test since Object#to_pdf method conflicts with rspec helper of same name
  context 'pdfmark' do
    it 'should generate pdfmark file if pdfmark attribute is set' do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, '-a', 'pdfmark', (fixture_file 'book.adoc')
      (expect res.exitstatus).to eql 0
      (expect out).to be_empty
      (expect err).to be_empty
      pdfmark_file = Pathname.new output_file 'book.pdfmark'
      (expect pdfmark_file).to exist
      pdfmark_contents = pdfmark_file.read
      (expect pdfmark_contents).to include '/Title (Book Title)'
      (expect pdfmark_contents).to include '/Author (Author Name)'
      (expect pdfmark_contents).to include '/DOCINFO pdfmark'
    end

    it 'should hex encode title if contains non-ASCII character' do
      out, err, res = run_command asciidoctor_pdf_bin, '-D', output_dir, (fixture_file 'pdfmark-non-ascii-title.adoc')
      (expect res.exitstatus).to eql 0
      (expect out).to be_empty
      (expect err).to be_empty
      pdfmark_file = Pathname.new output_file 'pdfmark-non-ascii-title.pdfmark'
      (expect pdfmark_file).to exist
      pdfmark_contents = pdfmark_file.read
      (expect pdfmark_contents).to include '/Title <feff004c006500730020004d0069007300e9007200610062006c00650073>'
      (expect pdfmark_contents).to include '/Author (Victor Hugo)'
      (expect pdfmark_contents).to include '/Subject (June Rebellion)'
      (expect pdfmark_contents).to include '/Keywords (france, poor, rebellion)'
      (expect pdfmark_contents).to include '/DOCINFO pdfmark'
    end
  end
end
