# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Audio' do
  it 'should replace audio block with right pointer, path to audio file, and audio label' do
    expected_lines = [
      'before',
      %(\u25ba\u00a0#{fixture_file 'podcast.mp3'} (audio)),
      'after',
    ]

    pdf = to_pdf <<~'END', analyze: true
    before

    audio::podcast.mp3[]

    after
    END

    (expect pdf.lines).to eql expected_lines
    before_text = (pdf.find_text 'before')[0]
    audio_text = (pdf.find_text %r/\(audio\)/)[0]
    after_text = (pdf.find_text 'after')[0]
    (expect ((before_text[:y] - audio_text[:y]).round 2)).to eql ((audio_text[:y] - after_text[:y]).round 2)
  end

  it 'should wrap text for audio if it exceeds width of content area' do
    pdf = to_pdf <<~'END', analyze: true, attribute_overrides: { 'imagesdir' => '' }
    audio::a-podcast-with-an-excessively-long-and-descriptive-name-as-they-sometimes-are-that-causes-the-text-to-wrap.mp3[]
    END

    (expect pdf.pages).to have_size 1
    lines = pdf.lines pdf.find_text page_number: 1
    (expect lines).to eql [%(\u25ba\u00a0a-podcast-with-an-excessively-long-and-descriptive-name-as-they-sometimes-are-that-causes-the-), 'text-to-wrap.mp3 (audio)']
  end

  it 'should use font-based icon for play symbol if font icons are enabled' do
    pdf = to_pdf <<~'END', attribute_overrides: { 'icons' => 'font' }, analyze: true
    audio::podcast.mp3[]
    END

    icon_text = (pdf.find_text ?\uf04b)[0]
    (expect icon_text).not_to be_nil
    (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
  end

  it 'should show caption for audio if title is specified' do
    pdf = to_pdf <<~'END', analyze: true
    :icons: font

    .Episode 1 of my podcast
    audio::podcast-e1.mp3[]
    END

    (expect pdf.lines).to eql [%(\uf04b\u00a0#{fixture_file 'podcast-e1.mp3'} (audio)), 'Episode 1 of my podcast']
  end
end
