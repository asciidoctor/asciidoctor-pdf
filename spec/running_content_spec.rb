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

    (expect pdf.pages.size).to eql 5
    page_number_texts = pdf.find_text %r/^\d+$/
    (expect page_number_texts.size).to eql expected_page_numbers.size
    page_number_texts.each_with_index do |page_number_text, idx|
      (expect page_number_text[:page_number]).to eql idx + 2
      (expect page_number_text[:x]).to eql expected_x_positions[idx.even? ? 0 : 1]
      (expect page_number_text[:y]).to eql 14.388
      (expect page_number_text[:font_size]).to eql 9
    end
  end

  it 'should not add running footer if nofooter attribute is set' do
    pdf = to_pdf <<~'EOS', attributes: 'nofooter', analyze: true
    = Document Title
    :doctype: book

    body
    EOS

    (expect pdf.find_text %r/^\d+$/).to be_empty
  end

  it 'should start running content at title page if running_content_start_at key is title' do
    theme_overrides = { running_content_start_at: 'title' }

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
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
    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: {}, analyze: true
    = Document Title

    first page

    <<<

    second page
    EOS

    p2_text = pdf.find_text page_number: 2
    (expect p2_text[1][:x]).to be > p2_text[0][:x]
    (expect p2_text[1][:string]).to eql '2'
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
    = Document Title
    :doctype: book

    first page

    <<<

    second page
    EOS

    expected_page_numbers = %w(1 2)

    header_texts = pdf.find_text '(Document Title)'
    (expect header_texts.size).to be expected_page_numbers.size
    expected_page_numbers.each_with_index do |page_number, idx|
      (expect header_texts[idx][:string]).to eql '(Document Title)'
      (expect header_texts[idx][:page_number]).to eql page_number.to_i + 1
      (expect header_texts[idx][:font_size]).to eql 9
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

    pdf = to_pdf <<~'EOS', attributes: 'noheader', theme_overrides: theme_overrides, analyze: true
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: true
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
end
