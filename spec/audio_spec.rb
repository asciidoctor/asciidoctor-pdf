# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Audio' do
  it 'should replace audio block with right pointer, absolute path to audio file, and audio label' do
    expected_lines = [
      'before',
      %(\u25ba\u00a0#{fixture_file 'podcast.mp3'} (audio)),
      'after',
    ]

    pdf = to_pdf <<~'EOS', analyze: true
    before

    audio::podcast.mp3[]

    after
    EOS

    (expect pdf.lines).to eql expected_lines
    before_text = (pdf.find_text 'before')[0]
    audio_text = (pdf.find_text %r/\(audio\)/)[0]
    after_text = (pdf.find_text 'after')[0]
    (expect ((before_text[:y] - audio_text[:y]).round 2)).to eql ((audio_text[:y] - after_text[:y]).round 2)
  end

  it 'should use font-based icon for play symbol if font icons are enabled' do
    pdf = to_pdf <<~'EOS', attribute_overrides: { 'icons' => 'font' }, analyze: true
    audio::podcast.mp3[]
    EOS

    icon_text = (pdf.find_text %(\uf04b))[0]
    (expect icon_text).not_to be_nil
    (expect icon_text[:font_name]).to eql 'FontAwesome5Free-Solid'
  end
end
