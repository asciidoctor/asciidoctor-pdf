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

  it 'should add correct padding around content when using default theme' do
    input = <<~'EOS'
    ****
    first

    last
    ****
    EOS

    pdf = to_pdf input, analyze: true
    lines = (to_pdf input, analyze: :line).lines

    (expect lines).to have_size 4
    (expect lines.map {|it| it[:color] }.uniq).to eql ['E1E1E1']
    (expect lines.map {|it| it[:width] }.uniq).to eql [0.5]
    top, bottom = lines.map {|it| [it[:from][:y], it[:to][:y]] }.flatten.yield_self {|it| [it.max, it.min] }
    left = lines.map {|it| [it[:from][:x], it[:to][:x]] }.flatten.min
    text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
    text_bottom = (pdf.find_unique_text 'last')[:y]
    text_left = (pdf.find_unique_text 'first')[:x]
    (expect (top - text_top).to_f).to (be_within 1.5).of 12.0
    (expect (text_bottom - bottom).to_f).to (be_within 1).of 15.0 # extra padding is descender
    (expect (text_left - left).to_f).to eql 15.0
  end

  it 'should add equal padding around content when using base theme' do
    pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => 'base' }, analyze: true
    ****
    first

    last
    ****
    EOS

    boundaries = (pdf.extract_graphic_states pdf.pages[0][:raw_content])[0]
      .select {|l| l.end_with? 'l' }
      .map {|l| l.split.yield_self {|it| { x: it[0].to_f, y: it[1].to_f } } }
    (expect boundaries).to have_size 8 # border and background
    top, bottom = boundaries.map {|it| it[:y] }.yield_self {|it| [it.max, it.min] }
    left = boundaries.map {|it| it[:x] }.min
    text_top = (pdf.find_unique_text 'first').yield_self {|it| it[:y] + it[:font_size] }
    text_bottom = (pdf.find_unique_text 'last')[:y]
    text_left = (pdf.find_unique_text 'first')[:x]
    (expect (top - text_top).to_f).to (be_within 1).of 12.0
    (expect (text_bottom - bottom).to_f).to (be_within 1).of 15.0 # extra padding is descender
    (expect (text_left - left).to_f).to eql 12.0
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

    pdf = to_pdf input, pdf_theme: { sidebar_title_text_align: nil, heading_text_align: 'center' }, analyze: true
    title_text = pdf.find_unique_text 'Sidebar Title'
    (expect title_text[:x]).to be > 100

    pdf = to_pdf input, pdf_theme: { sidebar_title_text_align: nil, heading_text_align: nil }, analyze: true
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

  it 'should keep title with content when block is advanced to next page' do
    pdf_theme = {
      sidebar_border_radius: 0,
      sidebar_border_width: 0,
      sidebar_background_color: 'DFDFDF',
    }
    pdf = with_content_spacer 10, 680 do |spacer_path|
      to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
      image::#{spacer_path}[]

      .Sidebar Title
      ****

      First block of content.
      ****
      EOS
    end

    pages = pdf.pages
    (expect pages).to have_size 2
    title_text = pdf.find_unique_text 'Sidebar Title'
    content_text = pdf.find_unique_text 'First block of content.'
    (expect title_text[:page_number]).to be 2
    (expect content_text[:page_number]).to be 2
    (pdf.extract_graphic_states pages[0][:raw_content]).each do |p1_gs|
      (expect p1_gs).not_to include '0.87451 0.87451 0.87451 scn'
    end
    p2_gs = (pdf.extract_graphic_states pages[1][:raw_content])[0]
    (expect p2_gs).to have_background color: 'DFDFDF', top_left: [48.24, 805.89], bottom_right: [547.04, 737.63]
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

  it 'should not collapse bottom padding if block ends near bottom of page' do
    pdf_theme = {
      sidebar_padding: 12,
      sidebar_background_color: 'EEEEEE',
      sidebar_border_width: 0,
      sidebar_border_radius: 0,
    }

    [%(****\ncontent +\nthat wraps\n****), %([sidebar%hardbreaks]\ncontent\nthat wraps)].each do |content|
      pdf = with_content_spacer 10, 690 do |spacer_path|
        to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        image::#{spacer_path}[]

        #{content}
        EOS
      end

      pages = pdf.pages
      (expect pages).to have_size 1
      gs = pdf.extract_graphic_states pages[0][:raw_content]
      (expect gs[1]).to have_background color: 'EEEEEE', top_left: [48.24, 103.89], bottom_right: [48.24, 48.33]
      last_text_y = pdf.text[-1][:y]
      (expect last_text_y - pdf_theme[:sidebar_padding]).to be > 48.24

      pdf = with_content_spacer 10, 692 do |spacer_path|
        to_pdf <<~EOS, pdf_theme: pdf_theme, analyze: true
        image::#{spacer_path}[]

        #{content}
        EOS
      end

      pages = pdf.pages
      (expect pages).to have_size 2
      gs = pdf.extract_graphic_states pages[0][:raw_content]
      (expect gs[1]).to have_background color: 'EEEEEE', top_left: [48.24, 101.89], bottom_right: [48.24, 48.24]
      (expect pdf.text[0][:page_number]).to eql 1
      (expect pdf.text[1][:page_number]).to eql 2
      (expect pdf.text[0][:y] - pdf_theme[:sidebar_padding]).to be > 48.24
    end
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

  it 'should allow font size of sidebar to be specified using absolute units' do
    pdf = to_pdf <<~'EOS', pdf_theme: { sidebar_font_size: 9 }, analyze: true
    ****
    sidebar
    ****
    EOS

    sidebar_text = pdf.find_unique_text 'sidebar'
    (expect sidebar_text[:font_size]).to eql 9
  end

  it 'should allow font size of sidebar to be specified using relative units' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_size: 12, sidebar_font_size: '0.75em' }, analyze: true
    ****
    sidebar
    ****
    EOS

    sidebar_text = pdf.find_unique_text 'sidebar'
    (expect sidebar_text[:font_size]).to eql 9
  end

  it 'should allow font size of code block in sidebar to be specified using relative units' do
    pdf = to_pdf <<~'EOS', pdf_theme: { sidebar_font_size: 12, code_font_size: '0.75em' }, analyze: true
    ****
    sidebar

    ----
    code block
    ----
    ****
    EOS

    sidebar_text = pdf.find_unique_text 'sidebar'
    (expect sidebar_text[:font_size]).to eql 12

    code_block_text = pdf.find_unique_text 'code block'
    (expect code_block_text[:font_size]).to eql 9
  end
end
