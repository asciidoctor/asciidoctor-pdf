# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Floating Title' do
  it 'should apply alignment defined for headings in theme' do
    pdf_theme = {
      heading_text_align: 'center',
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    [discrete]
    == Discrete Heading

    main content
    EOS

    discrete_heading_text = pdf.find_unique_text 'Discrete Heading'
    main_text = pdf.find_unique_text 'main content'
    (expect discrete_heading_text[:x]).to be > main_text[:x]
  end

  it 'should apply alignment defined for heading level in theme' do
    pdf_theme = {
      heading_text_align: 'left',
      heading_h2_text_align: 'center',
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    [discrete]
    == Discrete Heading

    main content
    EOS

    discrete_heading_text = pdf.find_unique_text 'Discrete Heading'
    main_text = pdf.find_unique_text 'main content'
    (expect discrete_heading_text[:x]).to be > main_text[:x]
  end

  it 'should use base text align to align floating title if theme does not specify alignemnt' do
    pdf_theme = {
      base_text_align: 'center',
      heading_h2_text_align: nil,
      heading_text_align: nil,
    }
    pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
    [discrete]
    == Discrete Heading

    [.text-left]
    main content
    EOS

    discrete_heading_text = pdf.find_unique_text 'Discrete Heading'
    main_text = pdf.find_unique_text 'main content'
    (expect discrete_heading_text[:x]).to be > main_text[:x]
  end

  it 'should force discrete heading to next page if space below is less than heading-min-height-after value' do
    pdf = with_content_spacer 10, 690 do |spacer_path|
      to_pdf <<~EOS
      image::#{spacer_path}[]

      [discrete#buddy]
      == Discrete Heading

      Don't abandon me!
      EOS
    end

    (expect pdf.pages).to have_size 2
    p2_text = (pdf.page 2).text
    (expect p2_text).to include 'Discrete Heading'
    (expect get_names pdf).to have_key 'buddy'
    (expect (get_dest pdf, 'buddy')[:page_number]).to eql 2
  end

  it 'should force discrete heading with breakable option to next page if no content is inked below it' do
    pdf = with_content_spacer 10, 675 do |spacer_path|
      to_pdf <<~EOS, pdf_theme: { heading_min_height_after: nil }
      image::#{spacer_path}[]

      [discrete#buddy%breakable]
      == Discrete Heading

      ----
      Do it like this.
      ----
      EOS
    end

    (expect pdf.pages).to have_size 2
    p2_text = (pdf.page 2).text
    (expect p2_text).to include 'Discrete Heading'
    (expect get_names pdf).to have_key 'buddy'
    (expect (get_dest pdf, 'buddy')[:page_number]).to eql 2
  end

  it 'should force discrete heading to next page when heading-min-height-after is auto if no content is inked below it' do
    pdf = with_content_spacer 10, 675 do |spacer_path|
      to_pdf <<~EOS, pdf_theme: { heading_min_height_after: 'auto' }
      image::#{spacer_path}[]

      [discrete#buddy]
      == Discrete Heading

      ----
      Do it like this.
      ----
      EOS
    end

    (expect pdf.pages).to have_size 2
    p2_text = (pdf.page 2).text
    (expect p2_text).to include 'Discrete Heading'
    (expect get_names pdf).to have_key 'buddy'
    (expect (get_dest pdf, 'buddy')[:page_number]).to eql 2
  end

  it 'should ignore heading-min-height-after if heading is last child' do
    pdf = with_content_spacer 10, 650 do |spacer_path|
      to_pdf <<~EOS, pdf_theme: { heading_min_height_after: 100, heading_font_color: 'AA0000' }, analyze: true
      image::#{spacer_path}[]

      [discrete]
      == Heading Fits
      EOS
    end

    (expect pdf.pages).to have_size 1
    heading_text = pdf.find_unique_text font_color: 'AA0000'
    (expect heading_text[:page_number]).to eql 1
  end

  it 'should allow arrange_heading to be reimplemented to always keep heading with content that follows it' do
    source_file = doc_file 'modules/extend/examples/pdf-converter-avoid-break-after-heading.rb'
    source_lines = (File.readlines source_file).select {|l| l == ?\n || (l.start_with? ' ') }
    ext_class = create_class Asciidoctor::Converter.for 'pdf'
    backend = %(pdf#{ext_class.object_id})
    source_lines[0] = %(  register_for '#{backend}'\n)
    ext_class.class_eval source_lines.join, source_file
    pdf = to_pdf <<~EOS, backend: backend, analyze: true
    [discrete]
    == Heading A

    [discrete]
    == Heading B

    image::tall.svg[pdfwidth=65mm]

    [discrete]
    == Heading C

    [%unbreakable]
    --
    keep

    this

    together
    --
    EOS

    heading_c_text = pdf.find_unique_text 'Heading C'
    (expect heading_c_text[:page_number]).to be 2
    content_text = pdf.find_unique_text 'keep'
    (expect content_text[:page_number]).to be 2
  end

  it 'should not force discrete heading to next page if heading-min-height-after value is not set' do
    pdf = with_content_spacer 10, 690 do |spacer_path|
      to_pdf <<~EOS, pdf_theme: { heading_min_height_after: nil }
      image::#{spacer_path}[]

      [discrete#buddy]
      == Discrete Heading

      Don't abandon me!
      EOS
    end

    (expect pdf.pages).to have_size 2
    p1_text = (pdf.page 1).text
    (expect p1_text).to include 'Discrete Heading'
    p2_text = (pdf.page 2).text
    (expect p2_text).to include 'abandon'
    (expect get_names pdf).to have_key 'buddy'
    (expect (get_dest pdf, 'buddy')[:page_number]).to eql 1
  end

  it 'should not force discrete heading without breakable option to next page if no content is inked below it' do
    pdf = with_content_spacer 10, 675 do |spacer_path|
      to_pdf <<~EOS
      image::#{spacer_path}[]

      [discrete#buddy]
      == Discrete Heading

      ----
      Do it like this.
      ----
      EOS
    end

    (expect pdf.pages).to have_size 2
    p1_text = (pdf.page 1).text
    (expect p1_text).to include 'Discrete Heading'
    p2_text = (pdf.page 2).text
    (expect p2_text).to include 'like this'
    (expect get_names pdf).to have_key 'buddy'
    (expect (get_dest pdf, 'buddy')[:page_number]).to eql 1
  end

  it 'should not force discrete heading to next page if it has no next sibling' do
    pdf = with_content_spacer 10, 690 do |spacer_path|
      to_pdf <<~EOS
      image::#{spacer_path}[]

      [discrete#buddy]
      == Discrete Heading
      EOS
    end

    (expect pdf.pages).to have_size 1
    p1_text = (pdf.page 1).text
    (expect p1_text).to include 'Discrete Heading'
    (expect get_names pdf).to have_key 'buddy'
    (expect (get_dest pdf, 'buddy')[:page_number]).to eql 1
  end

  it 'should outdent discrete heading' do
    pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
    = Document Title

    == Section

    paragraph

    [discrete]
    === Discrete Heading

    paragraph

    === Nested Section

    paragraph

    [discrete]
    ==== Another Discrete Heading

    paragraph
    EOS

    discrete_heading_texts = pdf.find_text %r/Discrete/
    (expect discrete_heading_texts).to have_size 2
    (expect discrete_heading_texts[0][:x]).to eql 48.24
    (expect discrete_heading_texts[1][:x]).to eql 48.24
    paragraph_texts = pdf.find_text 'paragraph'
    (expect paragraph_texts.map {|it| it[:x] }.uniq).to eql [84.24]
  end

  it 'should not outdent discrete heading inside block' do
    pdf = to_pdf <<~'EOS', pdf_theme: { section_indent: 36 }, analyze: true
    == Section

    ****
    sidebar content

    [discrete]
    == Discrete Heading
    ****
    EOS

    sidebar_content_text = (pdf.find_text 'sidebar content')[0]
    discrete_heading_text = (pdf.find_text 'Discrete Heading')[0]
    (expect sidebar_content_text[:x]).to eql discrete_heading_text[:x]
  end

  it 'should honor text alignment role on discrete heading' do
    pdf = to_pdf <<~'EOS', analyze: true
    [discrete]
    == Discrete Heading
    EOS
    left_x = (pdf.find_text 'Discrete Heading')[0][:x]

    pdf = to_pdf <<~'EOS', analyze: true
    [discrete.text-right]
    == Discrete Heading
    EOS
    right_x = (pdf.find_text 'Discrete Heading')[0][:x]

    (expect right_x).to be > left_x
  end

  it 'should allow theme to add borders and padding to specific heading levels' do
    pdf_theme = {
      heading_line_height: 1,
      heading_font_family: 'Times-Roman',
      heading_h2_border_width: [2, 0],
      heading_h2_border_color: 'AA0000',
      heading_h2_padding: [10, 0],
      heading_h3_border_width: [0, 0, 1, 0],
      heading_h3_border_style: 'dashed',
      heading_h3_border_color: 'DDDDDD',
      heading_h3_padding: [0, 0, 5],
    }

    input = <<~'EOS'
    [discrete]
    == Heading Level 1

    content

    [discrete]
    === Heading Level 2

    content
    EOS

    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true

    (expect lines).to have_size 3
    (expect lines[0][:color]).to eql 'AA0000'
    (expect lines[0][:width]).to eql 2
    (expect lines[0][:style]).to eql :solid
    (expect lines[1][:color]).to eql 'AA0000'
    (expect lines[1][:width]).to eql 2
    (expect lines[1][:style]).to eql :solid
    (expect lines[2][:color]).to eql 'DDDDDD'
    (expect lines[2][:width]).to eql 1
    (expect lines[2][:style]).to eql :dashed
    lines.each do |line|
      (expect line[:from][:y]).to eql line[:to][:y]
    end
    heading_level_1_text = pdf.find_unique_text 'Heading Level 1'
    heading_level_2_text = pdf.find_unique_text 'Heading Level 2'
    (expect lines[0][:from][:y]).to be > heading_level_1_text[:y]
    (expect lines[1][:from][:y]).to be < heading_level_1_text[:y]
    (expect lines[2][:from][:y]).to be < heading_level_2_text[:y]
    (expect heading_level_1_text[:y] - lines[1][:from][:y]).to be > 10
    (expect heading_level_2_text[:y] - lines[2][:from][:y]).to be > 5
  end
end
