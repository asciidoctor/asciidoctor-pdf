require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Running Content' do
  it 'should add running footer showing virtual page number starting at body by default' do
    pdf = to_pdf <<~'EOS', attributes: {}, analyze: true
    = Document Title
    :doctype: book

    first page

    <<<

    second page

    <<<

    third page

    <<<

    fourth page
    EOS

    expected_page_numbers = %w(1 2 3 4)
    expected_x_positions = [541.009, 49.24]

    (expect pdf.pages).to have_size 5
    page_number_texts = pdf.find_text %r/^\d+$/
    (expect page_number_texts).to have_size expected_page_numbers.size
    page_number_texts.each_with_index do |page_number_text, idx|
      (expect page_number_text[:page_number]).to eql idx + 2
      (expect page_number_text[:x]).to eql expected_x_positions[idx.even? ? 0 : 1]
      (expect page_number_text[:y]).to eql 14.388
      (expect page_number_text[:font_size]).to eql 9
    end
  end

  it 'should not add running footer if nofooter attribute is set' do
    pdf = to_pdf <<~'EOS', attributes: { 'nofooter' => '' }, analyze: true
    = Document Title
    :doctype: book

    body
    EOS

    (expect pdf.find_text %r/^\d+$/).to be_empty
  end

  it 'should start running content at title page if running_content_start_at key is title' do
    theme_overrides = { running_content_start_at: 'title' }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book
    :toc:

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
      accum << (pdf.find_text page_number: page_number, y: 14.388)[-1][:string]
      accum
    end
    (expect pgnum_labels).to eq %w(i ii 1 2 3)
  end

  it 'should start running content at toc page if running_content_start_at key is toc' do
    theme_overrides = { running_content_start_at: 'toc' }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book
    :toc:

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
      accum << ((pdf.find_text page_number: page_number, y: 14.388)[-1] || {})[:string]
      accum
    end
    (expect pgnum_labels).to eq [nil, 'ii', '1', '2', '3']
  end

  it 'should start running content at body if running_content_start_at key is toc and toc is disabled' do
    theme_overrides = { running_content_start_at: 'toc' }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
      accum << ((pdf.find_text page_number: page_number, y: 14.388)[-1] || {})[:string]
      accum
    end
    (expect pgnum_labels).to eq [nil, '1', '2', '3']
  end

  it 'should start page numbering at title page if page_numbering_start_at is title' do
    theme_overrides = { page_numbering_start_at: 'title', running_content_start_at: 'title' }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book
    :toc:

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
      accum << (pdf.find_text page_number: page_number, y: 14.388)[-1][:string]
      accum
    end
    (expect pgnum_labels).to eq %w(1 2 3 4 5)
  end

  it 'should start page numbering at toc page if page_numbering_start_at is toc' do
    theme_overrides = { page_numbering_start_at: 'toc', running_content_start_at: 'title' }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book
    :toc:

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
      accum << (pdf.find_text page_number: page_number, y: 14.388)[-1][:string]
      accum
    end
    (expect pgnum_labels).to eq %w(i 1 2 3 4)
  end

  it 'should expand footer padding from single value' do
    pdf = to_pdf <<~'EOS', attributes: {}, analyze: true
    = Document Title

    first page

    <<<

    second page
    EOS

    p2_text = pdf.find_text page_number: 2
    (expect p2_text[1][:x]).to be > p2_text[0][:x]
    (expect p2_text[1][:string]).to eql '2'
  end

  it 'should place footer text correctly if page layout changes' do
    theme_overrides = {
      footer_padding: 0,
      footer_verso_left_content: 'verso',
      footer_verso_right_content: nil,
      footer_recto_left_content: 'recto',
      footer_recto_right_content: nil,
    }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    portrait

    [.landscape]
    <<<

    landscape

    [.portrait]

    portrait
    EOS

    (expect pdf.text.size).to eql 5
    pdf.text.each do |text|
      (expect text[:x]).to eql 48.24
    end
  end

  it 'should adjust dimensions of running content to fit page layout' do
    filler = lorem_ipsum '2-sentences-2-paragraphs'
    theme_overrides = {
      footer_recto_left_content: '{section-title}',
      footer_recto_right_content: '{page-number}',
      footer_verso_left_content: '{page-number}',
      footer_verso_right_content: '{section-title}',
    }

    to_file = to_pdf_file <<~EOS, 'running-content-alt-layouts.pdf', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides)
    = Alternating Page Layouts

    This document demonstrates that the running content is adjusted to fit the page layout as the page layout alternates.

    #{filler}

    [.landscape]
    <<<

    == Landscape Page

    #{filler}

    [.portrait]
    <<<

    == Portrait Page

    #{filler}
    EOS

    (expect to_file).to visually_match 'running-content-alt-layouts.pdf'
  end

  it 'should add running header starting at body if header key is set in theme' do
    theme_overrides = {
      header_font_size: 9,
      header_height: 30,
      header_line_height: 1,
      header_padding: [6, 1, 0, 1],
      header_recto_right_content: '({document-title})',
      header_verso_right_content: '({document-title})'
    }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book

    first page

    <<<

    second page
    EOS

    expected_page_numbers = %w(1 2)

    page_height = pdf.pages[0][:size][1]
    header_texts = pdf.find_text '(Document Title)'
    (expect header_texts).to have_size expected_page_numbers.size
    expected_page_numbers.each_with_index do |page_number, idx|
      (expect header_texts[idx][:string]).to eql '(Document Title)'
      (expect header_texts[idx][:page_number]).to eql page_number.to_i + 1
      (expect header_texts[idx][:font_size]).to eql 9
      (expect header_texts[idx][:y]).to be < page_height
    end
  end

  it 'should not add running header if noheader attribute is set' do
    theme_overrides = {
      header_font_size: 9,
      header_height: 30,
      header_line_height: 1,
      header_padding: [6, 1, 0, 1],
      header_recto_right_content: '({document-title})',
      header_verso_right_content: '({document-title})'
    }

    pdf = to_pdf <<~'EOS', attributes: { 'noheader' => '' }, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book

    body
    EOS

    (expect pdf.find_text '(Document Title)').to be_empty
  end

  it 'should expand header padding from single value' do
    theme_overrides = {
      header_font_size: 9,
      header_height: 30,
      header_line_height: 1,
      header_padding: 5,
      header_recto_right_content: '{page-number}',
      header_verso_left_content: '{page-number}'
    }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :nofooter:

    first page

    <<<

    second page
    EOS

    p2_text = pdf.find_text page_number: 2
    (expect p2_text[1][:x]).to be > p2_text[0][:x]
    (expect p2_text[1][:string]).to eql '2'
  end

  it 'should use doctitle, toc-title, and preface-title as chapter-title before first chapter' do
    theme_overrides = {
      running_content_start_at: 'title',
      page_numbering_start_at: 'title',
      footer_recto_right_content: '{chapter-title}',
      footer_verso_left_content: '{chapter-title}',
    }

    pdf = to_pdf <<~'EOS', attributes: {}, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
    = Document Title
    :doctype: book
    :toc:

    content

    == Chapter 1

    content
    EOS

    expected_running_content_by_page = { 1 => 'Document Title', 2 => 'Table of Contents', 3 => 'Preface', 4 => 'Chapter 1' }
    running_content_by_page = (pdf.find_text y: 14.388).reduce({}) {|accum, text| accum[text[:page_number]] = text[:string]; accum }
    (expect running_content_by_page).to eql expected_running_content_by_page
  end

  it 'should draw background color across whole periphery region', integration: true do
    pdf_theme = build_pdf_theme \
      header_background_color: '009246',
      header_border_width: 0,
      footer_background_color: 'CE2B37',
      footer_border_width: 0,
      header_height: 160,
      footer_height: 160,
      page_margin: [160, 48, 160, 48]

    to_file = to_pdf_file 'Hello world', 'running-content-background-colors.pdf', attributes: {}, pdf_theme: pdf_theme

    (expect to_file).to visually_match 'running-content-background-colors.pdf'
  end

  it 'should scale image up to width when fit=contain', integration: true do
    %w(pdfwidth=99.76 fit=contain pdfwidth=0.5in,fit=contain pdfwidth=15in,fit=contain).each_with_index do |image_attrlist, idx|
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_recto_columns: '>40% =20% <40%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
        header_recto_right_content: 'text'

      to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-contain-#{idx}.pdf), pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image-fit.pdf'
    end
  end

  it 'should scale image down to width when fit=scale-down', integration: true do
    %w(pdfwidth=99.76 pdfwidth=15in,fit=scale-down).each_with_index do |image_attrlist, idx|
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_recto_columns: '>40% =20% <40%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
        header_recto_right_content: 'text'

      to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-scale-down-width-#{idx}.pdf), pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image-fit.pdf'
    end
  end

  it 'should scale image down to height when fit=scale-down', integration: true do
    %w(pdfwidth=30.60 fit=scale-down).each_with_index do |image_attrlist, idx|
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_recto_columns: '>40% =20% <40%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'tux.png'}[#{image_attrlist}]),
        header_recto_right_content: 'text'

      to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-scale-down-height-#{idx}.pdf), pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image-scale-down.pdf'
    end
  end

  it 'should not modify image dimensions when fit=scale-down if image already fits', integration: true do
    %w(pdfwidth=0.5in pdfwidth=0.5in,fit=scale-down).each_with_index do |image_attrlist, idx|
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_recto_columns: '>40% =20% <40%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
        header_recto_right_content: 'text'

      to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-#{idx}.pdf), pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image.pdf'
    end
  end

  it 'should warn and replace image with alt text if image is not found' do
    [true, false].each do |block|
      (expect {
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_recto_columns: '=100%',
          header_recto_center_content: %(image:#{block ? ':' : ''}no-such-image.png[alt text])

        pdf = to_pdf 'content', pdf_theme: pdf_theme, analyze: true

        alt_text = pdf.find_text '[alt text]'
        (expect alt_text).to have_size 1
      }).to log_message severity: :WARN, message: %r(image to embed not found or not readable.*data/themes/no-such-image\.png$)
    end
  end
end
