# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Page' do
  context 'Size' do
    it 'should set page size specified by theme by default' do
      pdf = to_pdf <<~'EOS', analyze: :page
      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should set page size specified by page_size key in theme with predefined name' do
      ['LEGAL', 'legal', :LEGAL, :legal].each do |page_size|
        pdf = to_pdf <<~'EOS', pdf_theme: { page_size: page_size }, analyze: :page
        content
        EOS
        (expect pdf.pages).to have_size 1
        (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LEGAL']
      end
    end

    it 'should set page size specified by pdf-page-size attribute using predefined name' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: Letter

      content
      EOS
      (expect pdf.pages).to have_size 1
      # NOTE: pdf-core 0.8 coerces whole number floats to integers
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end

    it 'should ignore pdf-page-size attribute if value is unrecognized name' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: Huge

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in points' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: [600, 800]

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql [600.0, 800.0]
    end

    it 'should set page size specified by page_size theme key using dimension array in points' do
      pdf = to_pdf 'content', pdf_theme: { page_size: [600, 800] }, analyze: :page
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql [600.0, 800.0]
    end

    it 'should truncate page size array to two dimensions' do
      pdf = to_pdf 'content', pdf_theme: { page_size: [600, 800, 1000] }, analyze: :page
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql [600.0, 800.0]
    end

    it 'should expand page size array to two dimensions' do
      pdf = to_pdf 'content', pdf_theme: { page_size: [800] }, analyze: :page
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql [800.0, 800.0]
    end

    it 'should use default page size if page size array is empty' do
      pdf = to_pdf 'content', pdf_theme: { page_size: [] }, analyze: :page
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should use default page size if page size is an unrecognized type' do
      pdf = to_pdf 'content', pdf_theme: { page_size: true }, analyze: :page
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should use default page size if any dimension of page size is an unrecognized type' do
      pdf = to_pdf 'content', pdf_theme: { page_size: ['8.5in', true] }, analyze: :page
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should use default page size if any dimension of page size is an unrecognized measurement' do
      pdf = to_pdf 'content', pdf_theme: { page_size: %w(wide tall) }, analyze: :page
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['A4']
    end

    it 'should use default page size if one of dimensions in page size array is 0' do
      [[800, 0], ['8.5in', '0in']].each do |page_size|
        pdf = to_pdf <<~'EOS', pdf_theme: { page_size: page_size }, analyze: :page
        content
        EOS
        (expect pdf.pages).to have_size 1
        (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['A4']
      end
    end

    it 'should set page size specified by pdf-page-size attribute using dimension array in inches' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: [8.5in, 11in]

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end

    it 'should set page size specified by pdf-page-size attribute using dimension string in inches' do
      pdf = to_pdf <<~'EOS', analyze: :page
      :pdf-page-size: 8.5in x 11in

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end

    it 'should set page size specified by page_size theme key using dimension array in inches' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_size: ['8.5in', '11in'] }, analyze: :page
      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    end
  end

  context 'Layout' do
    it 'should use layout specified in theme by default' do
      pdf = to_pdf <<~'EOS'
      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0].orientation).to eql 'portrait'
    end

    it 'should use layout specified by pdf-page-layout attribute' do
      pdf = to_pdf <<~'EOS'
      :pdf-page-layout: landscape

      content
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0].orientation).to eql 'landscape'
    end
  end

  context 'Initial Zoom' do
    it 'should set initial zoom to FitH by default' do
      pdf = to_pdf 'content'
      open_action = pdf.catalog[:OpenAction]
      (expect open_action).not_to be_nil
      (expect open_action).to have_size 3
      (expect pdf.objects[open_action[0]]).to eql (pdf.page 1).page_object
      (expect open_action[1]).to be :FitH
      (expect open_action[2]).to eql (get_page_size pdf, 1)[1]
    end

    it 'should not set initial zoom if value specified in theme is unrecognized or nil' do
      [nil, 'Auto'].each do |value|
        pdf = to_pdf 'content', pdf_theme: { page_initial_zoom: value }
        open_action = pdf.catalog[:OpenAction]
        (expect open_action).to be_nil
      end
    end

    it 'should set initial zoom to Fit as specified by theme' do
      pdf = to_pdf 'content', pdf_theme: { page_initial_zoom: 'Fit' }
      open_action = pdf.catalog[:OpenAction]
      (expect open_action).not_to be_nil
      (expect open_action).to have_size 2
      (expect pdf.objects[open_action[0]]).to eql (pdf.page 1).page_object
      (expect open_action[1]).to be :Fit
    end

    it 'should set initial zoom to FitV as specified by theme' do
      pdf = to_pdf 'content', pdf_theme: { page_initial_zoom: 'FitV' }
      open_action = pdf.catalog[:OpenAction]
      (expect open_action).not_to be_nil
      (expect open_action).to have_size 3
      (expect pdf.objects[open_action[0]]).to eql (pdf.page 1).page_object
      (expect open_action[1]).to be :FitV
      (expect open_action[2]).to eql 0
    end
  end

  context 'Mode' do
    it 'should set page mode to /UseOutlines by default' do
      pdf = to_pdf 'content'
      (expect pdf.catalog[:PageMode]).to be :UseOutlines
    end

    it 'should set page mode to /UseOutlines if value of page_mode key in theme is outline' do
      pdf = to_pdf 'content', pdf_theme: { page_mode: 'outline' }
      (expect pdf.catalog[:PageMode]).to be :UseOutlines
    end

    it 'should set page mode to /UseOutlines if value of pdf-page-mode attribute is outline' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-page-mode' => 'outline' }
      (expect pdf.catalog[:PageMode]).to be :UseOutlines
    end

    it 'should set page mode to /UseNone if value of page_mode key in theme is none' do
      pdf = to_pdf 'content', pdf_theme: { page_mode: 'none' }
      (expect pdf.catalog[:PageMode]).to be :UseNone
    end

    it 'should set page mode to /UseNone if value of pdf-page-mode attribute is none' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-page-mode' => 'none' }
      (expect pdf.catalog[:PageMode]).to be :UseNone
    end

    it 'should set page mode to /UseThumbs if value of page_mode key in theme is thumbs' do
      pdf = to_pdf 'content', pdf_theme: { page_mode: 'thumbs' }
      (expect pdf.catalog[:PageMode]).to be :UseThumbs
    end

    it 'should set page mode to /UseThumbs if value of pdf-page-mode attribute is thumbs' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-page-mode' => 'thumbs' }
      (expect pdf.catalog[:PageMode]).to be :UseThumbs
    end

    it 'should set page mode to /UseOutlines if value of page_mode key in theme is unrecognized' do
      pdf = to_pdf 'content', pdf_theme: { page_mode: 'invalid' }
      (expect pdf.catalog[:PageMode]).to be :UseOutlines
    end

    it 'should set page mode to /UseOutlines if value of pdf-page-mode attribute is unrecognized' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-page-mode' => 'invalid' }
      (expect pdf.catalog[:PageMode]).to be :UseOutlines
    end

    it 'should set page mode to fullscreen if page_mode key in theme is fullscreen' do
      pdf = to_pdf 'content', pdf_theme: { page_mode: 'fullscreen' }
      (expect pdf.catalog[:PageMode]).to be :FullScreen
      (expect pdf.catalog[:NonFullScreenPageMode]).to be :UseOutlines
    end

    it 'should set page mode to fullscreen if pdf-page-mode attribute is fullscreen' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-page-mode' => 'fullscreen' }
      (expect pdf.catalog[:PageMode]).to be :FullScreen
      (expect pdf.catalog[:NonFullScreenPageMode]).to be :UseOutlines
    end

    it 'should set secondary page mode to none if page_mode key in theme is fullscreen none' do
      pdf = to_pdf 'content', pdf_theme: { page_mode: 'fullscreen none' }
      (expect pdf.catalog[:PageMode]).to be :FullScreen
      (expect pdf.catalog[:NonFullScreenPageMode]).to be :UseNone
    end

    it 'should set secondary page mode to none if pdf-page-mode attribute is fullscreen none' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-page-mode' => 'fullscreen none' }
      (expect pdf.catalog[:PageMode]).to be :FullScreen
      (expect pdf.catalog[:NonFullScreenPageMode]).to be :UseNone
    end

    it 'should allow pdf-page-mode attribute in document to disable fullscreen mode' do
      pdf = to_pdf 'content', pdf_theme: { page_mode: 'fullscreen' }, attribute_overrides: { 'pdf-page-mode' => '' }
      (expect pdf.catalog[:PageMode]).not_to be :FullScreen
      (expect pdf.catalog).not_to have_key :NonFullScreenPageMode
    end
  end

  context 'Margin' do
    it 'should use the margin specified in theme by default' do
      input = 'content'
      prawn = to_pdf input, analyze: :document
      pdf = to_pdf input, analyze: true

      (expect prawn.page_margin).to eql [36, 48.24, 48.24, 48.24]
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 48.24, 793.926]
    end

    it 'should use default margin if value of margin in theme is empty string' do
      pdf_theme = { page_margin: '' }
      input = 'content'
      prawn = to_pdf input, pdf_theme: pdf_theme, analyze: :document
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      (expect prawn.page_margin).to eql [36, 36, 36, 36]
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 36.0, 793.926]
    end

    it 'should use default margin if value of margin in theme is empty array' do
      pdf_theme = { page_margin: [] }
      input = 'content'
      prawn = to_pdf input, pdf_theme: pdf_theme, analyze: :document
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      (expect prawn.page_margin).to eql [36, 36, 36, 36]
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 36.0, 793.926]
    end

    it 'should coerce margin string values to numbers' do
      pdf_theme = { page_margin: ['0.5in', '0.67in', '0.67in', '0.75in'] }
      input = 'content'
      prawn = to_pdf input, pdf_theme: pdf_theme, analyze: :document
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true

      (expect prawn.page_margin).to eql [36.0, 48.24, 48.24, 54.0]
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 54.0, 793.926]
    end

    it 'should truncate margin array in theme to 4 values' do
      pdf_theme = { page_margin: [36, 24, 28.8, 24, 36, 36] }
      input = 'content'
      prawn = to_pdf input, pdf_theme: pdf_theme, analyze: :document
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true

      (expect prawn.page_margin).to eql [36, 24, 28.8, 24]
      content_text = pdf.text[0]
      (expect content_text.values_at :string, :page_number, :x, :y).to eql ['content', 1, 24.0, 793.926]
      content_top = (get_page_size pdf, 1)[1] - 36
      (expect content_text[:y] + content_text[:font_size]).to be_within(2).of content_top
    end

    it 'should use the margin specified by the pdf-page-margin attribute as array' do
      ['0.5in, 1in, 0.5in, 1in', '36pt, 72pt, 36pt, 72pt'].each do |val|
        pdf = to_pdf <<~EOS, analyze: true
        :pdf-page-margin: [#{val}]

        content
        EOS
        (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 72.0, 793.926]
      end
    end

    it 'should use the margin specified by the pdf-page-margin attribute as string' do
      %w(1in 72pt 25.4mm 2.54cm 96px).each do |val|
        pdf = to_pdf <<~EOS, analyze: true
        :pdf-page-margin: #{val}

        content
        EOS
        (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 72.0, 757.926]
      end
    end

    it 'should split margin specified by the pdf-page-margin attribute as a string and use first 4 values' do
      input = %(:pdf-page-margin: [32.5, 28, 32.5, 28, 36, 36]\n\ncontent)
      prawn = to_pdf input, analyze: :document
      pdf = to_pdf input, analyze: true
      (expect prawn.page_margin).to eql [32.5, 28.0, 32.5, 28.0]
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 28.0, 797.426]
    end

    it 'should use default margin if value of pdf-page-margin is empty array' do
      input = %(:pdf-page-margin: []\n\ncontent)
      prawn = to_pdf input, analyze: :document
      pdf = to_pdf input, analyze: true
      (expect prawn.page_margin).to eql [36, 36, 36, 36]
      (expect pdf.text[0].values_at :string, :page_number, :x, :y).to eql ['content', 1, 36.0, 793.926]
    end

    it 'should use recto/verso margins when media=prepress', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-prepress-margins.pdf', enable_footer: true
      = Book Title
      :media: prepress
      :doctype: book
      // NOTE: setting front-cover-image to ~ informs converter cover page will be inserted by separate process
      :front-cover-image: ~

      == First Chapter

      <<<

      === A Section

      == Last Chapter

      <<<

      === B Section
      EOS

      (expect to_file).to visually_match 'page-prepress-margins.pdf'
    end

    it 'should allow recto/verso margins to be customized by theme when media=prepress', visual: true do
      pdf_theme = {
        page_margin_inner: 72,
        page_margin_outer: 54,
      }
      to_file = to_pdf_file <<~'EOS', 'page-prepress-custom-margins.pdf', pdf_theme: pdf_theme, enable_footer: true
      = Book Title
      :media: prepress
      :doctype: book
      :front-cover-image: ~

      == First Chapter

      <<<

      === A Section

      == Last Chapter

      <<<

      === B Section
      EOS

      (expect to_file).to visually_match 'page-prepress-custom-margins.pdf'
    end

    it 'should disable recto/verso margins when media=prepress if inner/outer margins in theme are nil', visual: true do
      pdf_theme = {
        page_margin_inner: nil,
        page_margin_outer: nil,
      }
      to_file = to_pdf_file <<~'EOS', 'page-prepress-normal-margins.pdf', pdf_theme: pdf_theme, enable_footer: true
      = Book Title
      :media: prepress
      :doctype: book
      :front-cover-image: ~

      == First Chapter

      <<<

      === A Section

      == Last Chapter

      <<<

      === B Section
      EOS

      (expect to_file).to visually_match 'page-prepress-normal-margins.pdf'
    end

    it 'should not apply recto margins to title page of prepress document if no cover is specifed', visual: true do
      pdf_theme = {
        page_margin_inner: 72,
        page_margin_outer: 54,
      }
      to_file = to_pdf_file <<~'EOS', 'page-prepress-margins-no-cover.pdf', pdf_theme: pdf_theme, enable_footer: true
      = Book Title
      :media: prepress
      :doctype: book

      == First Chapter

      <<<

      === A Section

      == Last Chapter

      <<<

      === B Section
      EOS

      (expect to_file).to visually_match 'page-prepress-margins-no-cover.pdf'
    end

    it 'should apply recto margins to first page of prepress document if not title page or cover', visual: true do
      pdf_theme = {
        page_margin_inner: 72,
        page_margin_outer: 54,
      }
      to_file = to_pdf_file <<~'EOS', 'page-prepress-margins-body-only.pdf', pdf_theme: pdf_theme, enable_footer: true
      :media: prepress
      :doctype: book

      == First Chapter

      <<<

      === A Section

      == Last Chapter

      <<<

      === B Section
      EOS

      (expect to_file).to visually_match 'page-prepress-margins-body-only.pdf'
    end

    it 'should invert recto/verso margins when pdf-folio-placement is inverted' do
      pdf_theme = {
        page_margin_inner: 72,
        page_margin_outer: 54,
        footer_recto_right_content: nil,
        footer_recto_left_content: 'page {page-number}',
        footer_verso_right_content: nil,
        footer_verso_left_content: 'p{page-number}',
        footer_padding: [6, 0, 0, 0],
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Book Title
      :media: prepress
      :doctype: book
      :pdf-folio-placement: physical-inverted

      == First Chapter

      content

      <<<

      more content

      == Last Chapter

      content
      EOS

      first_chapter_text = pdf.find_unique_text 'First Chapter'
      (expect first_chapter_text[:page_number]).to eql 3
      (expect first_chapter_text[:x]).to eql 54.0
      pgnum_1_text = pdf.find_unique_text 'p1'
      (expect pgnum_1_text[:x]).to eql 54.0
      (expect pgnum_1_text[:page_number]).to eql 3
      more_content_text = pdf.find_unique_text 'more content'
      (expect more_content_text[:x]).to eql 72.0
      (expect more_content_text[:page_number]).to eql 4
      pgnum_2_text = pdf.find_unique_text 'page 2'
      (expect pgnum_2_text[:x]).to eql 72.0
      (expect pgnum_2_text[:page_number]).to eql 4
      last_chapter_text = pdf.find_unique_text 'Last Chapter'
      (expect last_chapter_text[:x]).to eql 54.0
      (expect last_chapter_text[:page_number]).to eql 5
      pgnum_3_text = pdf.find_unique_text 'p3'
      (expect pgnum_3_text[:x]).to eql 54.0
      (expect pgnum_3_text[:page_number]).to eql 5
    end
  end

  context 'Columns' do
    it 'should ignore columns for book doctype' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 2 }, analyze: true
      = Document Title
      :doctype: book
      :notitle:

      [.text-right]
      first page

      <<<

      second page
      EOS

      midpoint = (get_page_size pdf)[0] * 0.5
      (expect pdf.pages).to have_size 2
      (expect (pdf.find_unique_text 'first page')[:page_number]).to eql 1
      (expect (pdf.find_unique_text 'first page')[:x]).to be > midpoint
      (expect (pdf.find_unique_text 'second page')[:page_number]).to eql 2
    end

    it 'should ignore columns if less than 2' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 1 }, analyze: true
      = Document Title
      :notitle:

      first page

      <<<

      second page
      EOS

      (expect pdf.pages).to have_size 2
      (expect (pdf.find_unique_text 'first page')[:page_number]).to eql 1
      (expect (pdf.find_unique_text 'second page')[:page_number]).to eql 2
    end

    it 'should arrange article body into columns' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 2 }, analyze: true
      first column

      <<<

      second column

      <<<

      [.text-right]
      first column again
      EOS

      midpoint = (get_page_size pdf)[0] * 0.5
      (expect pdf.pages).to have_size 2
      (expect (pdf.find_unique_text 'first column')[:page_number]).to eql 1
      (expect (pdf.find_unique_text 'second column')[:page_number]).to eql 1
      (expect (pdf.find_unique_text 'second column')[:x]).to be > midpoint
      (expect (pdf.find_unique_text 'first column again')[:page_number]).to eql 2
      (expect (pdf.find_unique_text 'first column again')[:x]).to be < midpoint
    end

    it 'should put footnotes at bottom of last column with content' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 2 }, analyze: true
      first columnfootnote:[This page has two columns.]

      <<<

      second column
      EOS

      midpoint = (get_page_size pdf)[0] * 0.5
      (expect pdf.pages).to have_size 1
      (expect (pdf.find_unique_text 'second column')[:x]).to be > midpoint
      right_column_text = pdf.text.select {|it| it[:x] > midpoint }
      right_column_lines = pdf.lines right_column_text
      (expect right_column_lines).to have_size 2
      (expect right_column_lines[-1]).to eql '[1] This page has two columns.'
    end

    it 'should place document title outside of column box' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 2 }, analyze: true
      = Article Title Goes Here

      first column

      <<<

      second column
      EOS

      midpoint = (get_page_size pdf)[0] * 0.5
      (expect pdf.pages).to have_size 1
      title_text = pdf.find_unique_text 'Article Title Goes Here'
      (expect title_text[:x]).to be < midpoint
      (expect title_text[:x] + title_text[:width]).to be > midpoint
      (expect (pdf.find_unique_text 'second column')[:x]).to be > midpoint
    end

    it 'should place TOC outside of column box' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 2 }, analyze: true
      = Article Title Goes Here
      :toc:

      == First Column

      <<<

      == Second Column
      EOS

      midpoint = (get_page_size pdf)[0] * 0.5
      (expect pdf.pages).to have_size 1
      first_column_text = (pdf.find_text 'First Column').sort_by {|it| -it[:y] }
      second_column_text = (pdf.find_text 'Second Column').sort_by {|it| -it[:y] }
      (expect first_column_text[0][:x]).to eql 48.24
      (expect first_column_text[1][:x]).to eql 48.24
      (expect second_column_text[0][:x]).to eql 48.24
      (expect second_column_text[1][:x]).to be > midpoint
      dots_text = pdf.text.select {|it| it[:string].include? '.' }
      dots_text.each do |it|
        (expect it[:x]).to be < midpoint
        (expect it[:x] + it[:width]).to be > midpoint
      end
    end

    it 'should allow theme to control number of columns' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 4 }, analyze: true
      one

      <<<

      two

      <<<

      three

      <<<<

      four
      EOS

      midpoint = (get_page_size pdf)[0] * 0.5
      (expect pdf.pages).to have_size 1
      one_text = pdf.find_unique_text 'one'
      two_text = pdf.find_unique_text 'two'
      three_text = pdf.find_unique_text 'three'
      four_text = pdf.find_unique_text 'four'
      (expect two_text[:x]).to be > one_text[:x]
      (expect two_text[:x]).to be < midpoint
      (expect four_text[:x]).to be > three_text[:x]
      (expect three_text[:x]).to be > midpoint
    end

    it 'should allow theme to control column gap' do
      pdf = to_pdf <<~'EOS', pdf_theme: { page_columns: 2, page_column_gap: 12 }, analyze: :image
      image::square.png[pdfwidth=100%]

      <<<

      image::square.png[pdfwidth=100%]
      EOS

      images = pdf.images
      (expect images).to have_size 2
      column_gap = (images[1][:x] - (images[0][:x] + images[0][:width])).to_f
      (expect column_gap).to eql 12.0
    end
  end

  context 'Background' do
    it 'should set page background to white if value is not defined or transparent', visual: true do
      [nil, 'transparent'].each do |bg_color|
        to_file = to_pdf_file <<~'EOS', %(page-background-color-#{bg_color || 'undefined'}.pdf), pdf_theme: { page_background_color: bg_color }
        = Document Title
        :doctype: book

        content
        EOS

        (expect to_file).to visually_match 'page-background-color-default.pdf'
      end
    end

    it 'should set page background color specified by page_background_color key in theme', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-color.pdf', pdf_theme: { page_background_color: 'ECFBF4' }
      = Document Title
      :doctype: book

      content
      EOS

      (expect to_file).to visually_match 'page-background-color.pdf'
    end

    it 'should set the background image using target of macro specified in page-background-image attribute', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-inline-macro.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:bg.png[]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should use remote image specified by page-background-image attribute as page background', visual: true do
      with_local_webserver do |base_url|
        [%(#{base_url}/bg.png), %(image:#{base_url}/bg.png[])].each_with_index do |image_url, idx|
          to_file = output_file %(page-background-image-remote-#{idx}.pdf)
          doc = to_pdf <<~EOS, analyze: :document, to_file: to_file, attribute_overrides: { 'allow-uri-read' => '' }
          = Document Title
          :doctype: book
          :page-background-image: #{image_url}

          content
          EOS

          (expect to_file).to visually_match 'page-background-image.pdf'
          # NOTE: we could assert no log messages instead, but that assumes the remove_tmp_files method is even called
          (expect doc.converter.instance_variable_get :@tmp_files).to be_empty
        end
      end
    end

    it 'should use remote image specified in theme as page background', visual: true do
      with_local_webserver do |base_url|
        [%(#{base_url}/bg.png), %(image:#{base_url}/bg.png[])].each_with_index do |image_url, idx|
          to_file = to_pdf_file <<~EOS, %(page-background-image-remote-#{idx}.pdf), attribute_overrides: { 'allow-uri-read' => '' }, pdf_theme: { page_background_image: image_url }
          = Document Title
          :doctype: book

          content
          EOS

          (expect to_file).to visually_match 'page-background-image.pdf'
        end
      end
    end

    it 'should use data URI specified by page-background-image attribute as page background', visual: true do
      image_data = File.binread fixture_file 'square.png'
      encoded_image_data = Base64.strict_encode64 image_data
      to_file = to_pdf_file <<~EOS, %(page-background-image-attr-data-uri.pdf)
      = Document Title
      :page-background-image: image:data:image/png;base64,#{encoded_image_data}[fit=fill]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-fill.pdf'
    end

    it 'should use data URI specified in theme as page background', visual: true do
      image_data = File.binread fixture_file 'square.png'
      encoded_image_data = Base64.strict_encode64 image_data
      pdf_theme = { page_background_image: %(image:data:image/png;base64,#{encoded_image_data}[fit=fill]) }
      to_file = to_pdf_file <<~EOS, %(page-background-image-attr-data-uri.pdf), pdf_theme: pdf_theme
      = Document Title

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-fill.pdf'
    end

    it 'should resolve background image in theme relative to theme dir', visual: true do
      [true, false].each do |macro|
        pdf_theme = {
          __dir__: fixtures_dir,
          page_background_image: (macro ? 'image:bg.png[]' : 'bg.png'),
        }
        to_file = to_pdf_file <<~'EOS', %(page-background-image-#{macro ? 'macro' : 'bare'}.pdf), pdf_theme: pdf_theme
        = Document Title
        :doctype: book

        content
        EOS

        (expect to_file).to visually_match 'page-background-image.pdf'
      end
    end

    it 'should resolve background image in theme relative to themesdir in classloader', if: RUBY_ENGINE == 'jruby' do
      require fixture_file 'pdf-themes.jar'
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => 'uri:classloader:/pdf-themes/page-background-image-theme.yml' }
      = Document Title
      :doctype: book

      content
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
    end

    it 'should resolve background image with absolute path for theme loaded from classloader', if: RUBY_ENGINE == 'jruby' do
      require fixture_file 'pdf-themes.jar'
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => 'uri:classloader:/pdf-themes/page-background-image-from-fixturesdir-theme.yml', 'fixturesdir' => fixtures_dir }
      = Document Title
      :doctype: book

      content
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
    end

    it 'should resolve background image in theme relative to themesdir', visual: true do
      attribute_overrides = {
        'pdf-theme' => 'page-background-image',
        'pdf-themesdir' => fixtures_dir,
      }
      to_file = to_pdf_file <<~'EOS', 'page-background-image-bare-in-theme-file.pdf', attribute_overrides: attribute_overrides
      = Document Title
      :doctype: book

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should allow both background color and image to be set concurrently', visual: true do
      pdf_theme = {
        page_background_color: 'F9F9F9',
        page_background_image: %(image:#{fixture_file 'tux.png'}[fit=none,pdfwidth=50%]),
      }
      to_file = to_pdf_file '{blank}', 'page-background-color-and-image.pdf', pdf_theme: pdf_theme

      (expect to_file).to visually_match 'page-background-color-and-image.pdf'
    end

    it 'should resolve attribute reference in image path in theme', visual: true do
      pdf_theme = {
        page_background_color: 'F9F9F9',
        page_background_image: 'image:{docdir}/tux.png[fit=none,pdfwidth=50%]',
      }
      to_file = to_pdf_file '{blank}', 'page-background-color-and-image-relative-to-docdir.pdf', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }

      (expect to_file).to visually_match 'page-background-color-and-image.pdf'
    end

    it 'should only substitute attributes in image path in theme', visual: true do
      pdf_theme = {
        page_background_color: 'F9F9F9',
        page_background_image: 'image:{docdir}/tux--classic.png[fit=none,pdfwidth=50%]',
      }
      to_file = to_pdf_file '{blank}', 'page-background-color-and-image-relative-to-docdir-no-replacements.pdf', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }

      (expect to_file).to visually_match 'page-background-color-and-image.pdf'
    end

    it 'should recognize attribute value that use block macro syntax', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-block-macro.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:bg.png[]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should not crash if background image is a URI and the allow-uri-read attribute is not set' do
      (expect do
        to_pdf <<~'EOS'
        = Document Title
        :page-background-image: image:https://example.org/bg.svg[]

        content
        EOS
      end).to not_raise_exception & (log_message severity: :WARN, message: '~allow-uri-read attribute not enabled')
    end

    it 'should set the background image using path specified in page-background-image attribute', visual: true do
      to_file = to_pdf_file <<~EOS, 'page-background-image-path.pdf'
      = Document Title
      :doctype: book
      :page-background-image: #{fixture_file 'bg.png', relative: true}

      content
      EOS

      (expect to_file).to visually_match 'page-background-image.pdf'
    end

    it 'should scale background image until it reaches shortest side', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-max-height.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:square.png[]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-max-height.pdf'
    end

    it 'should set width of background image according to width attribute when fit=none', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-width.pdf'
      = Document Title
      :page-background-image: image:square.png[bg,200,fit=none]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-width.pdf'
    end

    it 'should scale down background PNG to fit boundaries of page if fit is scale-down and width slightly exceeds available width', visual: true do
      reference_file = to_pdf_file <<~'EOS', 'page-background-image-fit-scale-down-reference.pdf'
      = Document Title
      :page-background-image: image:wide.png[fit=contain]

      content
      EOS

      to_file = to_pdf_file <<~'EOS', 'page-background-image-fit-scale-down-slightly.pdf'
      = Document Title
      :page-background-image: image:wide.png[fit=scale-down]

      content
      EOS

      (expect to_file).to visually_match reference_file
    end

    it 'should scale up background SVG to fit boundaries of page if value is path', visual: true do
      to_file = to_pdf_file <<~EOS, 'page-background-image-svg-scale-up-from-path.pdf'
      = Document Title
      :page-background-image: #{fixture_file 'square.svg', relative: true}

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if value is macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-scale-up-from-macro.pdf'
      = Document Title
      :page-background-image: image:square.svg[]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if fit is contain', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-contain.pdf'
      = Document Title
      :page-background-image: image:square.svg[fit=contain]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if fit is fill', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-fill.pdf'
      = Document Title
      :page-background-image: image:square.svg[fit=fill]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    end

    it 'should scale up background SVG to fit boundaries of page if pdfwidth is 100% and fit=none', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-pdfwidth.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:square.svg[fit=none,pdfwidth=100%]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-contain.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if value is path', visual: true do
      to_file = to_pdf_file <<~EOS, 'page-background-image-svg-scale-down-from-path.pdf'
      = Document Title
      :page-background-image: #{fixture_file 'example-stamp.svg', relative: true}

      This page has a background image.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if value is macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-scale-down-from-macro.pdf'
      = Document Title
      :page-background-image: image:example-stamp.svg[]

      This page has a background image.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if fit is scale-down', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-scale-down.pdf'
      = Document Title
      :page-background-image: image:example-stamp.svg[fit=scale-down]

      This page has a background image.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-down.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if fit is scale-down and width slightly exceeds available width', visual: true do
      reference_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-scale-down-reference.pdf'
      = Document Title
      :page-background-image: image:wide.svg[fit=contain]

      content
      EOS

      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-scale-down-slightly.pdf'
      = Document Title
      :page-background-image: image:wide.svg[fit=scale-down]

      content
      EOS

      (expect to_file).to visually_match reference_file
    end

    it 'should scale down background SVG to fit boundaries of page if computed height is greater than page height', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-scale-down-computed-height.pdf'
      :pdf-page-size: A6
      :page-background-image: image:tall.svg[pdfwidth=200,fit=scale-down]
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-fit-scale-down-height.pdf'
    end

    it 'should scale down background SVG to fit boundaries of page if intrinsic height is greater than page height', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-scale-down-intrinsic-height.pdf'
      :pdf-page-size: A6
      :page-background-image: image:tall.svg[fit=scale-down]
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-fit-scale-down-height.pdf'
    end

    it 'should not scale background SVG with explicit width to fit boundaries of page if fit is scale-down and image fits', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-prescaled.pdf'
      = Document Title
      :pdf-page-layout: landscape
      :page-background-image: image:green-bar.svg[pdfwidth=50%,fit=scale-down]

      This page has a background image.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-prescaled.pdf'
    end

    it 'should not scale background image without explicit width to fit boundaries of page if fit is scale-down and image fits' do
      pdf = to_pdf <<~'EOS', analyze: :image
      = Document Title
      :page-background-image: image:square.png[fit=scale-down]

      This page has a background image.
      EOS

      (expect pdf.images).to have_size 1
      bg_image = pdf.images[0]
      (expect bg_image[:width]).to eql 12.0
      (expect bg_image[:height]).to eql 12.0
    end

    it 'should not scale background SVG to fit boundaries of page if fit is none', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-fit-none.pdf'
      = Document Title
      :page-background-image: image:example-stamp.svg[fit=none]

      This page has a background image.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-unscaled.pdf'
    end

    it 'should scale up background SVG until it covers page if fit=cover', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-cover.pdf'
      = Document Title
      :page-background-image: image:square.svg[fit=cover]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-cover.pdf'
    end

    it 'should scale background PNG to fill page if fit=fill', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-fill.pdf'
      = Document Title
      :page-background-image: image:square.png[fit=fill]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-fill.pdf'
    end

    it 'should allow remote image in SVG to be read if allow-uri-read attribute is set', visual: true, network: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-with-remote-image.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      :page-background-image: image:svg-with-remote-image.svg[fit=none,position=top]

      Asciidoctor
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-with-image.pdf'
    end

    it 'should not allow remote image in SVG to be read if allow-uri-read attribute is not set', visual: true do
      (expect do
        to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-with-remote-image-disabled.pdf'
        :page-background-image: image:svg-with-remote-image.svg[fit=none,position=top]

        Asciidoctor
        EOS

        (expect to_file).to visually_match 'page-background-image-svg-with-image-disabled.pdf'
      end).to log_message severity: :WARN, message: '~No handler available for this URL scheme'
    end

    it 'should not warn if background SVG has warnings', visual: true do
      (expect do
        to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-faulty.pdf'
        = Document Title
        :page-background-image: image:faulty.svg[]

        This page has a background image that is rather loud.
        EOS
        (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
      end).to log_message severity: :WARN, message: %(~problem encountered in image: #{fixture_file 'faulty.svg'}; Unknown tag 'foobar')
    end

    it 'should read local image relative to SVG', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-svg-with-local-image.pdf'
      :page-background-image: image:svg-with-local-image.svg[fit=none,pdfwidth=1cm,position=top]

      Asciidoctor
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-with-image.pdf'
    end

    it 'should position background image according to value of position attribute on macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-position.pdf'
      = Document Title
      :page-background-image: image:example-stamp.svg[fit=none,pdfwidth=50%,position=bottom center]

      content
      EOS

      (expect to_file).to visually_match 'page-background-image-position.pdf'
    end

    it 'should position page background in center if position value is unrecognized' do
      pdf = to_pdf <<~'EOS', analyze: :image
      = Document Title
      :page-background-image: image:tux.png[fit=none,pdfwidth=4in,position=center]

      content
      EOS

      bg_image = pdf.images[0]
      center_coords = [bg_image[:x], bg_image[:y]]

      ['droit', 'haut droit'].each do |position|
        pdf = to_pdf <<~EOS, analyze: :image
        = Document Title
        :page-background-image: image:tux.png[fit=none,pdfwidth=4in,position=#{position}]

        content
        EOS

        bg_image = pdf.images[0]
        actual_coords = [bg_image[:x], bg_image[:y]]
        (expect actual_coords).to eql center_coords
      end
    end

    it 'should alternate page background if both verso and recto background images are specified', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt.pdf'
      = Document Title
      :doctype: book
      :page-background-image-recto: image:recto-bg.png[]
      :page-background-image-verso: image:verso-bg.png[]

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt.pdf'
    end

    it 'should swap recto and verso background images when pdf-folio-placement is inverted', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt.pdf'
      = Document Title
      :doctype: book
      :page-background-image-recto: image:verso-bg.png[]
      :page-background-image-verso: image:recto-bg.png[]
      :pdf-folio-placement: physical-inverted

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt.pdf'
    end

    it 'should alternate page background in landscape if both verso and recto background images are specified', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt-landscape.pdf'
      = Document Title
      :doctype: book
      :pdf-page-layout: landscape
      :page-background-image-recto: image:recto-bg-landscape.png[]
      :page-background-image-verso: image:verso-bg-landscape.png[]

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt-landscape.pdf'
    end

    it 'should use background image as fallback if background image for side not specified', visual: true do
      to_file = to_pdf_file <<~'EOS', 'page-background-image-alt.pdf'
      = Document Title
      :doctype: book
      :page-background-image: image:recto-bg.png[]
      :page-background-image-verso: image:verso-bg.png[]

      content

      <<<

      more content

      <<<

      the end
      EOS

      (expect to_file).to visually_match 'page-background-image-alt.pdf'
    end

    it 'should allow recto background image to be disabled if side is set to none', visual: true do
      [
        { 'page-background-image' => 'image:recto-bg.png[]', 'page-background-image-verso' => 'none' },
        { 'page-background-image-recto' => 'image:recto-bg.png[]' },
      ].each do |attribute_overrides|
        to_file = to_pdf_file <<~'EOS', 'page-background-image-recto-only.pdf', attribute_overrides: attribute_overrides
        = Document Title
        :doctype: book

        content

        <<<

        more content

        <<<

        the end
        EOS

        (expect to_file).to visually_match 'page-background-image-recto-only.pdf'
      end
    end

    it 'should allow verso background image to be disabled if side is set to none', visual: true do
      [
        { 'page-background-image' => 'image:verso-bg.png[]', 'page-background-image-recto' => 'none' },
        { 'page-background-image-verso' => 'image:verso-bg.png[]' },
      ].each do |attribute_overrides|
        to_file = to_pdf_file <<~'EOS', 'page-background-image-verso-only.pdf', attribute_overrides: attribute_overrides
        = Document Title
        :doctype: book

        content

        <<<

        more content

        <<<

        the end
        EOS

        (expect to_file).to visually_match 'page-background-image-verso-only.pdf'
      end
    end

    it 'should use the specified image format', visual: true do
      source_file = (dest_file = fixture_file 'square') + '.svg'
      FileUtils.cp source_file, dest_file
      to_file = to_pdf_file <<~'EOS', 'page-background-image-format.pdf'
      = Document Title
      :page-background-image: image:square[format=svg]

      This page has a background image that is rather loud.
      EOS

      (expect to_file).to visually_match 'page-background-image-svg-scale-up.pdf'
    ensure
      File.unlink dest_file
    end

    it 'should warn instead of crash if image is unreadable' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: :image
        = Document Title
        :page-background-image: image:does-not-exist.png[fit=cover]

        content
        EOS
        (expect pdf.images).to be_empty
      end).to log_message severity: :WARN, message: '~page background image not found or readable'
    end

    it 'should warn instead of crash if background image is invalid' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: :image
        = Document Title
        :page-background-image: image:corrupt.png[fit=cover]

        content
        EOS
        (expect pdf.images).to be_empty
      end).to log_message severity: :WARN, message: '~image file is an unrecognised format'
    end

    it 'should warn instead of crash if background image cannot be parsed' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: :image
        = Document Title
        :page-background-image: image:broken.svg[fit=cover]

        content
        EOS
        (expect pdf.images).to be_empty
      end).to log_message severity: :WARN, message: %(~Missing end tag for 'rect')
    end

    it 'should only warn once if background image cannot be loaded' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: :image
        = Document Title
        :page-background-image: image:corrupt.png[fit=cover]

        content

        <<<

        more content

        <<<

        even more content
        EOS
        (expect pdf.images).to be_empty
      end).to log_message severity: :WARN, message: '~image file is an unrecognised format'
    end

    it 'should still render different facing background image when background image cannot be loaded' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: :image
        = Document Title
        :page-background-image: image:corrupt.png[fit=cover]
        :page-background-image-verso: image:bg.png[]

        content

        <<<

        more content

        <<<

        even more content
        EOS
        (expect pdf.images).to have_size 1
        (expect pdf.images[0][:page_number]).to be 2
      end).to log_message severity: :WARN, message: '~image file is an unrecognised format'
    end

    it 'should support PDF as background image', visual: true do
      # NOTE: the running content is automatically disabled since this becomes an imported page
      to_file = to_pdf_file <<~'EOS', 'page-background-image-pdf.pdf', enable_footer: true
      :page-background-image-recto: image:tux-bg.pdf[]

      Tux has left his mark on this page.

      <<<

      But not on this page.
      EOS

      (expect to_file).to visually_match 'page-background-image-pdf.pdf'
    end

    it 'should only warn once if PDF for background image cannot be found' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: :image
        = Document Title
        :page-background-image: image:no-such-file.pdf[]

        content

        <<<

        more content

        <<<

        even more content
        EOS
        (expect pdf.images).to be_empty
      end).to log_message severity: :WARN, message: '~page background image not found or readable'
    end
  end

  context 'Watermark' do
    it 'should stamp watermark image on the top of all pages if page-foreground-image is specified', visual: true do
      to_file = to_pdf_file <<~EOS, 'page-watermark.pdf'
      = Document Title
      :doctype: book
      :page-foreground-image: image:watermark.svg[]

      [.text-left]
      #{['lots of rambling'] * 150 * ?\n}

      <<<

      [.text-left]
      #{['lots of rambling'] * 150 * ?\n}
      EOS

      (expect to_file).to visually_match 'page-watermark.pdf'
    end

    it 'should no apply watermark image to front cover, back cover, or imported page', visual: true do
      to_file = to_pdf_file <<~EOS, 'page-watermark-content-only.pdf'
      = Document Title
      :doctype: book
      :front-cover-image: image:cover.jpg[]
      :back-cover-image: image:cover.jpg[]
      :page-foreground-image: image:watermark.svg[]
      :notitle:

      [.text-left]
      #{['lots of rambling'] * 150 * ?\n}

      image::red-green-blue.pdf[page=1]

      [.text-left]
      #{['lots of rambling'] * 150 * ?\n}
      EOS

      (expect to_file).to visually_match 'page-watermark-content-only.pdf'
    end
  end
end
