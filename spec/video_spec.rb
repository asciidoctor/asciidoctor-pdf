# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Video' do
  context 'Local' do
    it 'should replace video with poster image if specified', visual: true do
      to_file = to_pdf_file <<~'END', 'video-local-file-poster.pdf'
      video::asciidoctor.mp4[logo.png,200,200]
      END

      (expect to_file).to visually_match 'video-local-file-poster.pdf'
    end

    it 'should replace video with video path and play icon if poster not specified' do
      pdf = to_pdf <<~'END', attributes: { 'imagesdir' => 'path/to/images' }, analyze: true
      :icons: font

      video::asciidoctor.mp4[]
      END

      (expect pdf.lines).to eql [%(\uf04b\u00a0path/to/images/asciidoctor.mp4 (video))]
    end

    it 'should wrap text for video if it exceeds width of content area' do
      pdf = to_pdf <<~'END', analyze: true, attribute_overrides: { 'imagesdir' => '' }
      video::a-video-with-an-excessively-long-and-descriptive-name-as-they-often-are-that-causes-the-text-to-wrap.mp4[]
      END

      (expect pdf.pages).to have_size 1
      lines = pdf.lines pdf.find_text page_number: 1
      (expect lines).to eql [%(\u25ba\u00a0a-video-with-an-excessively-long-and-descriptive-name-as-they-often-are-that-causes-the-text-to-), 'wrap.mp4 (video)']
    end

    it 'should show caption for video with no poster if title is specified' do
      pdf = to_pdf <<~'END', attributes: { 'imagesdir' => '' }, analyze: true
      :icons: font

      .Asciidoctor training
      video::asciidoctor.mp4[]
      END

      (expect pdf.lines).to eql [%(\uf04b\u00a0asciidoctor.mp4 (video)), 'Asciidoctor training']
    end
  end

  context 'YouTube' do
    it 'should replace video with poster image if allow-uri-read attribute is set', network: true, visual: true do
      video_id = 'EJ09pSuA9hw'
      to_file = to_pdf_file <<~END, 'video-youtube-poster.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      video::#{video_id}[youtube,pdfwidth=100%]
      END
      pdf = PDF::Reader.new to_file

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql %(https://www.youtube.com/watch?v=#{video_id})
      (expect to_file).to visually_match 'video-youtube-poster.pdf'
    end

    it 'should replace video with link if allow-uri-read attribute is not set' do
      video_id = 'EJ09pSuA9hw'
      input = %(video::#{video_id}[youtube])

      pdf = to_pdf input

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql %(https://www.youtube.com/watch?v=#{video_id})

      pdf = to_pdf input, analyze: true
      expected_strings = [%(\u25ba\u00a0), %(https://www.youtube.com/watch?v=#{video_id}), ' ', '(YouTube video)']
      (expect pdf.text.map {|it| it[:string] }).to eql expected_strings
    end
  end

  context 'Vimeo' do
    it 'should replace video with poster image if allow-uri-read attribute is set', network: true, visual: true do
      video_id = '300817511'
      to_file = to_pdf_file <<~END, 'video-vimeo-poster.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      video::#{video_id}[vimeo,pdfwidth=100%]
      END
      pdf = PDF::Reader.new to_file

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql %(https://vimeo.com/#{video_id})

      (expect to_file).to visually_match 'video-vimeo-poster.pdf'
    end

    it 'should replace video with link if allow-uri-read attribute is not set' do
      video_id = '77477140'
      input = %(video::#{video_id}[vimeo])

      pdf = to_pdf input

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql %(https://vimeo.com/#{video_id})

      pdf = to_pdf input, analyze: true
      expected_strings = [%(\u25ba\u00a0), %(https://vimeo.com/#{video_id}), ' ', '(Vimeo video)']
      (expect pdf.text.map {|it| it[:string] }).to eql expected_strings
    end

    it 'should replace video with link if allow-uri-read attribute is set and video is not found' do
      video_id = '0'
      input = %(video::#{video_id}[vimeo])

      pdf = to_pdf input, attribute_overrides: { 'allow-uri-read' => '' }

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql %(https://vimeo.com/#{video_id})

      pdf = to_pdf input, attribute_overrides: { 'allow-uri-read' => '' }, analyze: true
      expected_strings = [%(\u25ba\u00a0), %(https://vimeo.com/#{video_id}), ' ', '(Vimeo video)']
      (expect pdf.text.map {|it| it[:string] }).to eql expected_strings
    end
  end
end
