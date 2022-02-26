# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Sidebar' do
  it 'should draw line around sidebar block' do
    pdf = to_pdf <<~'EOS', analyze: :line, pdf_theme: { sidebar_background_color: 'transparent' }
    ****
    sidebar
    ****
    EOS

    (expect pdf.lines).to have_size 4
    (expect pdf.lines.map {|it| it[:color] }.uniq).to eql ['E1E1E1']
    (expect pdf.lines.map {|it| it[:width] }.uniq).to eql [0.5]
  end

  it 'should apply dashed border style defined by theme', visual: true do
    pdf_theme = {
      sidebar_border_width: 1,
      sidebar_border_style: 'dashed',
      sidebar_border_color: 'cccccc',
    }
    to_file = to_pdf_file <<~'EOS', 'sidebar-border-style-dashed.pdf', pdf_theme: pdf_theme
    ****
    sidebar
    ****
    EOS

    (expect to_file).to visually_match 'sidebar-border-style-dashed.pdf'
  end

  it 'should apply dotted border style defined by theme', visual: true do
    pdf_theme = {
      sidebar_border_width: 1.5,
      sidebar_border_style: 'dotted',
      sidebar_border_color: 'cccccc',
    }
    to_file = to_pdf_file <<~'EOS', 'sidebar-border-style-dotted.pdf', pdf_theme: pdf_theme
    ****
    sidebar
    ****
    EOS

    (expect to_file).to visually_match 'sidebar-border-style-dotted.pdf'
  end

  it 'should use block title as heading of sidebar block' do
    input = <<~'EOS'
    .Sidebar Title
    ****
    Sidebar content.
    ****
    EOS

    pdf = to_pdf input, analyze: :line
    sidebar_border_top = pdf.lines.find {|it| it[:color] == 'E1E1E1' }[:from][:y]

    pdf = to_pdf input, analyze: true
    title_text = pdf.find_unique_text 'Sidebar Title'
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect title_text[:font_size]).to be 13
    (expect title_text[:x]).to be > 100
    (expect title_text[:y]).to be < sidebar_border_top

    pdf = to_pdf input, pdf_theme: { sidebar_title_align: nil, heading_align: 'center' }, analyze: true
    title_text = pdf.find_unique_text 'Sidebar Title'
    (expect title_text[:x]).to be > 100

    pdf = to_pdf input, pdf_theme: { sidebar_title_align: nil, heading_align: nil }, analyze: true
    title_text = pdf.find_unique_text 'Sidebar Title'
    (expect title_text[:x]).to be < 100
  end

  it 'should render adjacent sidebars without overlapping', visual: true do
    to_file = to_pdf_file <<~'EOS', 'sidebar-adjacent.pdf'
    ****
    this

    is

    a

    sidebar
    ****

    ****
    another

    sidebar
    ****
    EOS

    (expect to_file).to visually_match 'sidebar-adjacent.pdf'
  end

  it 'should keep sidebar together if it can fit on one page' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['filler'] * 15).join %(\n\n)}

    .Sidebar
    [%unbreakable]
    ****
    #{(['content'] * 15).join %(\n\n)}
    ****
    EOS

    sidebar_text = (pdf.find_text 'Sidebar')[0]
    (expect sidebar_text[:page_number]).to be 2
  end

  it 'should split block if it cannot fit on one page' do
    pdf = to_pdf <<~EOS, analyze: true
    .Sidebar Title
    ****
    #{(['content'] * 30).join %(\n\n)}
    ****
    EOS

    title_text = (pdf.find_text 'Sidebar Title')[0]
    content_text = (pdf.find_text 'content')
    (expect title_text[:page_number]).to be 1
    (expect content_text[0][:page_number]).to be 1
    (expect content_text[-1][:page_number]).to be 2
  end

  it 'should split border when block is split across pages', visual: true do
    to_file = to_pdf_file <<~EOS, 'sidebar-page-split.pdf'
    .Sidebar Title
    ****
    #{(['content'] * 30).join %(\n\n)}
    ****
    EOS

    (expect to_file).to visually_match 'sidebar-page-split.pdf'
  end

  it 'should extend block to bottom of page but not beyond if content ends with page break', visual: true do
    to_file = to_pdf_file <<~'EOS', 'sidebar-with-trailing-page-break.pdf'
    .Sidebar Title
    ****
    Sidebar

    Contents

    <<<
    ****

    after
    EOS

    (expect to_file).to visually_match 'sidebar-with-trailing-page-break.pdf'
  end

  it 'should not add border if border width is not set in theme or value is nil' do
    pdf = to_pdf <<~'EOS', pdf_theme: { sidebar_border_color: 'AA0000', sidebar_border_width: nil }, analyze: :line
    ****
    Sidebar
    ****
    EOS

    (expect pdf.lines).to have_size 0
  end

  it 'should not add border if border color is transaprent' do
    pdf = to_pdf <<~'EOS', pdf_theme: { sidebar_border_color: 'transparent' }, analyze: :line
    ****
    Sidebar
    ****
    EOS

    (expect pdf.lines).to have_size 0
  end

  it 'should cut split indicator with preset width into background if sidebar has no border', visual: true do
    pdf_theme = {
      sidebar_border_width: 0,
      sidebar_border_radius: 5,
    }
    to_file = to_pdf_file <<~EOS, 'sidebar-page-split-no-border.pdf', pdf_theme: pdf_theme
    .Sidebar Title
    ****
    #{(['content'] * 30).join %(\n\n)}
    ****
    EOS

    (expect to_file).to visually_match 'sidebar-page-split-no-border.pdf'
  end

  it 'should cut split indicator into background if sidebar has transparent border', visual: true do
    pdf_theme = {
      sidebar_border_width: 1,
      sidebar_border_color: 'transparent',
      sidebar_border_radius: 5,
    }
    to_file = to_pdf_file <<~EOS, 'sidebar-page-split-transparent-border.pdf', pdf_theme: pdf_theme
    .Sidebar Title
    ****
    #{(['content'] * 30).join %(\n\n)}
    ****
    EOS

    (expect to_file).to visually_match 'sidebar-page-split-transparent-border.pdf'
  end
end
