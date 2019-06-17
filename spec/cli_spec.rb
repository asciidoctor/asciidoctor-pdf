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
end
