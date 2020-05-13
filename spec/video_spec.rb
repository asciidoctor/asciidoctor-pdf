# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Video' do
  context 'Local' do
    it 'should replace video with poster image if specified', visual: true do
      to_file = to_pdf_file <<~'EOS', 'video-local-file-poster.pdf'
      video::asciidoctor.mp4[logo.png,200,200]
      EOS

      (expect to_file).to visually_match 'video-local-file-poster.pdf'
    end

    it 'should replace video with video path and play icon if poster not specified' do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      video::asciidoctor.mp4[]
      EOS

      (expect pdf.lines).to eql [%(\uf04b\u00a0#{fixture_file 'asciidoctor.mp4'} (video))]
    end

    it 'should show caption for video with no poster if title is specified' do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      .Asciidoctor training
      video::asciidoctor.mp4[]
      EOS

      (expect pdf.lines).to eql [%(\uf04b\u00a0#{fixture_file 'asciidoctor.mp4'} (video)), 'Asciidoctor training']
    end
  end

  context 'YouTube' do
    it 'should replace video with poster image if allow-uri-read attribute is set', visual: true, network: true do
      video_id = 'EJ09pSuA9hw'
      to_file = to_pdf_file <<~EOS, 'video-youtube-poster.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      video::#{video_id}[youtube,pdfwidth=100%]
      EOS
      pdf = PDF::Reader.new to_file

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql %(https://www.youtube.com/watch?v=#{video_id})
      (expect to_file).to visually_match 'video-youtube-poster.pdf'
    end
  end

  context 'Vimeo' do
    it 'should replace video with poster image if allow-uri-read attribute is set', visual: true, network: true do
      video_id = '77477140'
      to_file = to_pdf_file <<~EOS, 'video-vimeo-poster.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      video::#{video_id}[vimeo,pdfwidth=100%]
      EOS
      pdf = PDF::Reader.new to_file

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql %(https://vimeo.com/#{video_id})
      (expect to_file).to visually_match 'video-vimeo-poster.pdf'
    end
  end
end
