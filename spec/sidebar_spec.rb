require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Sidebar' do
  it 'should keep sidebar together if it can fit on one page' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['filler'] * 15).join %(\n\n)}

    .Sidebar
    ****
    #{(['content'] * 15).join %(\n\n)}
    ****
    EOS

    sidebar_text = (pdf.find_text 'Sidebar')[0]
    (expect sidebar_text[:page_number]).to eql 2
  end

  it 'should draw line around sidebar block' do
    pdf = to_pdf <<~'EOS', analyze: :line
    ****
    sidebar
    ****
    EOS

    # NOTE lines without width are for the background
    (expect pdf.lines.select {|it| it[:width] }).to have_size 4
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
    title_text = (pdf.find_text 'Sidebar Title')[0]
    (expect title_text[:font_name]).to eql 'NotoSerif-Bold'
    (expect title_text[:font_size]).to eql 13
    (expect title_text[:x]).to be > 100
    (expect title_text[:y]).to be < sidebar_border_top
  end
end
