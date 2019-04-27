require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Running Content' do
  it 'should add running footer showing virtual page number starting at body by default' do
    pdf = to_pdf <<~'EOS', attributes: {}, analyze: :text
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

    (expect pdf.pages.size).to eql 5
    page_numbers_text = pdf.text.inject({}) do |accum, candidate|
      accum[candidate[:string]] = candidate if /^\d+$/.match? candidate[:string]
      accum
    end
    expected_page_numbers = %w(1 2 3 4)
    expected_x_positions = [541.009, 49.24]
    (expect page_numbers_text.size).to eql expected_page_numbers.size
    expected_page_numbers.each do |page_number|
      page_number_text = page_numbers_text[page_number]
      (expect page_number_text[:page_number]).to eql page_number.to_i + 1
      (expect page_number_text[:x]).to eql expected_x_positions[page_number.to_i.odd? ? 0 : 1]
      (expect page_number_text[:y]).to eql 14.388
      (expect page_number_text[:font_size]).to eql 9
    end
  end

  it 'should not add running footer if nofooter attribute is set' do
    pdf = to_pdf <<~'EOS', attributes: 'nofooter', analyze: :text
    = Document Title
    :doctype: book

    body
    EOS

    page_numbers_text = pdf.text.select {|candidate| /^\d+$/.match? candidate[:string] }
    (expect page_numbers_text).to be_empty
  end

  it 'should start running content at title page if running_content_start_at key is set to title in theme' do
    theme_overrides = { running_content_start_at: 'title' }

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: :text
    = Document Title
    :doctype: book
    :toc:

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pdf.text.reduce({}) {|accum, text|
      (accum[text[:page_number]] ||= []) << text
      accum
    }.each do |page_number, texts|
      last_text = texts[-1]
      (expect last_text).not_to be_nil
      (expect page_number.to_s).to eql last_text[:string]
      (expect last_text[:y]).to eql 14.388
    end
  end

  it 'should start running content at toc page if running_content_start_at key is set to toc in theme' do
    theme_overrides = { running_content_start_at: 'toc' }

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: :text
    = Document Title
    :doctype: book
    :toc:

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pdf.text.reduce({}) {|accum, text|
      (accum[text[:page_number]] ||= []) << text
      accum
    }.each do |page_number, texts|
      if page_number == 1
        (expect texts.size).to eql 1
      else
        last_text = texts[-1]
        (expect last_text).not_to be_nil
        (expect page_number.pred.to_s).to eql last_text[:string]
        (expect last_text[:y]).to eql 14.388
      end
    end
  end

  it 'should start running content at body if running_content_start_at key is set to toc in theme and toc is disabled' do
    theme_overrides = { running_content_start_at: 'toc' }

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: :text
    = Document Title
    :doctype: book

    == First Chapter

    == Second Chapter

    == Third Chapter
    EOS

    pdf.text.reduce({}) {|accum, text|
      (accum[text[:page_number]] ||= []) << text
      accum
    }.each do |page_number, texts|
      if page_number == 1
        (expect texts.size).to eql 1
      else
        last_text = texts[-1]
        (expect last_text).not_to be_nil
        (expect page_number.pred.to_s).to eql last_text[:string]
        (expect last_text[:y]).to eql 14.388
      end
    end
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

    pdf = to_pdf <<~'EOS', attributes: {}, theme_overrides: theme_overrides, analyze: :text
    = Document Title
    :doctype: book

    first page

    <<<

    second page
    EOS

    headers_text = pdf.text.select {|candidate| candidate[:string] == '(Document Title)' }
    expected_x_positions = [541.009, 49.24]
    expected_page_numbers = %w(1 2)
    (expect headers_text.size).to be expected_page_numbers.size
    expected_page_numbers.each_with_index do |page_number, idx|
      (expect headers_text[idx][:string]).to eql '(Document Title)'
      (expect headers_text[idx][:page_number]).to eql page_number.to_i + 1
      (expect headers_text[idx][:font_size]).to eql 9
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

    pdf = to_pdf <<~'EOS', attributes: 'noheader', analyze: :text
    = Document Title
    :doctype: book

    body
    EOS

    headers_text = pdf.text.select {|candidate| candidate[:string] == '(Document Title)' }
    (expect headers_text).to be_empty
  end
end
