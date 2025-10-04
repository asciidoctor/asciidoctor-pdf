# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Image Float' do
  page_width = 612.0
  page_height = 792.0
  page_margin = 36.0
  float_gap_s = 12.0
  float_gap_b = 6.0

  let :pdf_theme do
    {
      page_margin: page_margin,
      page_size: [page_width, page_height],
    }
  end

  it 'should ignore float attribute is value is unknown' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=center]

    #{lorem_ipsum '1-sentence'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    (expect image[:x]).to eql page_margin
    first_line = pdf.text[0]
    (expect first_line[:y]).to be < (image[:y] + image[:height])
  end

  it 'should wrap paragraph around left of image with float right' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=right]

    #{lorem_ipsum '1-sentence'}
    EOS

    images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
    (expect images).to have_size 1
    image = images[0]
    (expect image[:width].to_f).to eql 216.0
    (expect image[:x].to_f).to eql page_width - page_margin - image[:width].to_f
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    first_line = pdf.text[0]
    (expect first_line[:x].to_f).to eql page_margin
    text_right_boundary = image[:x] - float_gap_s
    pdf.text.each {|text| (expect text[:x] + text[:width]).to be < text_right_boundary }
  end

  it 'should ignore align attribute if float attribute is set' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,align=left,float=right]

    #{lorem_ipsum '1-sentence'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    (expect image[:x].to_f).to eql page_width - page_margin - image[:width].to_f
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    first_line = pdf.text[0]
    (expect first_line[:x].to_f).to eql page_margin
    text_right_boundary = image[:x] - float_gap_s
    pdf.text.each {|text| (expect text[:x] + text[:width]).to be < text_right_boundary }
  end

  it 'should wrap paragraph around right of image with float left' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{lorem_ipsum '1-sentence'}
    EOS

    images = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images
    (expect images).to have_size 1
    image = images[0]
    (expect image[:width].to_f).to eql 216.0
    (expect image[:x].to_f).to eql page_margin
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    pdf.text.each {|text| (expect text[:x]).to eql text_left_boundary }
  end

  it 'should apply hyphenation to paragraph in float box if hyphens is set', if: (gem_available? 'text-hyphen'), &(proc do
    input = <<~EOS
    :hyphens:

    image::rect.png[pdfwidth=3in,float=right]

    This story chronicles the inexplicable hazards and tremendously vicious beasts the team must conquer and vanquish.
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[0]).to end_with ?\u00ad
    (expect lines[0].count ?\u00ad).to be 1
  end)

  it 'should apply base font color to text within float box' do
    pdf_theme[:base_font_color] = '0000AA'
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=right]

    #{lorem_ipsum '1-sentence'}
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    (expect pdf.text[0][:font_color]).to eql pdf_theme[:base_font_color]
  end

  it 'should fit single paragraph within float box' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=right]

    #{lorem_ipsum '1-sentence'}
    *fin*
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    fin_text = pdf.find_unique_text 'fin'
    (expect fin_text).not_to be_nil
    (expect fin_text[:x] + fin_text[:width]).to be < image[:x]
    (expect fin_text[:y]).to be > image[:y] - image[:height]
  end

  it 'should fit multiple paragraphs within float box' do
    ref_input = lorem_ipsum '2-sentences-2-paragraphs'

    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{ref_input}
    EOS

    pdf = to_pdf ref_input, pdf_theme: (pdf_theme.merge section_indent: [228, 0]), analyze: true
    fragments = pdf.text
    expected_text_top = fragments[0][:y]
    p2_start_idx = fragments.index {|it| it[:string].start_with? 'Magna' }
    expected_paragraph_gap = (fragments[p2_start_idx - 1][:y] - fragments[p2_start_idx][:y]).round 5

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    fragments = pdf.text
    fragments.each {|text| (expect text[:x]).to eql text_left_boundary }
    p2_start_idx = fragments.index {|it| it[:string].start_with? 'Magna' }
    paragraph_gap = (fragments[p2_start_idx - 1][:y] - fragments[p2_start_idx][:y]).round 5
    (expect fragments[0][:y]).to eql expected_text_top
    (expect paragraph_gap).to eql expected_paragraph_gap
  end

  it 'should wrap current paragraph around bottom of image if it extends beyond image' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{lorem_ipsum '4-sentences-1-paragraph'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    fragments = pdf.text
    first_line_text = fragments[0]
    (expect first_line_text[:x]).to eql text_left_boundary
    last_line_text = fragments[-1]
    (expect last_line_text[:x]).to eql page_margin
    # NOTE: the line that didn't fit will be fragmented so that two fragments get placed on the first line under the image
    (expect fragments[-3][:y]).to eql fragments[-2][:y]
    line_gaps = (1.upto fragments.size - 1).map {|idx| (fragments[idx - 1][:y] - fragments[idx][:y]).round 5 }.reject {|it| it == 0 }
    (expect line_gaps.reject(&:zero?).uniq).to eql [15.78]
  end

  it 'should wrap second paragraph around bottom of image if it extends beyond image' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    fragments = pdf.text
    first_line_text = fragments[0]
    (expect first_line_text[:x]).to eql text_left_boundary
    last_line_text = fragments[-1]
    (expect last_line_text[:x]).to eql page_margin
  end

  it 'should wrap around single-line caption on bottom of image' do
    pdf_theme[:image_caption_font_color] = 'AA0000'
    input = <<~EOS
    .Image description
    image::rect.png[pdfwidth=2in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    caption_texts = pdf.find_text font_color: 'AA0000'
    (expect caption_texts).to have_size 1
    (expect caption_texts[0][:x]).to eql page_margin
    fragments = pdf.text - caption_texts
    first_line = fragments[0]
    (expect first_line[:x]).to eql text_left_boundary
    last_line = fragments[-1]
    (expect last_line[:x]).to eql page_margin
    first_line_after_float = fragments.find {|it| it[:x] == page_margin }
    (expect caption_texts[0][:y] - first_line_after_float[:y]).to (be_within 1).of 30
  end

  it 'should wrap around multi-line caption on bottom of image' do
    pdf_theme[:image_caption_font_color] = 'AA0000'
    input = <<~EOS
    .Long image description
    image::rect.png[pdfwidth=2in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    caption_texts = pdf.find_text font_color: 'AA0000'
    (expect caption_texts).to have_size 2
    (expect caption_texts[0][:x]).to eql page_margin
    fragments = pdf.text - caption_texts
    first_line = fragments[0]
    (expect first_line[:x]).to eql text_left_boundary
    last_line = fragments[-1]
    (expect last_line[:x]).to eql page_margin
    first_line_after_float = fragments.find {|it| it[:x] == page_margin }
    (expect caption_texts[-1][:y] - first_line_after_float[:y]).to (be_within 1).of 30
  end

  it 'should wrap around bottom of image when image has single-line caption on top' do
    pdf_theme[:image_caption_end] = 'top'
    pdf_theme[:image_caption_font_color] = 'AA0000'
    input = <<~EOS
    .Image description
    image::rect.png[pdfwidth=2in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    fragments = pdf.text - (pdf.find_text font_color: 'AA0000')
    first_line = fragments[0]
    (expect first_line[:x]).to eql text_left_boundary
    last_line = fragments[-1]
    (expect last_line[:x]).to eql page_margin
    first_line_after_float = fragments.find {|it| it[:x] == page_margin }
    expected_ceil = image[:y] - image[:height] - float_gap_b
    (expect first_line_after_float[:y] + first_line_after_float[:font_size]).to be < expected_ceil
  end

  it 'should wrap around bottom of image when image has multi-line caption on top' do
    pdf_theme[:image_caption_end] = 'top'
    pdf_theme[:image_caption_font_color] = 'AA0000'
    input = <<~EOS
    .Long image description
    image::rect.png[pdfwidth=2in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    fragments = pdf.text - (pdf.find_text font_color: 'AA0000')
    first_line = fragments[0]
    (expect first_line[:x]).to eql text_left_boundary
    last_line = fragments[-1]
    (expect last_line[:x]).to eql page_margin
    first_line_after_float = fragments.find {|it| it[:x] == page_margin }
    expected_ceil = image[:y] - image[:height] - float_gap_b
    (expect first_line_after_float[:y] + first_line_after_float[:font_size]).to be < expected_ceil
  end

  it 'should place caption directly under image when image floats to the right' do
    input = <<~EOS
    .Image description
    image::rect.png[pdfwidth=3in,float=right]

    #{lorem_ipsum '1-sentence'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    caption_text = pdf.find_unique_text %r/^Figure/
    (expect caption_text[:x]).to eql image[:x]
  end

  it 'should allow theme to specify float gap using single value' do
    pdf_theme[:image_float_gap] = 24
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + pdf_theme[:image_float_gap]
    fragments = pdf.text
    first_line = fragments[0]
    (expect first_line[:x]).to eql text_left_boundary
    last_line = fragments[-1]
    (expect last_line[:x]).to eql page_margin
    first_line_after_float = (pdf.find_text x: page_margin)[0]
    expected_ceil = image[:y] - image[:height] - pdf_theme[:image_float_gap]
    (expect first_line_after_float[:y]).to be < expected_ceil
  end

  it 'should allow theme to specify float gap using array value (side, bottom)' do
    pdf_theme[:image_float_gap] = [0, 0]
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width]
    fragments = pdf.text
    first_line = fragments[0]
    (expect first_line[:x]).to eql text_left_boundary
    last_line = fragments[-1]
    (expect last_line[:x]).to eql page_margin
    first_line_after_float = (pdf.find_text x: page_margin)[0]
    expected_ceil = image[:y] - image[:height]
    (expect first_line_after_float[:y]).to be < expected_ceil
  end

  it 'should apply base font color to text that extends beyond image' do
    pdf_theme[:base_font_color] = '0000AA'
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=right]

    #{lorem_ipsum '4-sentences-1-paragraph'}
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    (expect pdf.text[-1][:font_color]).to eql pdf_theme[:base_font_color]
  end

  it 'should add anchors to paragraphs in float box' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=right]

    [#first]
    #{lorem_ipsum '1-sentence'}

    [#second]
    #{lorem_ipsum '1-sentence'}
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme
    names = get_names pdf
    (expect names).to have_key 'first'
    (expect names).to have_key 'second'
  end

  it 'should apply text-align to text within float box' do
    input = <<~'EOS'
    image::rect.png[pdfwidth=3in,float=right]

    [.text-center]
    center me
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    text = (to_pdf input, pdf_theme: pdf_theme, analyze: true).text[0]
    (expect text[:x]).to be > page_margin
    midpoint = text[:x] + (text[:width] * 0.5)
    expected_midpoint = (image[:x] - float_gap_s - page_margin) * 0.5 + page_margin
    (expect midpoint).to eql expected_midpoint
  end

  it 'should support role on paragraph in float box' do
    pdf_theme[:role_important_text_align] = 'center'
    pdf_theme[:role_important_font_color] = 'AA0000'
    pdf_theme[:role_important_text_transform] = 'uppercase'
    input = <<~'EOS'
    image::rect.png[pdfwidth=3in,float=right]

    [.important]
    center me
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    text = (to_pdf input, pdf_theme: pdf_theme, analyze: true).text[0]
    (expect text[:x]).to be > page_margin
    midpoint = text[:x] + (text[:width] * 0.5)
    expected_midpoint = (image[:x] - float_gap_s - page_margin) * 0.5 + page_margin
    (expect midpoint).to eql expected_midpoint
    (expect text[:string]).to eql 'CENTER ME'
    (expect text[:font_color]).to eql 'AA0000'
  end

  it 'should apply text formatting to wrapped text' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{((lorem_ipsum '4-sentences-1-paragraph').sub 'Lorem', '*Lorem*').sub 'tempor', '_tempor_'}
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    bold_text = pdf.find_text font_name: 'NotoSerif-Bold'
    (expect bold_text).to have_size 1
    italic_text = pdf.find_text font_name: 'NotoSerif-Italic'
    (expect italic_text).to have_size 1
  end

  # TODO: could check that gap to next paragraph is correct
  it 'should honor role that changes font size, font family, and line height on paragraph in float box' do
    pdf_theme[:extends] = 'default-with-fallback-font'
    pdf_theme[:role_lead_line_height] = 1.5
    pdf_theme[:role_lead_font_family] = 'M+ 1p Fallback'
    pdf_theme[:role_muted_font_color] = '999999'
    input = <<~EOS
    image::rect.png[pdfwidth=2.25in,float=left]

    [.muted]
    #{lorem_ipsum '1-sentence'}

    [.lead]
    #{lorem_ipsum '2-sentences-1-paragraph'}

    [.muted]
    #{lorem_ipsum '1-sentence'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    lead_fragments = pdf.text - (pdf.find_text font_color: '999999')
    (expect lead_fragments[0][:x]).to eql image[:x] + image[:width] + float_gap_s
    (expect lead_fragments[-1][:x]).to eql page_margin
    lead_fragments.each do |fragment|
      (expect fragment[:font_name]).to eql 'mplus-1p-regular'
      (expect fragment[:font_size]).to eql 13
    end
    line_gaps = (1.upto lead_fragments.size - 1)
      .map {|idx| (lead_fragments[idx - 1][:y] - lead_fragments[idx][:y]).round 5 }
      .reject {|it| it == 0 }
    (expect line_gaps.uniq).to eql [20.67]
  end

  it 'should support prose text indent and prose margin inner' do
    pdf_theme.update \
      prose_text_indent_inner: 18,
      prose_margin_inner: 0
    input = <<~EOS
    image::rect.png[pdfwidth=50%,float=right]

    #{lorem_ipsum '4-sentences-2-paragraphs'}

    fin.
    EOS
    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    first_line_first_para_text = pdf.find_unique_text %r/^Lorem/
    (expect first_line_first_para_text[:x]).to eql page_margin
    first_line_second_para_text = pdf.find_unique_text %r/^Blandit/
    (expect first_line_second_para_text[:x]).to eql page_margin + 18
    first_line_last_para_text = pdf.find_unique_text 'fin.'
    (expect first_line_last_para_text[:x]).to eql page_margin + 18
    lines_wrapping_under = pdf.text.select {|it| it[:x] + it[:width] > image[:x] }
    (expect lines_wrapping_under).not_to be_empty
    last_line_first_para_text = pdf.text[(pdf.text.index first_line_second_para_text) - 1]
    inner_margin = last_line_first_para_text[:y] - (first_line_second_para_text[:y] + first_line_second_para_text[:font_size])
    (expect inner_margin).to be < 12
  end

  it 'should not end float box if next unstyled paragraph will fit' do
    with_content_spacer 180, 220 do |spacer_path|
      input = <<~EOS
      image::#{spacer_path}[float=left]

      #{lorem_ipsum '1-sentence'}

      [.lead]
      #{lorem_ipsum '2-sentences-1-paragraph'}

      #{lorem_ipsum '1-sentence'}
      EOS

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      expected_x = 228.0
      pdf.text.each {|text| (expect text[:x]).to eql expected_x }
    end
  end

  it 'should position next block below wrapped content when wrapped content extends past image' do
    pdf_theme.update code_border_radius: 0, code_border_color: '0000EE', code_border_width: [0.5, 0, 0, 0]

    ref_input = <<~'EOS'
    para

    ----
    code block
    ----
    EOS

    expected_margin = (
      ((to_pdf ref_input, pdf_theme: pdf_theme, analyze: true).find_unique_text 'para')[:y] -
      (to_pdf ref_input, pdf_theme: pdf_theme, analyze: :line).lines[0][:from][:y]
    ).round 5

    input = <<~EOS
    image::rect.png[pdfwidth=1.75in,float=left]

    #{lorem_ipsum '2-paragraphs'}

    ----
    code block
    ----
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    code_block_top = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines[0][:from][:y]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    float_bottom = image[:y] - image[:height]
    last_para_text = pdf.find_unique_text %r/All your base/
    (expect last_para_text[:x]).to eql (image[:x] + image[:width] + float_gap_s)
    (expect last_para_text[:y]).to be < float_bottom
    (expect code_block_top).to be < float_bottom
    code_block_text = pdf.find_unique_text 'code block'
    (expect code_block_text[:y]).to be < code_block_top
    (expect (last_para_text[:y] - code_block_top).round 5).to eql expected_margin
  end

  it 'should end float box after first paragraph if next block is not a paragraph' do
    input = <<~EOS
    image::rect.png[pdfwidth=3in,float=left]

    #{lorem_ipsum '1-sentence'}

    term:: desc
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    (expect pdf.text[0][:x]).to eql text_left_boundary
    term_text = pdf.find_unique_text 'term'
    (expect term_text[:x]).to eql page_margin
    compiled_pdf_theme = build_pdf_theme pdf_theme
    expected_next_top = image[:y] - image[:height] - compiled_pdf_theme.block_margin_bottom
    (expect term_text[:y] + term_text[:font_size]).to (be_within 2).of expected_next_top
  end

  it 'should not create float box if next block is not a paragraph' do
    input = <<~'EOS'
    image::rect.png[pdfwidth=50%,float=right]

    term:: desc
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    compiled_pdf_theme = build_pdf_theme pdf_theme
    expected_next_top = image[:y] - image[:height] - compiled_pdf_theme.block_margin_bottom
    term_text = pdf.find_unique_text 'term'
    (expect term_text[:x]).to eql page_margin
    (expect term_text[:y] + term_text[:font_size]).to (be_within 2).of expected_next_top
    (expect image[:x]).to eql (pdf.pages[0][:size][0] * 0.5)
  end

  # also verifies that unwrapped paragraph isn't pulled closer to previous than prose margin bottom
  it 'should continue below image if next paragraph does not fit in remaining height' do
    pdf_theme[:role_outline_border_width] = 0.5
    pdf_theme[:role_outline_border_color] = '0000EE'
    input = <<~EOS
    image::rect.png[pdfwidth=1.5in,float=left]

    #{(lorem_ipsum '4-sentences-2-paragraphs').gsub %r/non|nam/, '[.outline]#\\0#'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    rects = (to_pdf input, pdf_theme: pdf_theme, analyze: :rect).rectangles
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    (expect pdf.text[0][:x]).to eql text_left_boundary
    last_para_in_float_bottom = rects[0][:point][1]
    first_para_below_float_top = rects[1][:point][1] + rects[1][:height]
    (expect last_para_in_float_bottom - first_para_below_float_top).to eql 13.5 # 12 + 1.5 leading
  end

  it 'should indent and align next paragraph if next paragraph does not fit in remaining height and prose-text-indent is set' do
    pdf_theme[:prose_text_indent] = 18
    input = <<~EOS
    image::rect.png[pdfwidth=1.5in,float=left]

    #{(lorem_ipsum '4-sentences-2-paragraphs').sub 'Blandit', %([.text-left]\nBlandit)}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    (expect pdf.text[0][:x]).to eql text_left_boundary + 18
    first_line_below_float = pdf.text.find {|it| it[:x] < text_left_boundary }
    (expect first_line_below_float[:x]).to eql page_margin + 18
  end

  it 'should advance cursor to block bottom if next paragraph does not fit and cursor is above block bottom' do
    pdf_theme[:role_outline_border_width] = 0.5
    pdf_theme[:role_outline_border_color] = '0000EE'
    input = <<~EOS
    image::rect.png[pdfwidth=110.6pt,float=left]

    #{lorem_ipsum '2-sentences-1-paragraph'}

    [.outline]#fin#.
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    expected_y = image[:y] - image[:height] - float_gap_b
    rects = (to_pdf input, pdf_theme: pdf_theme, analyze: :rect).rectangles
    actual_y = rects[0].yield_self {|it| it[:point][1] + it[:height] }
    (expect actual_y).to (be_within 1).of expected_y # off by top padding of prose
  end

  it 'should end float box if inked text depletes float box' do
    input = <<~EOS
    image::rect.png[pdfwidth=1.2in,float=left]

    #{lorem_ipsum '2-sentences-1-paragraph'}

    after

    after that
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    last_text_in_float_box = (pdf.find_text x: (image[:x] + image[:width] + float_gap_s))[-1]
    expected_gap = (pdf.text[-2][:y] - pdf.text[-1][:y]).round 5
    (expect (last_text_in_float_box[:y] - pdf.text[-2][:y]).round 5).to eql expected_gap
  end

  it 'should leave no less than bottom gap below image' do
    pdf_theme[:role_outline_border_width] = 0.5
    pdf_theme[:role_outline_border_color] = '0000EE'
    [[116.5, 6], [117, 22]].each do |pdfwidth, expected_gap|
      input = <<~EOS
      image::rect.png[pdfwidth=#{pdfwidth}pt,float=left]

      #{(lorem_ipsum '4-sentences-1-paragraph').sub 'lobortis', '[.outline]#lobortis#'}
      EOS

      image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
      rects = (to_pdf input, pdf_theme: pdf_theme, analyze: :rect).rectangles
      first_line_below_float_top = rects[0].yield_self {|it| (it[:point][1] + it[:height]).round 5 }
      actual_gap = image[:y] - image[:height] - first_line_below_float_top
      (expect actual_gap).to be > 6
      (expect actual_gap).to (be_within 1).of expected_gap
    end
  end

  it 'should allow paragraph that starts in float box to extend to next page' do
    with_content_spacer 10, 596 do |spacer_path|
      input = <<~EOS
      image::#{spacer_path}[]

      image::rect.png[pdfwidth=2in,float=left]

      #{lorem_ipsum '4-sentences-1-paragraph'}

      <<<

      at top
      EOS

      image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      p1_fragments = pdf.find_text page_number: 1
      (expect p1_fragments).not_to be_empty
      p1_fragments.each do |fragment|
        (expect fragment[:x]).to eql image[:x] + image[:width] + float_gap_s
      end
      p2_fragments = (pdf.find_text page_number: 2).uniq {|it| it[:y] }
      (expect p2_fragments).not_to be_empty
      p2_fragments.each do |fragment|
        (expect fragment[:x]).to eql page_margin
      end
      (expect p2_fragments[0][:y]).to eql (pdf.find_text page_number: 3)[0][:y]
    end
  end

  it 'should run float box to bottom of page if taller than remaining space on page' do
    with_content_spacer 10, 605 do |spacer_path|
      input = <<~EOS
      image::#{spacer_path}[]

      image::rect.png[pdfwidth=2in,float=left]

      #{lorem_ipsum '4-sentences-1-paragraph'}

      <<<

      at top
      EOS

      image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      p1_fragments = pdf.find_text page_number: 1
      (expect p1_fragments).not_to be_empty
      p1_fragments.each do |fragment|
        (expect fragment[:x]).to eql image[:x] + image[:width] + float_gap_s
      end
      p2_fragments = (pdf.find_text page_number: 2).uniq {|it| it[:y] }
      (expect p2_fragments).not_to be_empty
      p2_fragments.each do |fragment|
        (expect fragment[:x]).to eql page_margin
      end
      (expect p2_fragments[0][:y]).to eql (pdf.find_text page_number: 3)[0][:y]
    end
  end

  it 'should not continue float box if bottom margin of last paragraph starts new page' do
    with_content_spacer 10, 630 do |spacer_path|
      input = <<~EOS
      image::#{spacer_path}[]

      image::rect.png[pdfwidth=1.5in,float=left]

      #{lorem_ipsum '2-sentences-2-paragraphs'}

      at top
      EOS

      image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      expected_wrap_margin = image[:x] + image[:width] + float_gap_s
      p1_fragments = pdf.find_text page_number: 1
      (expect p1_fragments).not_to be_empty
      p1_fragments.each {|fragment| (expect fragment[:x]).to eql expected_wrap_margin }
      at_top_text = pdf.find_unique_text 'at top'
      (expect at_top_text[:page_number]).to eql 2
      (expect at_top_text[:x]).to eql page_margin
      (expect at_top_text).to eql (pdf.find_text page_number: 2)[0]
    end
  end

  it 'should float image inside a delimited block' do
    input = <<~EOS
    ****
    image::rect.png[pdfwidth=3in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    ****
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    (expect image[:x]).to eql page_margin + 15
    text_left_boundary = image[:x] + image[:width] + float_gap_s
    fragments = pdf.text
    first_line_text = fragments[0]
    (expect first_line_text[:x]).to eql text_left_boundary
    last_line_text = fragments[-1]
    (expect last_line_text[:x]).to eql page_margin + 15
  end

  it 'should support multiple image floats in same document', visual: true do
    input = <<~EOS
    Start.

    image::rect.png[pdfwidth=2.5in,float=left]

    #{lorem_ipsum '4-sentences-2-paragraphs'}

    .Image description
    image::rect.png[pdfwidth=50%,float=right]

    #{lorem_ipsum '4-sentences-2-paragraphs'}

    [cols=1;3]
    |===
    |normal cell
    a|
    #{lorem_ipsum '1-sentence'}

    image::rect.png[pdfwidth=50%,float=right]

    #{lorem_ipsum '2-sentences-1-paragraph'}

    #{lorem_ipsum '1-sentence'}
    |===

    fin.
    EOS

    to_file = to_pdf_file input, 'image-float.pdf', pdf_theme: pdf_theme
    (expect to_file).to visually_match 'image-float.pdf'
  end

  it 'should not add bottom margin to image with float inside enclosure when wrapped text is shorter than float box' do
    pdf_theme.update \
      sidebar_border_radius: 0,
      sidebar_border_width: [0.5, 0],
      sidebar_border_color: '0000EE',
      sidebar_background_color: 'transparent'
    input = <<~EOS
    ****
    image::rect.png[pdfwidth=3in,float=right]

    #{lorem_ipsum '2-sentences-1-paragraph'}
    ****
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    top_padding = lines[0][:from][:y] - image[:y]
    bottom_padding = (image[:y] - image[:height]) - lines[1][:from][:y]
    (expect top_padding).to eql 12.0
    (expect bottom_padding).to eql 12.0
  end

  it 'should not add bottom margin to paragraph that wraps around image float inside enclosure' do
    pdf_theme.update \
      sidebar_border_radius: 0,
      sidebar_border_width: [0.5, 0],
      sidebar_border_color: '0000EE',
      sidebar_background_color: 'transparent'
    input = <<~EOS
    ****
    image::rect.png[pdfwidth=3in,float=right]

    #{lorem_ipsum '4-sentences-2-paragraphs'}
    ****
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    last_text = pdf.text[-1]
    (expect (last_text[:y] - lines[1][:from][:y]).round 5).to eql 15.816
  end

  it 'should not add bottom margin to paragraph that extends past bottom of image float inside enclosure' do
    pdf_theme.update \
      sidebar_border_radius: 0,
      sidebar_border_width: [0.5, 0],
      sidebar_border_color: '0000EE',
      sidebar_background_color: 'transparent'
    input = <<~EOS
    ****
    image::rect.png[pdfwidth=2.25in,float=right]

    #{lorem_ipsum '2-paragraphs'}
    ****
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
    last_text = pdf.text[-1]
    (expect (last_text[:y] - lines[1][:from][:y]).round 5).to eql 15.816
  end

  it 'should not process paragraph preceded by paragraph without an active float box' do
    input = <<~'EOS'
    paragraph

    another paragraph
    EOS

    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    pdf.text.each {|fragment| (expect fragment[:x]).to eql page_margin }
  end

  it 'should not process paragraph preceded by image without float attribute' do
    input = <<~'EOS'
    image::rect.png[pdfwidth=3in]

    paragraph
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    para_fragment = pdf.text[0]
    (expect para_fragment[:x]).to eql page_margin
    compiled_pdf_theme = build_pdf_theme pdf_theme
    expected_top = image[:y] - image[:height] - compiled_pdf_theme.block_margin_bottom
    (expect para_fragment[:y] + para_fragment[:font_size]).to be < expected_top
  end

  it 'should not process paragraph preceded by image with float attribute that spans width of content area' do
    input = <<~EOS
    image::rect.png[pdfwidth=100%,float=left]

    #{lorem_ipsum '1-sentence'}
    EOS

    image = (to_pdf input, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
    para_fragment = pdf.text[0]
    (expect para_fragment[:x]).to eql page_margin
    compiled_pdf_theme = build_pdf_theme pdf_theme
    expected_top = image[:y] - image[:height] - compiled_pdf_theme.block_margin_bottom
    (expect para_fragment[:y] + para_fragment[:font_size]).to be < expected_top
  end

  it 'should allow extended converter to enlist other blocks to wrap around float' do
    source_file = doc_file 'modules/extend/examples/pdf-converter-code-float-wrapping.rb'
    source_lines = (File.readlines source_file).select {|l| l == ?\n || (l.start_with? ' ') }
    ext_class = create_class Asciidoctor::Converter.for 'pdf'
    backend = %(pdf#{ext_class.object_id})
    source_lines[0] = %(  register_for '#{backend}'\n)
    ext_class.class_eval source_lines.join, source_file
    input = <<~EOS
    image::rect.png[pdfwidth=50%,float=left]

    #{lorem_ipsum '1-sentence'}

    ----
    code
    here
    ----

    #{lorem_ipsum '1-sentence'}
    EOS

    image = (to_pdf input, backend: backend, pdf_theme: pdf_theme, analyze: :image).images[0]
    pdf = to_pdf input, backend: backend, pdf_theme: pdf_theme, analyze: true

    text_left_boundary = image[:x] + image[:width] + float_gap_s
    lorem_text = pdf.find_text %r/^Lorem/
    (expect lorem_text).to have_size 2
    (expect lorem_text[0][:x]).to eql text_left_boundary
    (expect lorem_text[1][:x]).to eql lorem_text[0][:x]
    (expect (pdf.find_unique_text 'code')[:x]).to be > text_left_boundary
  end

  it 'should end float box and advance cursor to bottom if next paragraph is outside float group' do
    input = <<~EOS
    [.float-group]
    --
    image::rect.png[pdfwidth=110.6pt,float=left]

    #{lorem_ipsum '1-sentence'}
    --

    outside
    EOS

    image = (to_pdf input, analyze: :image).images[0]
    image_bottom = image[:y] - image[:height]
    pdf = to_pdf input, analyze: true
    text_inside = pdf.text[0]
    text_outside = pdf.find_unique_text 'outside'
    (expect text_outside[:x]).to eql image[:x]
    (expect text_inside[:x]).to be > text_outside[:x]
    (expect text_outside[:y]).to be < image_bottom
  end

  it 'should end float box and advance cursor to bottom if next paragraph is outside open block' do
    input = <<~EOS
    --
    image::rect.png[pdfwidth=110.6pt,float=left]

    #{lorem_ipsum '1-sentence'}
    --

    outside
    EOS

    image = (to_pdf input, analyze: :image).images[0]
    image_bottom = image[:y] - image[:height]
    pdf = to_pdf input, analyze: true
    text_inside = pdf.text[0]
    text_outside = pdf.find_unique_text 'outside'
    (expect text_outside[:x]).to eql text_inside[:x]
    (expect image[:x]).to be < text_outside[:x]
    (expect text_outside[:y]).to be > image_bottom
  end
end
