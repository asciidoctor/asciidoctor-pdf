# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Running Content' do
  context 'Activation' do
    it 'should not attempt to add running content if document has no body' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      EOS

      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'Document Title'
    end

    it 'should add running content if document is empty (single blank page)' do
      pdf = to_pdf '', enable_footer: true, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql '1'
    end

    it 'should start adding running content to page after imported page' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      image::blue-letter.pdf[]

      first non-imported page
      EOS

      pages = pdf.pages
      (expect pages).to have_size 2
      (expect pdf.find_text page_number: 1).to be_empty
      p2_text = pdf.find_text page_number: 2
      (expect p2_text).to have_size 2
      (expect p2_text[0][:string]).to eql 'first non-imported page'
      (expect p2_text[0][:order]).to be 1
      (expect p2_text[1][:string]).to eql '2'
      (expect p2_text[1][:order]).to be 2
    end

    it 'should not add running content if all pages are imported' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      image::red-green-blue.pdf[page=1]

      image::red-green-blue.pdf[page=2]

      image::red-green-blue.pdf[page=3]
      EOS

      pages = pdf.pages
      (expect pages).to have_size 3
      (expect pdf.text).to be_empty
    end
  end

  context 'Footer' do
    it 'should add running footer showing virtual page number starting at body by default' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
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
        (expect page_number_text[:y]).to eql 14.263
        (expect page_number_text[:font_size]).to be 9
      end
    end

    it 'should use single column that spans width of page if columns value is empty' do
      pdf_theme = {
        footer_columns: '',
        footer_recto_center_content: (expected_text = 'This text is aligned to the left and spans the width of the page.'),
      }
      pdf = to_pdf 'body', enable_footer: true, pdf_theme: pdf_theme, analyze: true

      footer_texts = pdf.find_text font_size: 9
      (expect footer_texts).to have_size 1
      (expect footer_texts[0][:string]).to eql expected_text
    end

    it 'should allow values in columns spec to be comma-separated' do
      pdf_theme = {
        footer_columns: '<25%, =50%, >25%',
        footer_padding: 0,
        footer_recto_left_content: 'left',
        footer_recto_center_content: 'center',
        footer_recto_right_content: 'right',
      }
      pdf = to_pdf 'body', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      midpoint = (get_page_size pdf)[0] * 0.5
      footer_texts = pdf.find_text font_size: 9
      (expect footer_texts).to have_size 3
      (expect footer_texts[0][:x]).to be < midpoint
      (expect footer_texts[1][:x]).to be < midpoint
      (expect footer_texts[1][:x] + footer_texts[1][:width]).to be > midpoint
      (expect footer_texts[2][:x]).to be > midpoint
    end

    it 'should hide page number if pagenums attribute is unset in document' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :!pagenums:

      first page

      <<<

      second page
      EOS

      (expect pdf.find_text '1').to be_empty
      (expect pdf.find_text '2').to be_empty
    end

    it 'should hide page number if pagenums attribute is unset via API' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'pagenums' => nil }, enable_footer: true, analyze: true
      = Document Title
      :doctype: book

      first page

      <<<

      second page
      EOS

      (expect pdf.find_text '1').to be_empty
      (expect pdf.find_text '2').to be_empty
    end

    it 'should drop line with page-number reference if pagenums attribute is unset' do
      pdf_theme = {
        footer_recto_right_content: %({page-number} hide me +\nrecto right),
        footer_verso_left_content: %({page-number} hide me +\nverso left),
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :!pagenums:

      first page

      <<<

      second page
      EOS

      (expect pdf.find_text %r/\d+ hide me/).to be_empty
      (expect pdf.find_text %r/recto right/, page_number: 2).to have_size 1
      (expect pdf.find_text %r/verso left/, page_number: 3).to have_size 1
    end

    it 'should not add running footer if nofooter attribute is set' do
      pdf = to_pdf <<~'EOS', enable_footer: false, analyze: true
      = Document Title
      :nofooter:
      :doctype: book

      body
      EOS

      (expect pdf.find_text %r/^\d+$/).to be_empty
    end

    it 'should not add running footer if height is nil' do
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: { footer_height: nil }, analyze: true
      = Document Title
      :doctype: book

      body
      EOS

      (expect pdf.find_text %r/^\d+$/).to be_empty
    end

    it 'should add footer if theme extends base and footer height is set' do
      pdf_theme = {
        extends: 'base',
        footer_height: 36,
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      == Beginning

      == End
      EOS

      pagenum1_text = (pdf.find_text '1')[0]
      pagenum2_text = (pdf.find_text '2')[0]
      (expect pagenum1_text).not_to be_nil
      (expect pagenum1_text[:page_number]).to be 2
      (expect pagenum2_text).not_to be_nil
      (expect pagenum2_text[:page_number]).to be 3
      (expect pagenum1_text[:x]).to be > pagenum2_text[:x]
    end
  end

  context 'Header' do
    it 'should add running header starting at body if header key is set in theme' do
      theme_overrides = {
        header_font_size: 9,
        header_height: 30,
        header_line_height: 1,
        header_padding: [6, 1, 0, 1],
        header_recto_right_content: '({document-title})',
        header_verso_right_content: '({document-title})',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
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
        (expect header_texts[idx][:font_size]).to be 9
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
        header_verso_right_content: '({document-title})',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, attribute_overrides: { 'noheader' => '' }, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book

      body
      EOS

      (expect pdf.find_text '(Document Title)').to be_empty
    end
  end

  context 'Start at' do
    it 'should start running content at body by default' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      (expect pdf.pages).to have_size 5
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, '1', '2', '3']
    end

    it 'should start running content at body when start at is after-toc and toc is not enabled' do
      pdf = to_pdf <<~'EOS', pdf_theme: { running_content_start_at: 'after-toc' }, enable_footer: true, analyze: true
      = Document Title
      :doctype: book

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      (expect pdf.pages).to have_size 4
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, '1', '2', '3']
    end

    it 'should start running content at body when start at is after-toc and toc is enabled with default placement' do
      pdf = to_pdf <<~'EOS', pdf_theme: { running_content_start_at: 'after-toc' }, enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      (expect pdf.pages).to have_size 5
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, '1', '2', '3']
    end

    it 'should start running content after toc in body of book when start at is after-toc and macro toc is used' do
      filler = (1..20).map {|it| %(== #{['Filler'] * 20 * ' '} #{it}\n\ncontent) }.join %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: { running_content_start_at: 'after-toc' }, enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :toc: macro

      == First Chapter

      toc::[]

      == Second Chapter

      == Third Chapter

      #{filler}
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels.slice 0, 5).to eql [nil, nil, nil, nil, '4']
    end

    it 'should start running content after toc in body of article with title page when start at is after-toc and macro toc is used' do
      filler = (1..20).map {|it| %(== #{['Filler'] * 20 * ' '} #{it}\n\ncontent) }.join %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: { running_content_start_at: 'after-toc' }, enable_footer: true, analyze: true
      = Document Title
      :title-page:
      :toc: macro

      == First Section

      toc::[]

      == Second Section

      == Third Section

      #{filler}
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels.slice 0, 5).to eql [nil, nil, nil, '3', '4']
    end

    it 'should start running content and page numbering after toc in body when both start at keys are after-toc and macro toc is used' do
      filler = (1..20).map {|it| %(== #{['Filler'] * 20 * ' '} #{it}\n\ncontent) }.join %(\n\n)
      pdf = to_pdf <<~EOS, pdf_theme: { running_content_start_at: 'after-toc', page_numbering_start_at: 'after-toc' }, enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :toc: macro

      == First Chapter

      toc::[]

      == Second Chapter

      == Third Chapter

      #{filler}
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels.slice 0, 5).to eql [nil, nil, nil, nil, '1']
    end

    it 'should start running content at title page if running_content_start_at key is title' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(i ii 1 2 3)
    end

    it 'should start running content at title page if running_content_start_at key is title and document has front cover' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:
      :front-cover-image: image:cover.jpg[]

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      (expect pdf.find_text page_number: 1).to be_empty
      pgnum_labels = (2.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(ii iii 1 2 3)
    end

    it 'should start running content at toc page if running_content_start_at key is title and title page is disabled' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(i 1 2 3)
    end

    it 'should start running content at body if running_content_start_at key is title and title page and toc are disabled' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(1 2 3)
    end

    it 'should start running content at toc page if running_content_start_at key is toc' do
      theme_overrides = { running_content_start_at: 'toc' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, 'ii', '1', '2', '3']
    end

    it 'should start running content at toc page if running_content_start_at key is toc and title page is disabled' do
      theme_overrides = { running_content_start_at: 'toc' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql %w(i 1 2 3)
    end

    it 'should start running content at body if running_content_start_at key is toc and toc is disabled' do
      theme_overrides = { running_content_start_at: 'toc' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, '1', '2', '3']
    end

    it 'should start running content at body if running_content_start_at key is after-toc and toc is disabled' do
      theme_overrides = { running_content_start_at: 'after-toc' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, '1', '2', '3']
    end

    it 'should start running content at specified page of body of book if running_content_start_at is an integer' do
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: { running_content_start_at: 3 }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Dedication

      To the only person who gets me.

      == Acknowledgements

      Thanks all to all who made this possible!

      == Chapter One

      content
      EOS

      (expect pdf.pages).to have_size 5
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, nil, nil, '3']
    end

    it 'should start running content at specified page of document with no title page if running_content_start_at is an integer' do
      pdf_theme = {
        running_content_start_at: 3,
        footer_font_color: '0000FF',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Article Title

      page one

      <<<

      page two

      <<<

      page three
      EOS

      (expect pdf.pages).to have_size 3
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, font_color: '0000FF')[0] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, '3']
    end

    it 'should start page numbering at body by default' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Dedication

      To the only person who gets me.

      == Acknowledgements

      Thanks all to all who made this possible!

      == Chapter One

      content
      EOS

      (expect pdf.pages).to have_size 5
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, '1', '2', '3']
    end

    it 'should start page numbering at body when start at is after-toc and toc is enabled' do
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: { page_numbering_start_at: 'after-toc' }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Dedication

      To the only person who gets me.

      == Acknowledgements

      Thanks all to all who made this possible!

      == Chapter One

      content
      EOS

      (expect pdf.pages).to have_size 5
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, '1', '2', '3']
    end

    it 'should start page numbering at body when start at is after-toc and toc is not enabled' do
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: { page_numbering_start_at: 'after-toc' }, analyze: true
      = Book Title
      :doctype: book

      == Dedication

      To the only person who gets me.

      == Acknowledgements

      Thanks all to all who made this possible!

      == Chapter One

      content
      EOS

      (expect pdf.pages).to have_size 4
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, '1', '2', '3']
    end

    it 'should start page numbering after toc in body of book when start at is after-toc and toc macro is used' do
      filler = (1..20).map {|it| %(== #{['Filler'] * 20 * ' '} #{it}\n\ncontent) }.join %(\n\n)
      pdf = to_pdf <<~EOS, enable_footer: true, pdf_theme: { page_numbering_start_at: 'after-toc' }, analyze: true
      = Book Title
      :doctype: book
      :toc: macro

      == Dedication

      To the only person who gets me.

      toc::[]

      == Acknowledgements

      Thanks all to all who made this possible!

      == Chapter One

      content

      #{filler}
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels.slice 0, 5).to eql [nil, 'ii', 'iii', 'iv', '1']
    end

    it 'should start page numbering after toc in body of article with title page when start at is after-toc and toc macro is used' do
      filler = (1..20).map {|it| %(== #{['Filler'] * 20 * ' '} #{it}\n\ncontent) }.join %(\n\n)
      pdf = to_pdf <<~EOS, enable_footer: true, pdf_theme: { page_numbering_start_at: 'after-toc' }, analyze: true
      = Document Title
      :title-page:
      :toc: macro

      == Dedication

      To the only person who gets me.

      toc::[]

      == Acknowledgements

      Thanks all to all who made this possible!

      == Section One

      content

      #{filler}
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels.slice 0, 5).to eql [nil, 'ii', 'iii', '1', '2']
    end

    it 'should start page numbering and running content at specified page of body' do
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: { page_numbering_start_at: 3, running_content_start_at: 3 }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Dedication

      To the only person who gets me.

      == Acknowledgements

      Thanks all to all who made this possible!

      == Chapter One

      content
      EOS

      (expect pdf.pages).to have_size 5
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, nil, nil, '1']
    end

    it 'should start page numbering and running content at specified page of document with no title page' do
      pdf_theme = {
        running_content_start_at: 3,
        page_numbering_start_at: 3,
        footer_font_color: '0000FF',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Article Title

      page one

      <<<

      page two

      <<<

      page three
      EOS

      (expect pdf.pages).to have_size 3
      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << ((pdf.find_text page_number: page_number, font_color: '0000FF')[0] || {})[:string]
      end
      (expect pgnum_labels).to eql [nil, nil, '1']
    end
  end

  context 'Page numbering' do
    it 'should start page numbering at body if title page and toc are disabled' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :notitle:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(1 2 3)
    end

    it 'should start page numbering at body if title page is disabled and toc is enabled' do
      pdf_theme = { running_content_start_at: 'toc' }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(i 1 2 3)
    end

    it 'should start page numbering at cover page of article if page_numbering_start_at is cover' do
      theme_overrides = { page_numbering_start_at: 'cover' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides)
      = Document Title
      :front-cover-image: image:tux.png[]

      == First Section

      == Second Section

      == Third Section
      EOS

      page_labels = get_page_labels pdf
      (expect page_labels).to eql %w(1 2)
    end

    it 'should start page numbering at cover page of book if page_numbering_start_at is cover' do
      theme_overrides = { page_numbering_start_at: 'cover' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides)
      = Document Title
      :doctype: book
      :front-cover-image: image:tux.png[]
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      page_labels = get_page_labels pdf
      (expect page_labels).to eql %w(1 2 3 4 5 6)
    end

    it 'should start page numbering at title page of book if page_numbering_start_at is cover and document has no cover' do
      theme_overrides = { page_numbering_start_at: 'cover' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides)
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      page_labels = get_page_labels pdf
      (expect page_labels).to eql %w(1 2 3 4 5)
    end

    it 'should start page numbering at body of article if page_numbering_start_at is cover and document has no cover' do
      theme_overrides = { page_numbering_start_at: 'cover' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides)
      = Document Title

      == First Section

      == Second Section

      == Third Section
      EOS

      page_labels = get_page_labels pdf
      (expect page_labels).to eql %w(1)
    end

    it 'should start page numbering at title page if page_numbering_start_at is title' do
      theme_overrides = { page_numbering_start_at: 'title', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(1 2 3 4 5)
    end

    it 'should start page numbering at toc page if page_numbering_start_at is title and title page is disabled' do
      theme_overrides = { page_numbering_start_at: 'title', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(1 2 3 4)
    end

    it 'should start page numbering at body if page_numbering_start_at is title and title page and toc are disabled' do
      theme_overrides = { page_numbering_start_at: 'title', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(1 2 3)
    end

    it 'should start page numbering at toc page if page_numbering_start_at is toc' do
      theme_overrides = { page_numbering_start_at: 'toc', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(i 1 2 3 4)
    end

    it 'should start page numbering at toc page if page_numbering_start_at is toc and title page is disabled' do
      theme_overrides = { page_numbering_start_at: 'toc', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(1 2 3 4)
    end

    it 'should start page numbering at specified page of body of book if page_numbering_start_at is an integer' do
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: { running_content_start_at: 'title', page_numbering_start_at: 3 }, analyze: true
      = Book Title
      :doctype: book
      :toc:

      == Dedication

      To the only ((person)) who gets me.

      == Acknowledgements

      Thanks all to all who made this possible!

      == Chapter One

      content

      [index]
      == Index
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
      end
      (expect pgnum_labels).to eql %w(i ii iii iv 1 2)
      dedication_toc_line = (pdf.lines pdf.find_text page_number: 2).find {|it| it.start_with? 'Dedication' }
      (expect dedication_toc_line).to end_with 'iii'
      (expect pdf.lines pdf.find_text page_number: pdf.pages.size).to include 'person, iii'
    end

    it 'should start page numbering at specified page of document with no title page if page_numbering_start_at is an integer' do
      pdf_theme = {
        page_numbering_start_at: 3,
        footer_font_color: '0000FF',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Article Title

      page one

      <<<

      page two

      <<<

      page three
      EOS

      pgnum_labels = (1.upto pdf.pages.size).each_with_object [] do |page_number, accum|
        accum << (pdf.find_text page_number: page_number, font_color: '0000FF')[0][:string]
      end
      (expect pgnum_labels).to eql %w(i ii 1)
    end

    it 'should compute page-count attribute correctly when running content starts after page numbering' do
      pdf_theme = {
        page_numbering_start_at: 'toc',
        running_content_start_at: 'body',
        footer_recto_right_content: '{page-number} of {page-count}',
        footer_verso_left_content: '{page-number} of {page-count}',
        footer_font_color: 'AA0000',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :toc:

      == Beginning

      == End
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 2
      (expect footer_texts[0][:page_number]).to be 3
      (expect footer_texts[0][:string]).to eql '2 of 3'
      (expect footer_texts[1][:page_number]).to be 4
      (expect footer_texts[1][:string]).to eql '3 of 3'
    end

    it 'should compute page-count attribute correctly when page numbering starts after running content' do
      pdf_theme = {
        page_numbering_start_at: 'body',
        running_content_start_at: 'toc',
        footer_recto_right_content: '{page-number} of {page-count}',
        footer_verso_left_content: '{page-number} of {page-count}',
        footer_font_color: 'AA0000',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :toc:

      == Beginning

      == End
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 3
      (expect footer_texts[0][:page_number]).to be 2
      (expect footer_texts[0][:string]).to eql 'ii of 2'
      (expect footer_texts[1][:page_number]).to be 3
      (expect footer_texts[1][:string]).to eql '1 of 2'
      (expect footer_texts[2][:page_number]).to be 4
      (expect footer_texts[2][:string]).to eql '2 of 2'
    end
  end

  context 'Theming' do
    it 'should be able to set font styles per periphery and side in theme' do
      pdf_theme = build_pdf_theme \
        footer_font_size: 7.5,
        footer_recto_left_content: '{section-title}',
        footer_recto_left_font_style: 'bold',
        footer_recto_left_text_transform: 'lowercase',
        footer_recto_right_content: '{page-number}',
        footer_recto_right_font_color: '00ff00',
        footer_verso_left_content: '{page-number}',
        footer_verso_left_font_color: 'ff0000',
        footer_verso_right_content: '{section-title}',
        footer_verso_right_text_transform: 'uppercase'

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title

      Preamble text.

      <<<

      == Beginning

      <<<

      == Middle

      <<<

      == End
      EOS

      (expect pdf.find_text font_size: 7.5, page_number: 1, string: '1', font_color: '00FF00').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 2, string: 'BEGINNING').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 2, string: '2', font_color: 'FF0000').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 3, string: 'middle', font_name: 'NotoSerif-Bold').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 3, string: '3', font_color: '00FF00').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 4, string: 'END').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 4, string: '4', font_color: 'FF0000').to have_size 1
    end

    it 'should expand footer padding from single value' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title

      first page

      <<<

      second page
      EOS

      p2_text = pdf.find_text page_number: 2
      (expect p2_text[1][:x]).to be > p2_text[0][:x]
      (expect p2_text[1][:string]).to eql '2'
    end

    it 'should expand header padding from single value' do
      theme_overrides = {
        header_font_size: 9,
        header_height: 30,
        header_line_height: 1,
        header_padding: 5,
        header_recto_right_content: '{page-number}',
        header_verso_left_content: '{page-number}',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title

      first page

      <<<

      second page
      EOS

      p2_text = pdf.find_text page_number: 2
      (expect p2_text[1][:x]).to be > p2_text[0][:x]
      (expect p2_text[1][:string]).to eql '2'
    end

    it 'should coerce non-array value to a string' do
      theme_overrides = {
        header_font_size: 9,
        header_height: 30,
        header_line_height: 1,
        header_padding: 5,
        header_recto_right_content: 99,
        header_verso_left_content: 99,
      }

      pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title

      first page

      <<<

      second page
      EOS

      p2_text = pdf.find_text page_number: 2
      (expect p2_text[1][:x]).to be > p2_text[0][:x]
      (expect p2_text[1][:string]).to eql '99'
    end

    it 'should allow horizontal padding to be negative', visual: true do
      pdf_theme = {
        footer_font_color: '000000',
        footer_padding: [0, -48.24, 0, -48.24],
        footer_recto_left_content: 'text left',
        footer_recto_right_content: 'text right',
        footer_vertical_align: 'middle',
      }

      to_file = to_pdf_file <<~'EOS', 'running-content-negative-padding.pdf', pdf_theme: pdf_theme, enable_footer: true
      text left

      [.text-right]
      text right
      EOS

      (expect to_file).to visually_match 'running-content-negative-padding.pdf'
    end

    it 'should allow vertical alignment of content to be set in theme' do
      pdf_theme = {
        footer_font_color: '000000',
        footer_padding: 0,
        footer_height: 72,
        footer_line_height: 1,
        footer_font_size: 10,
        footer_recto_left_content: 'text left',
        footer_recto_right_content: 'text right',
      }

      # NOTE: the exact y position is affected by the font height and line metrics, so use a fuzzy check
      { 'top' => 72, 'middle' => 42, 'bottom' => 12, ['top', 10] => 62, ['bottom', -10] => 22 }.each do |valign, expected_y|
        pdf = to_pdf 'body', pdf_theme: (pdf_theme.merge footer_vertical_align: valign), enable_footer: true, analyze: true
        left_text = (pdf.find_text 'text left')[0]
        (expect left_text[:y] + left_text[:font_size]).to be_within(1).of(expected_y)
      end
    end

    it 'should coerce content value to string' do
      pdf = to_pdf 'body', enable_footer: true, attribute_overrides: { 'pdf-theme' => (fixture_file 'running-footer-coerce-content-theme.yml') }, analyze: true

      (expect pdf.find_text '1000').to have_size 1
      (expect pdf.find_text 'true').to have_size 1
    end

    it 'should not substitute escaped attribute reference in content' do
      pdf_theme = {
        footer_recto_right_content: '\{keepme}',
        footer_verso_left_content: '\{keepme}',
      }

      pdf = to_pdf 'body', enable_footer: true, pdf_theme: pdf_theme, analyze: true

      running_text = pdf.find_text '{keepme}'
      (expect running_text).to have_size 1
    end

    it 'should normalize newlines and whitespace' do
      pdf_theme = {
        footer_recto_right_content: %(He's  a  real  nowhere  man,\nMaking all his nowhere plans\tfor nobody.),
        footer_verso_left_content: %(He's  a  real  nowhere  man,\nMaking all his nowhere plans\tfor nobody.),
      }

      pdf = to_pdf 'body', enable_footer: true, pdf_theme: pdf_theme, analyze: true

      (expect pdf.lines.last).to eql %(He\u2019s a real nowhere man, Making all his nowhere plans for nobody.)
    end

    it 'should drop line in content with unresolved attribute reference' do
      pdf_theme = {
        footer_recto_right_content: %(keep\ndrop{bogus}\nme),
        footer_verso_left_content: %(keep\ndrop{bogus}\nme),
      }

      pdf = to_pdf 'body', enable_footer: true, pdf_theme: pdf_theme, analyze: true

      running_text = pdf.find_text %(keep me)
      (expect running_text).to have_size 1
    end

    it 'should not warn if attribute is missing in running content' do
      (expect do
        pdf_theme = {
          footer_recto_right_content: %(keep\ndrop{does-not-exist}\nattribute-missing={attribute-missing}),
          footer_verso_left_content: %(keep\ndrop{does-not-exist}\nattribute-missing={attribute-missing}),
        }

        doc = to_pdf 'body', attribute_overrides: { 'attribute-missing' => 'warn' }, enable_footer: true, pdf_theme: pdf_theme, to_file: (pdf_io = StringIO.new), analyze: :document

        (expect doc.attr 'attribute-missing').to eql 'warn'
        pdf = PDF::Reader.new pdf_io
        (expect (pdf.page 1).text).to include 'keep attribute-missing=skip'
      end).to not_log_message
    end

    it 'should parse running content as AsciiDoc' do
      pdf_theme = {
        footer_recto_right_content: 'footer: *bold* _italic_ `mono`',
        footer_verso_left_content: 'https://asciidoctor.org[Asciidoctor] AsciiDoc -> PDF',
      }
      input = <<~'EOS'
      page 1

      <<<

      page 2
      EOS

      pdf = to_pdf input, enable_footer: true, pdf_theme: pdf_theme, analyze: true

      footer_y = (pdf.find_text 'footer: ')[0][:y]
      bold_text = (pdf.find_text 'bold', page_number: 1, y: footer_y)[0]
      (expect bold_text).not_to be_nil
      italic_text = (pdf.find_text 'italic', page_number: 1, y: footer_y)[0]
      (expect italic_text).not_to be_nil
      mono_text = (pdf.find_text 'mono', page_number: 1, y: footer_y)[0]
      (expect mono_text).not_to be_nil
      link_text = (pdf.find_text 'Asciidoctor', page_number: 2, y: footer_y)[0]
      (expect link_text).not_to be_nil
      convert_text = (pdf.find_text %( AsciiDoc \u2192 PDF), page_number: 2, y: footer_y)[0]
      (expect convert_text).not_to be_nil

      pdf = to_pdf input, enable_footer: true, pdf_theme: pdf_theme
      annotations_p2 = get_annotations pdf, 2
      (expect annotations_p2).to have_size 1
      link_annotation = annotations_p2[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://asciidoctor.org'
    end

    it 'should process custom inline macros in content' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: 'offset:{page-number}[2]',
        footer_verso_left_content: 'offset:{page-number}[2]',
      }

      input = <<~'EOS'
      first

      <<<

      last
      EOS

      extension_registry = Asciidoctor::Extensions.create do
        inline_macro :offset do
          resolve_attributes '1:amount'
          process do |parent, target, attrs|
            create_inline parent, :quoted, (target.to_i + attrs['amount'].to_i)
          end
        end
      end

      pdf = to_pdf input, enable_footer: true, pdf_theme: pdf_theme, extension_registry: extension_registry, analyze: true

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 2
      (expect footer_texts[0][:page_number]).to be 1
      (expect footer_texts[0][:string]).to eql '3'
      (expect footer_texts[1][:page_number]).to be 2
      (expect footer_texts[1][:string]).to eql '4'
    end

    it 'should allow theme to control border style', visual: true do
      pdf_theme = {
        footer_border_width: 1,
        footer_border_style: 'dashed',
        footer_border_color: '000000',
      }

      to_file = to_pdf_file 'content', 'running-content-border-style.pdf', enable_footer: true, pdf_theme: pdf_theme, analyze: :line

      (expect to_file).to visually_match 'running-content-border-style.pdf'
    end

    it 'should not draw background color across whole periphery region', visual: true do
      pdf_theme = build_pdf_theme \
        header_background_color: '009246',
        header_border_width: 0,
        header_height: 160,
        footer_background_color: 'CE2B37',
        footer_border_width: 0,
        footer_height: 160,
        footer_padding: [6, 49, 0, 49],
        page_margin: [160, 48, 160, 48]

      to_file = to_pdf_file 'Hello world', 'running-content-background-color.pdf', enable_footer: true, pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-background-color.pdf'
    end

    it 'should not draw background color across whole periphery region if margin is 0', visual: true do
      pdf_theme = build_pdf_theme \
        header_background_color: '009246',
        header_border_width: 0,
        header_height: 160,
        header_margin: 0,
        header_content_margin: [0, 'inherit'],
        header_padding: [6, 1, 0, 1],
        footer_background_color: 'CE2B37',
        footer_border_width: 0,
        footer_height: 160,
        footer_padding: [6, 1, 0, 1],
        footer_margin: 0,
        footer_content_margin: [0, 'inherit'],
        page_margin: [160, 48, 160, 48]

      to_file = to_pdf_file 'Hello world', 'running-content-background-color-full.pdf', enable_footer: true, pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-background-color-full.pdf'
    end

    it 'should not draw background image across whole periphery region', visual: true do
      pdf_theme = build_pdf_theme \
        header_background_image: %(image:#{fixture_file 'header-bg-letter.svg'}[fit=contain]),
        header_border_width: 0,
        header_height: 30,
        header_padding: 0,
        header_recto_left_content: '{page-number}',
        footer_background_image: %(image:#{fixture_file 'footer-bg-letter.svg'}[fit=contain]),
        footer_border_width: 0,
        footer_height: 30,
        footer_padding: 0,
        footer_vertical_align: 'middle'

      to_file = to_pdf_file <<~'EOS', 'running-content-background-image.pdf', enable_footer: true, pdf_theme: pdf_theme
      :pdf-page-size: Letter

      Hello, World!
      EOS

      (expect to_file).to visually_match 'running-content-background-image.pdf'
    end

    it 'should not draw background image across whole periphery region if margin is 0', visual: true do
      pdf_theme = build_pdf_theme \
        header_background_image: %(image:#{fixture_file 'header-bg-letter.svg'}[fit=contain]),
        header_border_width: 0,
        header_height: 30,
        header_padding: 0,
        header_margin: 0,
        header_content_margin: [0, 'inherit'],
        header_recto_left_content: '{page-number}',
        footer_background_image: %(image:#{fixture_file 'footer-bg-letter.svg'}[fit=contain]),
        footer_border_width: 0,
        footer_height: 30,
        footer_padding: 0,
        footer_margin: 0,
        footer_content_margin: [0, 'inherit'],
        footer_vertical_align: 'middle'

      to_file = to_pdf_file <<~'EOS', 'running-content-background-image-full.pdf', enable_footer: true, pdf_theme: pdf_theme
      :pdf-page-size: Letter

      Hello, World!
      EOS

      (expect to_file).to visually_match 'running-content-background-image-full.pdf'
    end

    it 'should warn if background image cannot be resolved' do
      pdf_theme = build_pdf_theme \
        footer_background_image: 'no-such-image.png',
        footer_border_width: 0,
        footer_height: 30,
        footer_padding: 0,
        footer_vertical_align: 'middle'

      (expect do
        pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme

        Hello, World!
        EOS

        images = get_images pdf, 1
        (expect images).to be_empty
      end).to log_message severity: :WARN, message: %r(footer background image not found or readable.*data/themes/no-such-image\.png$)
    end

    it 'should compute boundary of background image per side if sides have different content width', visual: true do
      pdf_theme = {
        page_size: 'Letter',
        footer_background_image: %(image:#{fixture_file 'footer-bg-letter.svg'}[]),
        footer_columns: '=100%',
        footer_border_width: 0,
        footer_margin: 0,
        footer_recto_center_content: '',
        footer_verso_margin: [0, 'inherit'],
        footer_verso_center_content: '',
      }

      to_file = to_pdf_file <<~'EOS', 'running-content-background-image-per-side.pdf', pdf_theme: pdf_theme, enable_footer: true
      recto

      <<<

      verso
      EOS

      (expect to_file).to visually_match 'running-content-background-image-per-side.pdf'
    end

    it 'should be able to reference page layout in background image path', visual: true do
      pdf_theme = { footer_background_image: 'image:{imagesdir}/square-{page-layout}.svg[]' }

      to_file = to_pdf_file <<~'EOS', 'running-content-background-image-per-layout.pdf', pdf_theme: pdf_theme, enable_footer: true
      page 1

      [.landscape]
      <<<

      page 2

      [.portrait]
      <<<

      page 3
      EOS
      (expect to_file).to visually_match 'running-content-background-image-per-layout.pdf'
    end

    it 'should allow theme to control side margin of running content using fixed value' do
      pdf_theme = {
        header_height: 36,
        header_padding: 0,
        header_recto_margin: [0, 10],
        header_recto_content_margin: 0,
        header_recto_left_content: 'H',
        header_verso_margin: [0, 10],
        header_verso_content_margin: 0,
        header_verso_right_content: 'H',
        footer_padding: 0,
        footer_recto_margin: [0, 10],
        footer_recto_content_margin: 0,
        footer_recto_left_content: 'F',
        footer_verso_margin: [0, 10],
        footer_verso_content_margin: 0,
        footer_verso_right_content: 'F',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      page one

      <<<

      page two
      EOS

      page_width = (get_page_size pdf)[0]
      p1_header_text = (pdf.find_text 'H', page_number: 1)[0]
      p1_footer_text = (pdf.find_text 'F', page_number: 1)[0]
      (expect p1_header_text[:x].round).to eql 10
      (expect p1_footer_text[:x].round).to eql 10
      p2_header_text = (pdf.find_text 'H', page_number: 2)[0]
      p2_footer_text = (pdf.find_text 'F', page_number: 2)[0]
      (expect (page_width - p2_header_text[:x] - p2_header_text[:width]).round).to eql 10
      (expect (page_width - p2_footer_text[:x] - p2_footer_text[:width]).round).to eql 10
    end

    it 'should allow theme to control side margin of running content using inherited value' do
      pdf_theme = {
        header_height: 36,
        header_padding: 0,
        header_recto_margin: [0, 'inherit'],
        header_recto_left_content: 'H',
        header_verso_margin: [0, 'inherit'],
        header_verso_right_content: 'H',
        footer_padding: 0,
        footer_recto_margin: [0, 'inherit'],
        footer_recto_left_content: 'F',
        footer_verso_margin: [0, 'inherit'],
        footer_verso_right_content: 'F',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      page one

      <<<

      page two
      EOS

      page_width = (get_page_size pdf)[0]
      p1_header_text = (pdf.find_text 'H', page_number: 1)[0]
      p1_footer_text = (pdf.find_text 'F', page_number: 1)[0]
      (expect p1_header_text[:x].round).to eql 48
      (expect p1_footer_text[:x].round).to eql 48
      p2_header_text = (pdf.find_text 'H', page_number: 2)[0]
      p2_footer_text = (pdf.find_text 'F', page_number: 2)[0]
      (expect (page_width - p2_header_text[:x] - p2_header_text[:width]).round).to eql 48
      (expect (page_width - p2_footer_text[:x] - p2_footer_text[:width]).round).to eql 48
    end

    it 'should allow theme to control side content margin of running content using fixed value' do
      pdf_theme = {
        header_height: 36,
        header_padding: 0,
        header_recto_margin: [0, 10],
        header_recto_content_margin: [0, 40],
        header_recto_left_content: 'H',
        header_verso_margin: [0, 10],
        header_verso_content_margin: [0, 40],
        header_verso_right_content: 'H',
        footer_padding: 0,
        footer_recto_margin: [0, 10],
        footer_recto_content_margin: [0, 40],
        footer_recto_left_content: 'F',
        footer_verso_margin: [0, 10],
        footer_verso_content_margin: [0, 40],
        footer_verso_right_content: 'F',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      page one

      <<<

      page two
      EOS

      page_width = (get_page_size pdf)[0]
      p1_header_text = (pdf.find_text 'H', page_number: 1)[0]
      p1_footer_text = (pdf.find_text 'F', page_number: 1)[0]
      (expect p1_header_text[:x].round).to eql 50
      (expect p1_footer_text[:x].round).to eql 50
      p2_header_text = (pdf.find_text 'H', page_number: 2)[0]
      p2_footer_text = (pdf.find_text 'F', page_number: 2)[0]
      (expect (page_width - p2_header_text[:x] - p2_header_text[:width]).round).to eql 50
      (expect (page_width - p2_footer_text[:x] - p2_footer_text[:width]).round).to eql 50
    end

    it 'should allow theme to control side content margin of running content using inherited value' do
      pdf_theme = {
        header_height: 36,
        header_padding: 0,
        header_recto_margin: [0, 10],
        header_recto_content_margin: [0, 'inherit'],
        header_recto_left_content: 'H',
        header_verso_margin: [0, 10],
        header_verso_content_margin: [0, 'inherit'],
        header_verso_right_content: 'H',
        footer_padding: 0,
        footer_recto_margin: [0, 10],
        footer_recto_content_margin: [0, 'inherit'],
        footer_recto_left_content: 'F',
        footer_verso_margin: [0, 10],
        footer_verso_content_margin: [0, 'inherit'],
        footer_verso_right_content: 'F',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      page one

      <<<

      page two
      EOS

      page_width = (get_page_size pdf)[0]
      p1_header_text = (pdf.find_text 'H', page_number: 1)[0]
      p1_footer_text = (pdf.find_text 'F', page_number: 1)[0]
      (expect p1_header_text[:x].round).to eql 48
      (expect p1_footer_text[:x].round).to eql 48
      p2_header_text = (pdf.find_text 'H', page_number: 2)[0]
      p2_footer_text = (pdf.find_text 'F', page_number: 2)[0]
      (expect (page_width - p2_header_text[:x] - p2_header_text[:width]).round).to eql 48
      (expect (page_width - p2_footer_text[:x] - p2_footer_text[:width]).round).to eql 48
    end

    it 'should allow theme to control end margin of running content', visual: true do
      pdf_theme = {
        header_background_color: 'EEEEEE',
        header_border_width: 0,
        header_height: 24,
        header_recto_left_content: '{page-number}',
        header_recto_margin: [6, 0, 0],
        header_verso_right_content: '{page-number}',
        header_verso_margin: [6, 0, 0],
        header_vertical_align: 'top',
        footer_background_color: 'EEEEEE',
        footer_border_width: 0,
        footer_padding: 0,
        footer_height: 24,
        footer_recto_margin: [0, 0, 6],
        footer_verso_margin: [0, 0, 6],
      }

      to_file = to_pdf_file <<~'EOS', 'running-content-end-margin.pdf', enable_footer: true, pdf_theme: pdf_theme
      page one

      <<<

      page two
      EOS

      (expect to_file).to visually_match 'running-content-end-margin.pdf'
    end

    it 'should allow theme to specify margin as single element array' do
      page_w, page_h = get_page_size to_pdf '', analyze: true

      pdf_theme = {
        header_height: 36,
        header_columns: '<50% >50%',
        header_line_height: 1,
        header_padding: 0,
        header_recto_margin: [10],
        header_recto_content_margin: [0],
        header_recto_left_content: %(image:#{fixture_file 'square.png'}[fit=contain]),
        header_verso_margin: [10],
        header_verso_content_margin: [0],
        header_verso_right_content: %(image:#{fixture_file 'square.png'}[fit=contain]),
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :image
      page one

      <<<

      page two
      EOS

      recto_image, verso_image = pdf.images
      (expect recto_image[:width]).to eql 36.0
      (expect verso_image[:width]).to eql 36.0
      (expect recto_image[:x]).to eql 10.0
      (expect recto_image[:y]).to eql (page_h - 10.0)
      (expect verso_image[:x]).to eql (page_w - 10.0 - verso_image[:width])
      (expect verso_image[:y]).to eql (page_h - 10.0)
    end

    it 'should draw column rule between columns using specified width and spacing', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_padding: [8, 0],
        header_columns: '>40% =10% <40%',
        header_column_rule_width: 0.5,
        header_column_rule_color: '333333',
        header_column_rule_spacing: 8,
        header_recto_left_content: 'left',
        header_recto_center_content: 'center',
        header_recto_right_content: 'right',
        footer_border_width: 0,
        footer_padding: [8, 0],
        footer_columns: '>40% =10% <40%',
        footer_column_rule_width: 0.5,
        footer_column_rule_color: '333333',
        footer_column_rule_spacing: 8,
        footer_recto_left_content: 'left',
        footer_recto_center_content: 'center',
        footer_recto_right_content: 'right'

      to_file = to_pdf_file <<~'EOS', 'running-content-column-rule.pdf', enable_footer: true, pdf_theme: pdf_theme
      = Document Title

      content
      EOS

      (expect to_file).to visually_match 'running-content-column-rule.pdf'
    end

    it 'should not draw column rule if there is only one column', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_padding: [8, 0],
        header_columns: '<25% =50% >25%',
        header_column_rule_width: 0.5,
        header_column_rule_color: '333333',
        header_column_rule_spacing: 8,
        header_recto_left_content: 'left',
        footer_border_width: 0,
        footer_padding: [8, 0],
        footer_columns: '<25% =50% >25%',
        footer_column_rule_width: 0.5,
        footer_column_rule_color: '333333',
        footer_column_rule_spacing: 8,
        footer_recto_right_content: 'right'

      to_file = to_pdf_file <<~'EOS', 'running-content-no-column-rule.pdf', enable_footer: true, pdf_theme: pdf_theme
      = Document Title

      content
      EOS

      (expect to_file).to visually_match 'running-content-no-column-rule.pdf'
    end
  end

  context 'Folio placement' do
    it 'should invert recto and verso if pdf-folio-placement is virtual-inverted' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      :pdf-folio-placement: virtual-inverted

      content
      EOS

      footer_text = pdf.find_text font_size: 9
      (expect footer_text).to have_size 2
      (expect footer_text[0][:string]).to eql 'verso'
      (expect footer_text[1][:string]).to eql 'verso'
    end

    it 'should invert recto and verso if pdf-folio-placement is physical-inverted' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :pdf-folio-placement: physical-inverted
      :media: print
      :doctype: book

      content
      EOS

      footer_text = pdf.find_text font_size: 9
      (expect footer_text).to have_size 2
      (expect footer_text[0][:string]).to eql 'recto'
      (expect footer_text[1][:string]).to eql 'recto'
    end

    it 'should base recto and verso on physical page number if pdf-folio-placement is physical or physical-inverted' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      { 'physical' => 'verso', 'physical-inverted' => 'recto' }.each do |placement, side|
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, enable_footer: true, analyze: true
        = Document Title
        :pdf-folio-placement: #{placement}
        :doctype: book
        :toc:

        == Chapter

        #{40.times.map {|it| %(=== Section #{it + 1}) }.join %(\n\n)}
        EOS

        (expect pdf.find_text page_number: 4, string: 'Chapter').to have_size 1
        body_start_footer_text = pdf.find_text font_size: 9, page_number: 4
        (expect body_start_footer_text).to have_size 2
        (expect body_start_footer_text[0][:string]).to eql side
      end
    end

    it 'should base recto and verso on physical page if media=prepress even if pdf-folio-placement is set' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :pdf-folio-placement: virtual-inverted
      :media: prepress
      :doctype: book

      content
      EOS

      footer_text = pdf.find_text font_size: 9
      (expect footer_text).to have_size 2
      (expect footer_text[0][:string]).to eql 'recto'
      (expect footer_text[1][:string]).to eql 'recto'
    end
  end

  context 'Page layout' do
    it 'should place footer text correctly if page layout changes' do
      theme_overrides = {
        footer_padding: 0,
        footer_verso_left_content: 'verso',
        footer_verso_right_content: nil,
        footer_recto_left_content: 'recto',
        footer_recto_right_content: nil,
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      portrait

      [.landscape]
      <<<

      landscape

      [.portrait]

      portrait
      EOS

      (expect pdf.text.size).to be 5
      pdf.text.each do |text|
        (expect text[:x]).to eql 48.24
      end
    end

    it 'should adjust dimensions of running content to fit page layout', visual: true do
      filler = lorem_ipsum '2-sentences-2-paragraphs'
      theme_overrides = {
        footer_recto_left_content: '{section-title}',
        footer_recto_right_content: '{page-number}',
        footer_verso_left_content: '{page-number}',
        footer_verso_right_content: '{section-title}',
      }

      to_file = to_pdf_file <<~EOS, 'running-content-alt-layouts.pdf', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides)
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
  end

  context 'Implicit attributes' do
    it 'should escape text of doctitle attribute' do
      theme_overrides = {
        footer_recto_right_content: '({doctitle})',
        footer_verso_left_content: '({doctitle})',
      }

      (expect do
        pdf = to_pdf <<~'EOS', enable_footer: true, attribute_overrides: { 'doctitle' => 'The Chronicles of <Foo> & &#166;' }, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
        :doctype: book

        == Chapter 1

        content
        EOS

        running_text = pdf.find_text %(The Chronicles of <Foo> & \u00a6)
        (expect running_text).to have_size 1
      end).to not_log_message
    end

    it 'should set document-title and document-subtitle based on doctitle' do
      pdf_theme = {
        footer_recto_left_content: '({document-title})',
        footer_recto_right_content: '[{document-subtitle}]',
        footer_verso_left_content: '({document-title})',
        footer_verso_right_content: '[{document-subtitle}]',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title: Subtitle
      :doctype: book

      == Beginning

      == End
      EOS

      [2, 3].each do |pgnum|
        main_title_text = (pdf.find_text page_number: pgnum, string: '(Document Title)')[0]
        subtitle_text = (pdf.find_text page_number: pgnum, string: '[Subtitle]')[0]
        (expect main_title_text).not_to be_nil
        (expect subtitle_text).not_to be_nil
      end
    end

    it 'should set part-title, chapter-title, and section-title based on context of current page' do
      pdf_theme = {
        footer_columns: '<25% >70%',
        footer_recto_left_content: 'FOOTER',
        footer_recto_right_content: '[{part-title}|{chapter-title}|{section-title}]',
        footer_verso_left_content: 'FOOTER',
        footer_verso_right_content: '[{part-title}|{chapter-title}|{section-title}]',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      = Part I

      == Chapter A

      === Detail

      <<<

      === More Detail

      == Chapter B

      = Part II

      == Chapter C
      EOS

      footer_y = (pdf.find_text 'FOOTER')[0][:y]
      titles_by_page = (pdf.find_text y: footer_y).each_with_object Hash.new do |it, accum|
        accum[it[:page_number]] = it[:string] unless it[:string] == 'FOOTER'
      end
      (expect titles_by_page[2]).to eql '[Part I||]'
      (expect titles_by_page[3]).to eql '[Part I|Chapter A|Detail]'
      (expect titles_by_page[4]).to eql '[Part I|Chapter A|More Detail]'
      (expect titles_by_page[5]).to eql '[Part I|Chapter B|]'
      (expect titles_by_page[6]).to eql '[Part II||]'
      (expect titles_by_page[7]).to eql '[Part II|Chapter C|]'
    end

    it 'should clear part title on appendix pages of multi-part book' do
      pdf_theme = {
        footer_font_color: '0000FF',
        footer_recto_right_content: '{part-title} ({page-number})',
        footer_verso_left_content: '{part-title} ({page-number})',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :doctype: book

      = Part A

      == Chapter 1

      = Part B

      == Chapter 2

      [appendix]
      = Installation

      Describe installation procedure.
      EOS

      footer_texts = pdf.find_text page_number: 5, font_color: '0000FF'
      (expect footer_texts).to have_size 1
      (expect footer_texts[0][:string]).to eql 'Part B (4)'
      footer_texts = pdf.find_text page_number: 6, font_color: '0000FF'
      (expect footer_texts).to have_size 1
      (expect footer_texts[0][:string]).to eql '(5)'
    end

    it 'should set chapter-numeral attribute when a chapter is active and sectnums attribute is set' do
      pdf_theme = {
        footer_title_style: 'basic',
        footer_font_color: '0000FF',
        footer_recto_right_content: %(({chapter-numeral})\n{chapter-title} | {page-number}),
        footer_verso_left_content: %(({chapter-numeral})\n{chapter-title} | {page-number}),
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :sectnums:

      preamble

      == A

      content

      <<<

      more content

      == B

      content
      EOS

      footer_texts = pdf.find_text font_color: '0000FF'
      (expect footer_texts).to have_size 4
      (expect footer_texts.map {|it| it[:page_number] }).to eql [2, 3, 4, 5]
      (expect footer_texts.map {|it| it[:string] }).to eql ['Preface | 1', '(1) A | 2', '(1) A | 3', '(2) B | 4']
    end

    it 'should not set chapter-numeral attribute if sectnums attributes is not set' do
      pdf_theme = {
        footer_title_style: 'basic',
        footer_font_color: '0000FF',
        footer_recto_right_content: %(({chapter-numeral})\n{chapter-title} | {page-number}),
        footer_verso_left_content: %(({chapter-numeral})\n{chapter-title} | {page-number}),
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :doctype: book

      preamble

      == A

      content

      <<<

      more content

      == B

      content
      EOS

      footer_texts = pdf.find_text font_color: '0000FF'
      (expect footer_texts).to have_size 4
      (expect footer_texts.map {|it| it[:page_number] }).to eql [2, 3, 4, 5]
      (expect footer_texts.map {|it| it[:string] }).to eql ['Preface | 1', 'A | 2', 'A | 3', 'B | 4']
    end

    it 'should set part-numeral attribute when a part is active and partnums attribute is set' do
      pdf_theme = {
        footer_title_style: 'basic',
        footer_font_color: '0000FF',
        footer_recto_right_content: %(P{part-numeral} |\n{page-number}),
        footer_verso_left_content: %(P{part-numeral} |\n{page-number}),
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :partnums:

      content

      = A

      == Chapter

      content

      = B

      == Moar Chapter

      content
      EOS

      footer_texts = pdf.find_text font_color: '0000FF'
      (expect footer_texts).to have_size 5
      (expect footer_texts.map {|it| it[:page_number] }).to eql (2..6).to_a
      (expect footer_texts.map {|it| it[:string] }).to eql ['1', 'PI | 2', 'PI | 3', 'PII | 4', 'PII | 5']
    end

    it 'should not set part-numeral attribute if partnums attribute is not set' do
      pdf_theme = {
        footer_title_style: 'basic',
        footer_font_color: '0000FF',
        footer_recto_right_content: %(P{part-numeral} |\n{page-number}),
        footer_verso_left_content: %(P{part-numeral} |\n{page-number}),
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :doctype: book

      = A

      == Chapter

      content
      EOS

      footer_texts = pdf.find_text font_color: '0000FF'
      (expect footer_texts).to have_size 2
      (expect footer_texts.map {|it| it[:page_number] }).to eql [2, 3]
      (expect footer_texts.map {|it| it[:string] }).to eql %w(1 2)
    end

    it 'should not set section-title attribute on pages in preamble of article' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: '[{section-title}]',
        footer_verso_left_content: '[{section-title}]',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title

      First page of preamble.

      <<<

      Second page of preamble.

      == Section Title
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 2
      (expect footer_texts[0][:string]).to eql '[]'
      (expect footer_texts[1][:string]).to eql '[Section Title]'
    end

    it 'should not set section-title attribute if document has no sections' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: '[{section-title}]',
        footer_verso_left_content: '[{section-title}]',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      first page

      <<<

      last page
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 2
      (expect footer_texts[0][:string]).to eql '[]'
      (expect footer_texts[1][:string]).to eql '[]'
    end

    it 'should set chapter-title to value of preface-title attribute for pages in the preamble' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: '{chapter-title}',
        footer_verso_left_content: '{chapter-title}',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :preface-title: PREFACE

      First page of preface.

      <<<

      Second page of preface.

      == First Chapter
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 3
      (expect footer_texts[0][:page_number]).to be 2
      (expect footer_texts[0][:string]).to eql 'PREFACE'
      (expect footer_texts[1][:page_number]).to be 3
      (expect footer_texts[1][:string]).to eql 'PREFACE'
      (expect footer_texts[2][:page_number]).to be 4
      (expect footer_texts[2][:string]).to eql 'First Chapter'
    end

    it 'should set chapter-title attribute correctly on pages in preface when title page is disabled' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: '{chapter-title}',
        footer_verso_left_content: '{chapter-title}',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :notitle:

      First page of preface.

      <<<

      Second page of preface.

      == First Chapter
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 3
      (expect footer_texts[0][:page_number]).to be 1
      (expect footer_texts[0][:string]).to eql 'Preface'
      (expect footer_texts[1][:page_number]).to be 2
      (expect footer_texts[1][:string]).to eql 'Preface'
      (expect footer_texts[2][:page_number]).to be 3
      (expect footer_texts[2][:string]).to eql 'First Chapter'
    end

    it 'should set chapter-title attribute to value of toc-title attribute on toc pages in default location' do
      pdf_theme = {
        running_content_start_at: 'toc',
        footer_font_color: 'AA0000',
        footer_recto_right_content: '{page-number} | {chapter-title}',
        footer_verso_left_content: '{chapter-title} | {page-number}',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :toc:
      :toc-title: Contents

      == Beginning

      == End
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 3
      (expect footer_texts[0][:page_number]).to be 2
      (expect footer_texts[0][:string]).to eql 'Contents | ii'
      (expect footer_texts[1][:page_number]).to be 3
      (expect footer_texts[1][:string]).to eql '1 | Beginning'
    end

    it 'should set chapter-title attribute to value of toc-title attribute on toc pages in custom location' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: '{page-number} | {chapter-title}',
        footer_verso_left_content: '{chapter-title} | {page-number}',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :toc: macro
      :toc-title: Contents

      == Beginning

      toc::[]

      == End
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 3
      (expect footer_texts[0][:page_number]).to be 2
      (expect footer_texts[0][:string]).to eql '1 | Beginning'
      (expect footer_texts[1][:page_number]).to be 3
      (expect footer_texts[1][:string]).to eql 'Contents | 2'
      (expect footer_texts[2][:page_number]).to be 4
      (expect footer_texts[2][:string]).to eql '3 | End'
    end

    it 'should set section-title attribute to value of toc-title attribute on toc pages in custom location' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: '{page-number} | {section-title}',
        footer_verso_left_content: '{section-title} | {page-number}',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :toc: macro
      :toc-title: Contents

      == Beginning

      <<<

      toc::[]

      <<<

      == End
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 3
      (expect footer_texts[0][:page_number]).to be 1
      (expect footer_texts[0][:string]).to eql '1 | Beginning'
      (expect footer_texts[1][:page_number]).to be 2
      (expect footer_texts[1][:string]).to eql 'Contents | 2'
      (expect footer_texts[2][:page_number]).to be 3
      (expect footer_texts[2][:string]).to eql '3 | End'
    end

    it 'should not set section-title attribute to value of toc-title attribute on toc pages that contain other section' do
      pdf_theme = {
        footer_font_color: 'AA0000',
        footer_recto_right_content: '{page-number} | {section-title}',
        footer_verso_left_content: '{section-title} | {page-number}',
      }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :toc: macro
      :toc-title: Contents

      == Beginning

      toc::[]

      <<<

      == End
      EOS

      footer_texts = pdf.find_text font_color: 'AA0000'
      (expect footer_texts).to have_size 2
      (expect footer_texts[0][:page_number]).to be 1
      (expect footer_texts[0][:string]).to eql '1 | Beginning'
      (expect footer_texts[1][:page_number]).to be 2
      (expect footer_texts[1][:string]).to eql 'End | 2'
    end

    it 'should assign section titles down to sectlevels defined in theme' do
      input = <<~'EOS'
      = Document Title
      :doctype: book

      == A

      <<<

      === Level 2

      <<<

      ==== Level 3

      <<<

      ===== Level 4

      == B
      EOS

      {
        nil => ['A', 'Level 2', 'Level 2', 'Level 2', 'B'],
        2 => ['A', 'Level 2', 'Level 2', 'Level 2', 'B'],
        3 => ['A', 'Level 2', 'Level 3', 'Level 3', 'B'],
        4 => ['A', 'Level 2', 'Level 3', 'Level 4', 'B'],
      }.each do |sectlevels, expected|
        theme_overrides = {
          footer_sectlevels: sectlevels,
          footer_font_family: 'Helvetica',
          footer_recto_right_content: '{section-or-chapter-title}',
          footer_verso_left_content: '{section-or-chapter-title}',
        }
        pdf = to_pdf input, enable_footer: true, pdf_theme: theme_overrides, analyze: true
        titles = (pdf.find_text font_name: 'Helvetica').map {|it| it[:string] }
        (expect titles).to eql expected
      end
    end

    it 'should use doctitle, toc-title, and preface-title as chapter-title before first chapter' do
      theme_overrides = {
        running_content_start_at: 'title',
        page_numbering_start_at: 'title',
        footer_recto_right_content: '{chapter-title}',
        footer_verso_left_content: '{chapter-title}',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      content

      == Chapter 1

      content
      EOS

      expected_running_content_by_page = { 1 => 'Document Title', 2 => 'Table of Contents', 3 => 'Preface', 4 => 'Chapter 1' }
      running_content_by_page = (pdf.find_text y: 14.263).each_with_object({}) {|text, accum| accum[text[:page_number]] = text[:string] }
      (expect running_content_by_page).to eql expected_running_content_by_page
    end

    it 'should allow style of title-related attributes to be customized using the title-style key' do
      input = <<~'EOS'
      = Document Title
      :doctype: book
      :sectnums:
      :notitle:

      == Beginning
      EOS

      pdf_theme = {
        footer_recto_left_content: '[{chapter-title}]',
        footer_recto_right_content: '',
        footer_verso_left_content: '[{chapter-title}]',
        footer_verso_right_content: '',
        footer_font_color: 'AA0000',
      }

      [
        [nil, 'Chapter 1. Beginning'],
        ['document', 'Chapter 1. Beginning'],
        ['toc', '1. Beginning'],
        %w(basic Beginning),
      ].each do |(title_style, expected_title)|
        pdf_theme = pdf_theme.merge footer_title_style: title_style if title_style
        pdf = to_pdf input, pdf_theme: pdf_theme, enable_footer: true, analyze: true
        footer_text = (pdf.find_text font_color: 'AA0000')[0]
        (expect footer_text[:string]).to eql %([#{expected_title}])
      end
    end
  end

  context 'Images' do
    it 'should align images based on column aligment', visual: true do
      pdf_theme = {
        footer_columns: '>50% <50%',
        footer_recto_left_content: %(image:#{fixture_file 'tux.png'}[fit=contain]),
        footer_recto_right_content: %(image:#{fixture_file 'tux.png'}[fit=contain]),
      }

      to_file = to_pdf_file 'body', 'running-content-image-alignment.pdf', pdf_theme: pdf_theme, enable_footer: true

      (expect to_file).to visually_match 'running-content-image-alignment.pdf'
    end

    it 'should allow image vertical alignment to be set independent of column vertical alignment' do
      image_positions = %w(top center middle bottom).each_with_object({}) do |image_vertical_align, accum|
        pdf_theme = {
          footer_columns: '<50% >50%',
          footer_padding: 0,
          footer_vertical_align: 'top',
          footer_image_vertical_align: image_vertical_align,
          footer_recto_left_content: %(image:#{fixture_file 'tux.png'}[pdfwidth=16]),
          footer_recto_right_content: '{page-number}',
        }

        pdf = to_pdf 'body', pdf_theme: pdf_theme, enable_footer: true, analyze: :image
        images = pdf.images
        (expect images).to have_size 1
        accum[image_vertical_align] = images[0][:y]
      end
      (expect image_positions['top']).to be > image_positions['center']
      (expect image_positions['center']).to eql image_positions['middle']
      (expect image_positions['center']).to be > image_positions['bottom']
    end

    it 'should skip image macro if target is remote and allow-uri-read attribute is not set' do
      with_local_webserver do |base_url|
        pdf_theme = {
          footer_font_color: '0000FF',
          footer_columns: '=100%',
          footer_recto_center_content: %(image:#{base_url}/tux.png[fit=contain]),
        }

        (expect do
          pdf = to_pdf 'body', analyze: true, pdf_theme: pdf_theme, enable_footer: true
          footer_text = pdf.find_unique_text font_color: '0000FF'
          (expect footer_text[:string]).to eql 'image:[fit=contain]'
        end).to log_message severity: :WARN, message: '~allow-uri-read is not enabled; cannot embed remote image'
      end
    end

    it 'should support remote image if allow-uri-read attribute is set', visual: true do
      with_local_webserver do |base_url|
        pdf_theme = {
          footer_columns: '>50% <50%',
          footer_recto_left_content: %(image:#{base_url}/tux.png[fit=contain]),
          footer_recto_right_content: %(image:#{base_url}/tux.png[fit=contain]),
        }

        doc = to_pdf 'body',
            analyze: :document,
            to_file: (to_file = output_file 'running-content-remote-image.pdf'),
            pdf_theme: pdf_theme,
            enable_footer: true,
            attribute_overrides: { 'allow-uri-read' => '' }

        (expect to_file).to visually_match 'running-content-image-alignment.pdf'
        # NOTE: we could assert no log messages instead, but that assumes the remove_tmp_files method is even called
        (expect doc.converter.instance_variable_get :@tmp_files).to be_empty
      end
    end

    it 'should warn and show alt text if image cannot be embedded' do
      pdf_theme = {
        footer_font_color: '0000FF',
        footer_columns: '=100%',
        footer_recto_center_content: %(image:#{fixture_file 'broken.svg'}[no worky]),
      }

      (expect do
        pdf = to_pdf 'body', analyze: true, pdf_theme: pdf_theme, enable_footer: true
        footer_text = pdf.find_unique_text font_color: '0000FF'
        (expect footer_text[:string]).to eql '[no worky]'
      end).to log_message severity: :WARN, message: %(~could not embed image in running content: #{fixture_file 'broken.svg'}; Missing end tag for 'rect')
    end

    it 'should support data URI image', visual: true do
      image_data = File.binread fixture_file 'tux.png'
      encoded_image_data = Base64.strict_encode64 image_data
      image_url = %(data:image/png;base64,#{encoded_image_data})
      pdf_theme = {
        footer_columns: '>50% <50%',
        footer_recto_left_content: %(image:#{image_url}[fit=contain]),
        footer_recto_right_content: %(image:#{image_url}[fit=contain]),
      }

      to_file = to_pdf_file 'body', 'running-content-data-uri-image.pdf', pdf_theme: pdf_theme, enable_footer: true

      (expect to_file).to visually_match 'running-content-image-alignment.pdf'
    end

    it 'should scale image up to width when fit=contain', visual: true do
      %w(pdfwidth=99.76 fit=contain pdfwidth=0.5in,fit=contain pdfwidth=15in,fit=contain).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-contain-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image-fit.pdf'
      end
    end

    it 'should not overlap border when scaling image to fit content area', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_border_width: 5,
        header_border_color: 'dddddd',
        header_columns: '>40% =20% <40%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'square.png'}[fit=contain]),
        header_recto_right_content: 'text',
        footer_height: 36,
        footer_padding: 0,
        footer_vertical_align: 'middle',
        footer_border_width: 5,
        footer_border_color: 'dddddd',
        footer_recto_columns: '>40% =20% <40%',
        footer_recto_left_content: 'text',
        footer_recto_center_content: %(image:#{fixture_file 'square.png'}[fit=contain]),
        footer_recto_right_content: 'text'

      to_file = to_pdf_file %([.text-center]\ncontent), 'running-content-image-contain-border.pdf', enable_footer: true, pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image-contain-border.pdf'
    end

    it 'should scale image down to width when fit=scale-down', visual: true do
      %w(pdfwidth=99.76 pdfwidth=15in,fit=scale-down).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-scale-down-width-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image-fit.pdf'
      end
    end

    it 'should scale image down to height when fit=scale-down', visual: true do
      %w(pdfwidth=30.60 fit=scale-down).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'tux.png'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-scale-down-height-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image-scale-down.pdf'
      end
    end

    it 'should scale image down to minimum dimension when fit=scale-down', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 24,
        header_columns: '>25% =50% <25%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'square-viewbox-only.svg'}[fit=scale-down]),
        header_recto_right_content: 'text'
      to_file = to_pdf_file %([.text-center]\ncontent), 'running-content-image-scale-down-min.pdf', pdf_theme: pdf_theme
      (expect to_file).to visually_match 'running-content-image-scale-down-min.pdf'
    end

    it 'should not modify image dimensions when fit=scale-down if image already fits', visual: true do
      %w(pdfwidth=0.5in pdfwidth=0.5in,fit=scale-down).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image.pdf'
      end
    end

    it 'should size image based on width attribute value if no other dimension attribute is specified', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_columns: '<25% =50% >25%',
        header_recto_center_content: %(image:#{fixture_file 'square-viewbox-only.svg'}[square,24])

      to_file = to_pdf_file %([.text-center]\ncontent), 'running-content-image-width.pdf', pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image-width.pdf'
    end

    it 'should use image format specified by format attribute' do
      source_file = (dest_file = fixture_file 'square') + '.svg'
      pdf_theme = {
        footer_height: 36,
        footer_padding: 0,
        footer_recto_columns: '<25% =50% >25%',
        footer_border_width: 0,
        footer_recto_left_content: nil,
        footer_recto_center_content: %(image:#{dest_file}[format=svg,fit=contain]),
        footer_recto_right_content: nil,
      }
      FileUtils.cp source_file, dest_file
      pdf = to_pdf 'content', enable_footer: true, pdf_theme: pdf_theme, analyze: :rect
      (expect pdf.rectangles).to have_size 1
      rect = pdf.rectangles[0]
      (expect rect[:width]).to eql 200.0
      (expect rect[:height]).to eql 200.0
    ensure
      File.unlink dest_file
    end

    it 'should print running content on consecutive pages even when image in running content overruns bounds', visual: true do
      pdf_theme = {
        footer_recto_left_content: '{page-number}',
        footer_recto_right_content: %(image:#{fixture_file 'tux.png'}[pdfwidth=100px]),
        footer_verso_left_content: '{page-number}',
        footer_verso_right_content: %(image:#{fixture_file 'tux.png'}[pdfwidth=100px]),
      }

      to_file = to_pdf_file <<~'EOS', 'running-content-image-overrun.pdf', enable_footer: true, pdf_theme: pdf_theme
      = Article Title

      content

      <<<

      content
      EOS

      (expect to_file).to visually_match 'running-content-image-overrun.pdf'
    end

    it 'should resolve image target relative to themesdir', visual: true do
      [
        {
          'pdf-theme' => 'running-header',
          'pdf-themesdir' => fixtures_dir,
        },
        {
          'pdf-theme' => 'fixtures/running-header-outside-fixtures-theme.yml',
          'pdf-themesdir' => (File.dirname fixtures_dir),
        },
      ].each_with_index do |attribute_overrides, idx|
        to_file = to_pdf_file <<~'EOS', %(running-content-image-from-themesdir-#{idx}.pdf), attribute_overrides: attribute_overrides
        [.text-center]
        content
        EOS
        (expect to_file).to visually_match 'running-content-image.pdf'
      end
    end

    it 'should resolve image target relative to theme file when themesdir is not set', visual: true do
      attribute_overrides = { 'pdf-theme' => (fixture_file 'running-header-theme.yml', relative: true) }
      to_file = to_pdf_file <<~'EOS', 'running-content-image-from-theme.pdf', attribute_overrides: attribute_overrides
      [.text-center]
      content
      EOS

      (expect to_file).to visually_match 'running-content-image.pdf'
    end

    it 'should resolve run-in image relative to themesdir', visual: true do
      to_file = to_pdf_file 'content', 'running-content-run-in-image.pdf', attribute_overrides: { 'pdf-theme' => (fixture_file 'running-header-run-in-image-theme.yml') }
      (expect to_file).to visually_match 'running-content-run-in-image.pdf'
    end

    it 'should set imagesdir attribute to value of themesdir in running content' do
      pdf_theme = {
        __dir__: fixtures_dir,
        footer_columns: '=100%',
        footer_padding: 0,
        footer_recto_center_content: 'image:tux.png[pdfwidth=16] found in {imagesdir}',
        footer_verso_center_content: 'image:tux.png[pdfwidth=16] found in {imagesdir}',
      }

      pdf = to_pdf 'body', pdf_theme: pdf_theme, enable_footer: true, analyze: :image
      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:width]).to eql 16.0

      pdf = to_pdf 'body', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      footer_text = (pdf.text.find {|it| it[:y] < 50 })
      (expect footer_text[:string]).to end_with %(found in #{fixtures_dir})
    end

    it 'should not leave imagesdir attribute set after running content if originally unset' do
      pdf_theme = {
        __dir__: fixtures_dir,
        footer_columns: '=100%',
        footer_padding: 0,
        footer_recto_center_content: 'image:tux.png[pdfwidth=16] found in {imagesdir}',
        footer_verso_center_content: 'image:tux.png[pdfwidth=16] foudn in {imagesdir}',
      }

      doc = to_pdf 'body', pdf_theme: pdf_theme, enable_footer: true, to_file: (pdf_io = StringIO.new), attributes: {}, analyze: :document
      (expect doc.attr? 'imagesdir').to be_falsy
      pdf = PDF::Reader.new pdf_io
      (expect (pdf.page 1).text).to include fixtures_dir
    end

    it 'should warn and replace image with alt text if image is not found' do
      [true, false].each do |block|
        (expect do
          pdf_theme = build_pdf_theme \
            header_height: 36,
            header_columns: '=100%',
            header_recto_center_content: %(image:#{block ? ':' : ''}no-such-image.png[alt text])

          pdf = to_pdf 'content', pdf_theme: pdf_theme, analyze: true

          alt_text = pdf.find_text '[alt text]'
          (expect alt_text).to have_size 1
        end).to log_message severity: :WARN, message: %r(image to embed not found or not readable.*data/themes/no-such-image\.png$)
      end
    end

    it 'should add link to raster image if link attribute is set' do
      theme_overrides = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_recto_center_content: 'image:tux.png[link=https://www.linuxfoundation.org/projects/linux/]',
        header_verso_center_content: 'image:tux.png[link=https://www.linuxfoundation.org/projects/linux/]',
      }
      pdf = to_pdf 'body', pdf_theme: theme_overrides

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://www.linuxfoundation.org/projects/linux/'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 36.0
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 30.6
    end

    it 'should add link to SVG image if link attribute is set' do
      theme_overrides = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_recto_center_content: 'image:square.svg[link=https://example.org]',
        header_verso_center_content: 'image:square.svg[link=https://example.org]',
      }
      pdf = to_pdf 'body', pdf_theme: theme_overrides

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 36.0
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 36.0
    end

    it 'should add link around image aligned to top' do
      pdf_theme = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_image_vertical_align: 'top',
        header_recto_center_content: 'image:tux.png[pdfwidth=20.4pt,link=https://www.linuxfoundation.org/projects/linux/]',
        header_verso_center_content: 'image:tux.png[pdfwidth=20.4pt,link=https://www.linuxfoundation.org/projects/linux/]',
      }
      pdf = to_pdf 'body', pdf_theme: pdf_theme

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://www.linuxfoundation.org/projects/linux/'
      link_rect = link_annotation[:Rect]
      link_coords = { x: link_rect[0], y: link_rect[3], width: ((link_rect[2] - link_rect[0]).round 4), height: ((link_rect[3] - link_rect[1]).round 4) }

      pdf = to_pdf 'body', pdf_theme: pdf_theme, analyze: :image
      image = pdf.images[0]
      image_coords = { x: image[:x], y: image[:y], width: image[:width], height: image[:height] }
      (expect link_coords).to eql image_coords
      (expect image_coords[:y]).to eql PDF::Core::PageGeometry::SIZES['A4'][1]
    end

    it 'should add link around image aligned to bottom' do
      pdf_theme = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_image_vertical_align: 'bottom',
        header_recto_center_content: 'image:tux.png[pdfwidth=20.4pt,link=https://www.linuxfoundation.org/projects/linux/]',
        header_verso_center_content: 'image:tux.png[pdfwidth=20.4pt,link=https://www.linuxfoundation.org/projects/linux/]',
      }
      pdf = to_pdf 'body', pdf_theme: pdf_theme

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://www.linuxfoundation.org/projects/linux/'
      link_rect = link_annotation[:Rect]
      link_coords = { x: link_rect[0], y: link_rect[3], width: ((link_rect[2] - link_rect[0]).round 4), height: ((link_rect[3] - link_rect[1]).round 4) }

      pdf = to_pdf 'body', pdf_theme: pdf_theme, analyze: :image
      image = pdf.images[0]
      image_coords = { x: image[:x], y: image[:y], width: image[:width], height: image[:height] }
      (expect link_coords).to eql image_coords
    end

    it 'should add link around image offset from top by specific value' do
      pdf_theme = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_image_vertical_align: 5,
        header_recto_center_content: 'image:square.png[pdfwidth=18pt,link=https://en.wikipedia.org/wiki/Square]',
        header_verso_center_content: 'image:square.png[pdfwidth=18pt,link=https://en.wikipedia.org/wiki/Square]',
      }

      pdf = to_pdf 'body', pdf_theme: pdf_theme

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://en.wikipedia.org/wiki/Square'
      link_rect = link_annotation[:Rect]
      link_coords = { x: link_rect[0], y: link_rect[3], width: ((link_rect[2] - link_rect[0]).round 4), height: ((link_rect[3] - link_rect[1]).round 4) }

      pdf = to_pdf 'body', pdf_theme: pdf_theme, analyze: :image
      image = pdf.images[0]
      image_coords = { x: image[:x], y: image[:y], width: image[:width], height: image[:height] }
      (expect link_coords).to eql image_coords
      (expect image_coords[:y]).to eql (PDF::Core::PageGeometry::SIZES['A4'][1] - 5)
    end

    it 'should replace unrecognized font family in SVG with SVG fallback font family specified in theme' do
      theme_overrides = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_recto_center_content: 'image:svg-with-unknown-font.svg[]',
        header_verso_center_content: 'image:svg-with-unknown-font.svg[]',
        svg_fallback_font_family: 'Times-Roman',
      }
      pdf = to_pdf 'body', pdf_theme: theme_overrides, analyze: true

      text = pdf.find_text 'This text uses the default SVG font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'Times-Roman'
    end

    it 'should embed local image referenced in SVG', visual: true do
      pdf_theme = {
        __dir__: fixtures_dir,
        footer_padding: 0,
        footer_recto_right_content: 'image:svg-with-local-image.svg[fit=contain]',
        footer_verso_left_content: 'image:svg-with-local-image.svg[fit=contain]',
      }
      to_file = to_pdf_file <<~'EOS', 'running-content-svg-with-local-image.pdf', enable_footer: true, pdf_theme: pdf_theme
      body
      EOS

      (expect to_file).to visually_match 'running-content-svg-with-local-image.pdf'
    end
  end
end
