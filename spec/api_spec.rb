# frozen_string_literal: true

require_relative 'spec_helper'

describe 'API' do
  context 'Asciidoctor.convert' do
    it 'should return an instance of Prawn::Document' do
      output = to_pdf 'hello', analyze: :document
      (expect output).to be_a Asciidoctor::PDF::Converter
      (expect output).to be_a Prawn::Document
      (expect output.render).to start_with '%PDF'
    end
  end

  context 'Asciidoctor.convert_file' do
    it 'should return a doc whose converter is a Prawn::Document' do
      input_file = Pathname.new fixture_file 'hello.adoc'
      output = to_pdf input_file, to_dir: output_dir, analyze: :document
      (expect output).to be_a Asciidoctor::PDF::Converter
      (expect output).to be_a Prawn::Document
      (expect output.render).to start_with '%PDF'
    end
  end
end
