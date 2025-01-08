# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor Diagram Integration', if: (RSpec::ExampleGroupHelpers.gem_available? 'asciidoctor-diagram'), &(proc do
  it 'should locate generated diagram when :to_dir is set and imagesdir is not set' do
    require 'asciidoctor-diagram'
    input_file = Pathname.new fixture_file 'diagrams.adoc'
    pdf = to_pdf input_file, safe: :unsafe, attributes: { 'sequence-diagram-name' => 'sequence-diagram-a' }, analyze: :image
    (expect pdf.images).to have_size 1
    (expect Pathname.new output_file 'sequence-diagram-a.png').to exist
    (expect Pathname.new output_file '.asciidoctor/diagram/sequence-diagram-a.png.cache').to exist
    (expect Pathname.new fixture_file 'sequence-diagram-a.png').not_to exist
    (expect Pathname.new fixture_file 'sequence-diagram-a.png.cache').not_to exist
  end

  it 'should generate diagram into imagesdir relative to output dir' do
    require 'asciidoctor-diagram'
    input_file = Pathname.new fixture_file 'diagrams.adoc'
    pdf = to_pdf input_file, safe: :unsafe, attributes: { 'imagesdir' => 'images', 'sequence-diagram-name' => 'sequence-diagram-b' }, analyze: :image
    (expect pdf.images).to have_size 1
    (expect Pathname.new output_file 'images/sequence-diagram-b.png').to exist
    (expect Pathname.new output_file '.asciidoctor/diagram/sequence-diagram-b.png.cache').to exist
    (expect Pathname.new fixture_file 'images/sequence-diagram-b.png').not_to exist
    (expect Pathname.new fixture_file 'images/sequence-diagram-b.png.cache').not_to exist
  end

  it 'should be able to control display size of image using pdfwidth attribute on diagram block' do
    require 'asciidoctor-diagram'
    pdf = to_pdf <<~END, safe: :unsafe, attributes: { 'docdir' => fixtures_dir, 'outdir' => output_dir, 'imagesdir' => 'images' }, analyze: :image

    [plantuml,pdfwidth-test,png,pdfwidth=1in]
    ....
    scale 4
    start
    :Work;
    end
    ....
    END

    (expect Pathname.new output_file 'images/pdfwidth-test.png').to exist
    images = pdf.images
    (expect images).to have_size 1
    image_data = JSON.load (Pathname.new output_file '.asciidoctor/diagram/pdfwidth-test.png.cache').read
    (expect images[0][:intrinsic_width].to_f).to eql image_data['width'].to_f
    (expect images[0][:width].to_f).to eql 72.0
  end

  it 'should allow font family used for diagram to be remapped' do
    require 'asciidoctor-diagram'
    with_tmp_file '.cfg', contents: %(skinparam defaultFontName M+ 1p Fallback\n) do |tmp_file|
      Dir.chdir File.dirname tmp_file do
        pdf = to_pdf <<~END, attributes: { 'imagesdir' => '' }, analyze: true
        :pdf-theme: default-with-font-fallbacks
        :plantumlconfig: #{File.basename tmp_file}

        [plantuml,font-test,svg]
        ....
        card カード
        ....
        END

        text = pdf.text[0]
        (expect text[:string]).to eql 'カード'
        (expect text[:font_name]).to eql 'mplus-1p-regular'
        (expect (File.file? 'font-test.svg')).to be true
        (expect (File.directory? '.asciidoctor')).to be true
      end
    end
  end

  it 'should not crash when both Asciidoctor Diagram and pdfmark are active' do
    require 'asciidoctor-diagram'
    input_file = Pathname.new fixture_file 'diagrams.adoc'
    pdfmark_file = Pathname.new output_file 'diagrams.pdfmark'
    pdf = to_pdf input_file, safe: :unsafe, attributes: { 'pdfmark' => '', 'sequence-diagram-name' => 'sequence-diagram-c' }, analyze: :image
    (expect pdf.images).to have_size 1
    (expect pdfmark_file).to exist
  end
end)

describe 'Asciidoctor Kroki Integration', if: (RSpec::ExampleGroupHelpers.gem_available? 'asciidoctor-kroki'), &(proc do
  # NOTE: asciidoctor-kroki not honoring :to_dir option; see https://github.com/Mogztter/asciidoctor-kroki/issues/371
  it 'should locate generated diagram in output directory' do
    require 'asciidoctor-kroki'
    input_file = Pathname.new fixture_file 'diagrams.adoc'
    attributes = {
      'sequence-diagram-name' => 'sequence-diagram-d',
      'kroki-fetch-diagram' => '',
      # imagesdir and imagesoutdir required until fixes are applied to Asciidoctor Kroki
      'imagesdir' => output_dir,
      'imagesoutdir' => output_dir,
    }
    pdf = to_pdf input_file, safe: :unsafe, attributes: attributes, analyze: :image
    (expect pdf.images).to have_size 1
    (expect pdf.images[0][:data].length).to be > 5000
    diagram_file = Dir[File.join output_dir, '*.png'][0]
    (expect diagram_file).not_to be_nil
  end

  # NOTE: asciidoctor-kroki not honoring :to_dir option; see https://github.com/Mogztter/asciidoctor-kroki/issues/371
  it 'should overwrite generated diagram file on subsequent invocations' do
    require 'asciidoctor-kroki'
    input_file = Pathname.new fixture_file 'diagrams.adoc'
    attributes = {
      'sequence-diagram-name' => 'sequence-diagram-e',
      'kroki-fetch-diagram' => '',
      # imagesdir and imagesoutdir required until fixes are applied to Asciidoctor Kroki
      'imagesdir' => output_dir,
      'imagesoutdir' => output_dir,
    }
    2.times do
      pdf = to_pdf input_file, safe: :unsafe, attributes: attributes, analyze: :image
      (expect pdf.images).to have_size 1
      (expect pdf.images[0][:data].length).to be > 5000
      diagram_file = Dir[File.join output_dir, '*.png'][0]
      (expect diagram_file).not_to be_nil
    end
  end
end)
