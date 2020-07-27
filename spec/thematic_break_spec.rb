# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Thematic Break' do
  it 'should draw a horizonal rule at the location of a thematic break' do
    pdf = to_pdf <<~'EOS', analyze: :line
    before

    ---

    after
    EOS

    lines = pdf.lines
    (expect lines).to have_size 1
    horizontal_rule = lines[0]
    (expect horizontal_rule[:from][:y]).to eql horizontal_rule[:to][:y]
    (expect horizontal_rule[:to][:x]).to be > horizontal_rule[:from][:x]
  end

  it 'should draw dashed line if the border style is dashed', visual: true do
    pdf_theme = {
      thematic_break_border_width: 0.5,
      thematic_break_border_style: 'dashed',
      thematic_break_border_color: 'a0a0a0',
    }
    to_file = to_pdf_file <<~'EOS', 'thematic-break-line-style-dashed.pdf', pdf_theme: pdf_theme
    before

    ---

    after
    EOS

    (expect to_file).to visually_match 'thematic-break-line-style-dashed.pdf'
  end

  it 'should draw dotted line if the border style is dotted', visual: true do
    pdf_theme = {
      thematic_break_border_width: 0.5,
      thematic_break_border_style: 'dotted',
      thematic_break_border_color: 'aa0000',
    }
    to_file = to_pdf_file <<~'EOS', 'thematic-break-line-style-dotted.pdf', pdf_theme: pdf_theme
    before

    ---

    after
    EOS

    (expect to_file).to visually_match 'thematic-break-line-style-dotted.pdf'
  end

  it 'should draw two parallel lines that span the border width if the border style is double', visual: true do
    pdf_theme = {
      thematic_break_border_width: 3,
      thematic_break_border_style: 'double',
      thematic_break_border_color: 'a0a0a0',
    }
    to_file = to_pdf_file <<~'EOS', 'thematic-break-line-style-double.pdf', pdf_theme: pdf_theme
    before

    ---

    after
    EOS

    (expect to_file).to visually_match 'thematic-break-line-style-double.pdf'
  end
end
