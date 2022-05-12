# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Thematic Break' do
  it 'should apply margin bottom to thematic break' do
    input = <<~'EOS'
    before

    '''

    ****
    after
    ****
    EOS
    { 'base' => 12.0, 'default' => 18.0 }.each do |theme, bottom_margin|
      lines = (to_pdf input, attribute_overrides: { 'pdf-theme' => theme }, analyze: :line).lines
      break_line = lines[0]
      sidebar_line = lines[1]
      (expect break_line[:from][:y] - sidebar_line[:from][:y]).to eql bottom_margin
    end
  end

  it 'should apply padding to thematic break' do
    pdf_theme = {
      sidebar_border_radius: 0,
      sidebar_border_width: 0.5,
      sidebar_border_color: '0000EE',
      sidebar_background_color: 'transparent',
      thematic_break_border_color: '00EE00',
    }
    input = <<~'EOS'
    ****
    before
    ****

    '''

    ****
    after
    ****
    EOS
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    sidebar_h_lines = lines.select {|it| it[:from][:y] == it[:to][:y] && it[:color] == '0000EE' }.sort_by {|it| -it[:from][:y] }
    break_line = lines.find {|it| it[:color] == '00EE00' }
    (expect sidebar_h_lines[1][:from][:y] - break_line[:from][:y]).to eql 18.0
    (expect break_line[:from][:y] - sidebar_h_lines[2][:from][:y]).to eql 18.0
  end

  it 'should apply bottom block margin to thematic break with padding 0 when at top of page' do
    pdf_theme = {
      sidebar_border_radius: 0,
      sidebar_border_width: 0.5,
      sidebar_border_color: '0000EE',
      sidebar_background_color: 'transparent',
      thematic_break_border_color: '00EE00',
      thematic_break_padding: 0,
      block_margin_bottom: 10,
    }
    input = <<~'EOS'
    '''

    ****
    after
    ****
    EOS
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    sidebar_h_lines = lines.select {|it| it[:from][:y] == it[:to][:y] && it[:color] == '0000EE' }.sort_by {|it| -it[:from][:y] }
    break_line = lines.find {|it| it[:color] == '00EE00' }
    (expect break_line[:from][:y] - sidebar_h_lines[0][:from][:y]).to eql 10.0
  end

  it 'should use margin_top value as fallback value if padding is not set for backwards compatibility' do
    pdf_theme = {
      sidebar_border_radius: 0,
      sidebar_border_width: 0.5,
      sidebar_border_color: '0000EE',
      sidebar_background_color: 'transparent',
      thematic_break_border_color: '00EE00',
      thematic_break_margin_top: 3,
      thematic_break_padding: nil,
    }
    input = <<~'EOS'
    ****
    before
    ****

    '''

    ****
    after
    ****
    EOS
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    sidebar_h_lines = lines.select {|it| it[:from][:y] == it[:to][:y] && it[:color] == '0000EE' }.sort_by {|it| -it[:from][:y] }
    break_line = lines.find {|it| it[:color] == '00EE00' }
    (expect sidebar_h_lines[1][:from][:y] - break_line[:from][:y]).to eql 15.0
    (expect break_line[:from][:y] - sidebar_h_lines[2][:from][:y]).to eql 15.0
  end

  it 'should apply side padding to thematic break' do
    pdf = to_pdf <<~'EOS', pdf_theme: { thematic_break_padding: [0, 36] }, analyze: :line
    before

    ---

    after
    EOS

    break_line = pdf.lines[0]
    (expect break_line[:from][:x]).to eql 84.24
    (expect break_line[:to][:x]).to eql 511.04
  end

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

  it 'should set width of thematic break to 0.5 if not set in theme' do
    pdf = to_pdf <<~'EOS', pdf_theme: { thematic_break_border_width: nil }, analyze: :line
    before

    ---

    after
    EOS

    lines = pdf.lines
    (expect lines).to have_size 1
    horizontal_rule = lines[0]
    (expect horizontal_rule[:width]).to eql 0.5
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
