require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Optimizer' do
  it 'should optimize output file if optimize attribute is set' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    reference_file = example_file 'basic-example.pdf'
    to_file = to_pdf_file input_file, 'optimizer-not-optimized.pdf'
    to_optimized_file = to_pdf_file input_file, 'optimizer-default.pdf', attribute_overrides: { 'optimize' => '', 'subject' => 'Example' }
    to_file_size = (File.stat to_file).size
    to_optimized_file_size = (File.stat to_optimized_file).size
    (expect to_optimized_file_size).to be < to_file_size
    pdf = PDF::Reader.new to_optimized_file
    (expect pdf.pages).to have_size 4
    pdf_info = pdf.info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
    (expect pdf_info[:Title]).to eql 'Document Title'
    (expect pdf_info[:Author]).to eql 'Doc Writer'
    (expect pdf_info[:Subject]).to eql 'Example'
  end

  it 'should optimize output file using quality specified by value of optimize attribute' do
    input_file = Pathname.new example_file 'basic-example.adoc'
    reference_file = example_file 'basic-example.pdf'
    to_screen_file = to_pdf_file input_file, 'optimizer-screen.pdf', attribute_overrides: { 'optimize' => 'screen' }
    to_prepress_file = to_pdf_file input_file, 'optimizer-prepress.pdf', attribute_overrides: { 'optimize' => 'prepress' }
    to_screen_file_size = (File.stat to_screen_file).size
    to_prepress_file_size = (File.stat to_prepress_file).size
    (expect to_prepress_file_size).to be < to_screen_file_size
    pdf = PDF::Reader.new to_prepress_file
    (expect pdf.pages).to have_size 4
    pdf_info = pdf.info
    (expect pdf_info[:Producer]).to include 'Ghostscript'
    (expect pdf_info[:Title]).to eql 'Document Title'
    (expect pdf_info[:Author]).to eql 'Doc Writer'
  end
end if ENV['RGHOST_VERSION']
