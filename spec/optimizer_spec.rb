# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Optimizer', if: (RSpec::ExampleGroupHelpers.gem_available? 'rghost'), &(proc do
  it 'should optimize output file if optimize attribute is set' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer-not-optimized.pdf'
    to_optimized_file = to_pdf_file input_file, 'optimizer-default.pdf', attribute_overrides: { 'title-page' => '', 'optimize' => '', 'subject' => 'Example' }
    to_file_size = (File.stat to_file).size
    to_optimized_file_size = (File.stat to_optimized_file).size
    (expect to_optimized_file_size).to be < to_file_size
    pdf = PDF::Reader.new to_optimized_file
    (expect pdf.pdf_version).to eql 1.4
    (expect pdf.pages).to have_size 3
    pdf_info = pdf.info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
    (expect pdf_info[:Title]).to eql 'Document Title'
    (expect pdf_info[:Author]).to eql 'Doc Writer'
    (expect pdf_info[:Subject]).to eql 'Example'
    (expect defined? Asciidoctor::PDF::Optimizer).to be_truthy
    # NOTE: assert constructor behavior once we know the class has been loaded
    optimizer = Asciidoctor::PDF::Optimizer.new
    (expect optimizer.quality).to eql :default
    (expect optimizer.compatibility_level).to eql '1.4'
    (expect optimizer.compliance).to eql 'PDF'
  end

  it 'should generate optimized PDF when filename contains spaces' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer filename with spaces.pdf', attribute_overrides: { 'optimize' => '' }
    pdf = PDF::Reader.new to_file
    pdf_info = pdf.info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
  end

  it 'should generate optimized PDF using PDF version specified by pdf-version attribute' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer-pdf-version.pdf', attribute_overrides: { 'optimize' => '', 'pdf-version' => '1.3' }
    pdf = PDF::Reader.new to_file
    (expect pdf.pdf_version).to eql 1.3
    (expect pdf.catalog).not_to have_key :Metadata
  end

  it 'should use existing pdfmark file if present when optimizing' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    pdfmark_file = Pathname.new output_file 'optimizer-pdfmark.pdfmark'
    pdfmark_file.write <<~'EOS'
    [ /Title (All Your PDF Are Belong To Us)
      /Author (CATS)
      /Subject (Zero Wing)
      /ModDate (D:19920101000000-00'00')
      /CreationDate (D:19920101000000-00'00')
      /Creator (Genesis)
      /DOCINFO pdfmark
    EOS
    to_file = to_pdf_file input_file, 'optimizer-pdfmark.pdf', attribute_overrides: { 'optimize' => '' }
    pdf = PDF::Reader.new to_file
    pdf_info = pdf.info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
    (expect pdf_info[:Title]).to eql 'All Your PDF Are Belong To Us'
    (expect pdf_info[:Subject]).to eql 'Zero Wing'
    (expect pdf_info[:Creator]).to eql 'Genesis'
    pdfmark_file.unlink
  end

  it 'should optimize output file using quality specified by value of optimize attribute' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_screen_file = to_pdf_file input_file, 'optimizer-screen.pdf', attribute_overrides: { 'title-page' => '', 'optimize' => 'screen' }
    to_prepress_file = to_pdf_file input_file, 'optimizer-prepress.pdf', attribute_overrides: { 'title-page' => '', 'optimize' => 'prepress' }
    to_screen_file_size = (File.stat to_screen_file).size
    to_prepress_file_size = (File.stat to_prepress_file).size
    (expect to_prepress_file_size).to be < to_screen_file_size
    pdf = PDF::Reader.new to_prepress_file
    (expect pdf.pdf_version).to eql 1.4
    (expect pdf.pages).to have_size 3
    pdf_info = pdf.info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
    (expect pdf_info[:Title]).to eql 'Document Title'
    (expect pdf_info[:Author]).to eql 'Doc Writer'
  end

  it 'should use default quality if specified quality is not recognized' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    (expect do
      to_pdf_file input_file, 'optimizer-fallback-quality.pdf', attribute_overrides: { 'optimize' => 'foobar' }
    end).to not_raise_exception
  end

  it 'should generate PDF that conforms to specified compliance' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer-screen-pdf-a.pdf', attribute_overrides: { 'optimize' => 'PDF/A' }
    pdf = PDF::Reader.new to_file
    (expect pdf.pdf_version).to eql 1.4
    (expect pdf.pages).to have_size 1
    # Non-printing annotations (i.e., hyperlinks) are not permitted in PDF/A
    (expect get_annotations pdf, 1).to be_empty
  end

  # NOTE: I can't figure out a way to capture the stderr in this case without using the CLI
  it 'should not fail to produce PDF/X compliant document if specified', cli: true do
    out, err, res = run_command asciidoctor_pdf_bin, '-a', 'optimize=PDF/X', '-o', (to_file = output_file 'optimizer-screen-pdf-x.pdf'), (example_file 'basic-example.adoc')
    (expect res.exitstatus).to be 0
    (expect out).to be_empty
    (expect err).not_to include 'TrimBox does not fit inside BleedBox'
    (expect err).to be_empty
    pdf = PDF::Reader.new to_file
    (expect pdf.pdf_version).to eql 1.3
    (expect pdf.pages).to have_size 1
    # Non-printing annotations (i.e., hyperlinks) are not permitted in PDF/X
    (expect get_annotations pdf, 1).to be_empty
  end

  it 'should generate PDF that conforms to specified PDF/A compliance when quality is specified' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer-print-pdf-a.pdf', attribute_overrides: { 'optimize' => 'print,PDF/A' }
    pdf = PDF::Reader.new to_file
    (expect pdf.pdf_version).to eql 1.4
    (expect pdf.pages).to have_size 1
    # Non-printing annotations (i.e., hyperlinks) are not permitted in PDF/A
    (expect get_annotations pdf, 1).to be_empty
  end

  it 'should install bin script named asciidoctor-pdf-optimize' do
    bin_script = (Pathname.new Gem.bindir) / 'asciidoctor-pdf-optimize'
    bin_script = Pathname.new Gem.bin_path 'asciidoctor-pdf', 'asciidoctor-pdf-optimize' unless bin_script.exist?
    (expect bin_script).to exist
  end

  it 'should optimize PDF passed to asciidoctor-pdf-optimize CLI', cli: true do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer-cli.pdf'
    out, err, res = run_command asciidoctor_pdf_optimize_bin, '--quality', 'prepress', to_file
    (expect res.exitstatus).to be 0
    (expect out).to be_empty
    (expect err).to be_empty
    pdf_info = (PDF::Reader.new to_file).info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
  end

  it 'should use ghostscript command specified by GS environment variable', cli: true do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer-cli-with-custom-gs.pdf'
    env = windows? ? {} : { 'GS' => '/usr/bin/gs' }
    out, err, res = run_command asciidoctor_pdf_optimize_bin, '--quality', 'prepress', to_file, env: env
    (expect res.exitstatus).to be 0
    (expect out).to be_empty
    (expect err).to be_empty
    pdf_info = (PDF::Reader.new to_file).info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
  end

  it 'should not crash if quality passed to asciidoctor-pdf-optimize CLI is not recognized', cli: true do
    input_file = Pathname.new example_file 'basic-example.adoc'
    to_file = to_pdf_file input_file, 'optimizer-cli-fallback-quality.pdf'
    out, err, res = run_command asciidoctor_pdf_optimize_bin, '--quality', 'foobar', to_file
    (expect res.exitstatus).to be 0
    (expect out).to be_empty
    (expect err).to be_empty
    pdf_info = (PDF::Reader.new to_file).info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
  end
end)
