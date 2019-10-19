require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Document Title' do
  context 'book' do
    it 'should place document title on title page for doctype book' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
      = Document Title

      body
      EOS

      (expect pdf.pages).to have_size 2
      text = pdf.text
      (expect text).to have_size 2
      (expect pdf.pages[0][:text]).to have_size 1
      doctitle_text = pdf.pages[0][:text][0]
      (expect doctitle_text[:string]).to eql 'Document Title'
      (expect doctitle_text[:font_size]).to eql 27
      (expect pdf.pages[1][:text]).to have_size 1
    end

    it 'should create document with only a title page if body is empty' do
      pdf = to_pdf '= Title Page Only', doctype: :book, analyze: true
      (expect pdf.pages).to have_size 1
      (expect pdf.lines).to eql ['Title Page Only']
    end

    it 'should not include title page if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', doctype: :book, analyze: :page
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).to_not include 'Document Title'
    end

    it 'should partition the main title and subtitle' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Main Title: Subtitle
      :doctype: book

      body
      EOS

      title_page_texts = pdf.find_text page_number: 1
      (expect title_page_texts).to have_size 2
      main_title_text = title_page_texts[0]
      subtitle_text = title_page_texts[1]
      (expect main_title_text[:string]).to eql 'Main Title'
      (expect main_title_text[:font_color]).to eql '999999'
      (expect main_title_text[:font_name]).to eql 'NotoSerif'
      (expect subtitle_text[:string]).to eql 'Subtitle'
      (expect subtitle_text[:font_color]).to eql '333333'
      (expect subtitle_text[:font_name]).to eql 'NotoSerif-BoldItalic'
      (expect subtitle_text[:y]).to be < main_title_text[:y]
    end

    it 'should include revision number, date, and remark on title page' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      Author Name
      v1.0, 2019-01-01: Draft
      :doctype: book
      EOS

      (expect pdf.lines).to include 'Version 1.0, 2019-01-01: Draft'
    end

    it 'should allow delimiter for authors and revision info to be set' do
      pdf_theme = {
        title_page_authors_delimiter: ' / ',
        title_page_revision_delimiter: ' - ',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      = Document Title
      Doc Writer; Junior Writer
      v1.0, 2019-01-01
      :doctype: book

      content
      EOS

      lines = pdf.lines
      (expect lines).to include 'Doc Writer / Junior Writer'
      (expect lines).to include 'Version 1.0 - 2019-01-01'
    end

    it 'should add logo specified by title-logo-image document attribute to title page' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[]
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to eql 204
      (expect images[0].hash[:Height]).to eql 240
    end

    it 'should add logo specified by title_page_logo_image theme key to title page' do
      pdf = to_pdf <<~'EOS', pdf_theme: { title_page_logo_image: 'image:{docdir}/tux.png[]' }, attribute_overrides: { 'docdir' => fixtures_dir }
      = Document Title
      :doctype: book
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to eql 204
      (expect images[0].hash[:Height]).to eql 240
    end

    it 'should allow left margin of elements on title page to be configured' do
      input = <<~'EOS'
      = Book Title: Bring Out Your Dead Trees
      Author Name
      v1.0, 2001-01-01

      body
      EOS

      theme_overrides = { title_page_align: 'left' }

      pdf = to_pdf input, doctype: :book, pdf_theme: theme_overrides, analyze: true

      expected_x = (pdf.find_text page_number: 1).map {|it| it[:x] + 10 }

      theme_overrides.update \
        title_page_title_margin_left: 10,
        title_page_subtitle_margin_left: 10,
        title_page_authors_margin_left: 10,
        title_page_revision_margin_left: 10

      pdf = to_pdf input, doctype: :book, pdf_theme: theme_overrides, analyze: true

      actual_x = (pdf.find_text page_number: 1).map {|it| it[:x] }
      (expect actual_x).to eql expected_x
    end

    it 'should allow right margin of elements on title page to be configured' do
      input = <<~'EOS'
      = Book Title: Bring Out Your Dead Trees
      Author Name
      v1.0, 2001-01-01

      body
      EOS

      pdf = to_pdf input, doctype: :book, analyze: true

      expected_x = (pdf.find_text page_number: 1).map {|it| it[:x] - 10 }

      theme_overrides = {
        title_page_title_margin_right: 10,
        title_page_subtitle_margin_right: 10,
        title_page_authors_margin_right: 10,
        title_page_revision_margin_right: 10,
      }

      pdf = to_pdf input, doctype: :book, pdf_theme: theme_overrides, analyze: true

      actual_x = (pdf.find_text page_number: 1).map {|it| it[:x] }
      (expect actual_x).to eql expected_x
    end

    it 'should be able to set background color of title page', visual: true do
      theme_overrides = {
        title_page_background_color: '000000',
        title_page_title_font_color: 'EFEFEF',
        title_page_authors_font_color: 'DBDBDB',
      }

      to_file = to_pdf_file <<~'EOS', 'document-title-background-color.pdf', pdf_theme: theme_overrides
      = Dark and Stormy
      Author Name
      :doctype: book

      body
      EOS

      (expect to_file).to visually_match 'document-title-background-color.pdf'
    end

    it 'set background image of title page from title-page-background-image attribute', visual: true do
      pdf = to_pdf <<~'EOS'
      = The Amazing
      Author Name
      :doctype: book
      :title-page-background-image: image:bg.png[]

      beginning

      <<<

      middle

      <<<

      end
      EOS

      (expect pdf.pages).to have_size 4
      [1, 0, 0, 0].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        (expect images).to have_size expected_num_images
      end
    end

    it 'set background image when document has image cover page', visual: true do
      pdf = to_pdf <<~'EOS'
      = The Amazing
      Author Name
      :doctype: book
      :front-cover-image: image:cover.jpg[]
      :title-page-background-image: image:bg.png[]

      beginning

      <<<

      middle

      <<<

      end
      EOS

      (expect pdf.pages).to have_size 5
      [1, 1, 0, 0, 0].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        (expect images).to have_size expected_num_images
      end
    end

    it 'set background image when document has PDF cover page', visual: true do
      pdf = to_pdf <<~'EOS'
      = The Amazing
      Author Name
      :doctype: book
      :front-cover-image: image:blue-letter.pdf[]
      :title-page-background-image: image:tux.png[]
      :page-background-image: image:bg.png[]

      beginning

      <<<

      middle

      <<<

      end
      EOS

      images_by_page = []
      (expect pdf.pages).to have_size 5
      [0, 1, 1, 1, 1].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        images_by_page << images
        (expect images).to have_size expected_num_images
      end

      (expect images_by_page[1][0].data).not_to eql images_by_page[2][0].data
      (expect images_by_page[2..-1].map {|it| it[0].data }.uniq).to have_size 1
    end

    it 'set background color when document has PDF cover page', visual: true do
      pdf = to_pdf <<~'EOS', pdf_theme: { title_page_background_color: 'eeeeee' }
      = The Amazing
      Author Name
      :doctype: book
      :front-cover-image: image:blue-letter.pdf[]
      :title-page-background-image: none
      :page-background-image: image:bg.png[]

      beginning

      <<<

      middle

      <<<

      end
      EOS

      images_by_page = []
      (expect pdf.pages).to have_size 5
      [0, 0, 1, 1, 1].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        images_by_page << images
        (expect images).to have_size expected_num_images
      end

      (expect images_by_page[2..-1].map {|it| it[0].data }.uniq).to have_size 1
    end

    it 'should not use page background on title page if page_background is set to none in theme' do
      pdf_theme = {
        page_background_image: %(image:#{fixture_file 'bg.png'}[]),
        title_page_background_image: 'none',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
      = Document Title
      :doctype: book

      == Chapter 1

      content

      == Chapter 2

      content
      EOS

      (expect pdf.pages).to have_size 3
      (expect get_images pdf, 1).to have_size 0
      (expect get_images pdf, 2).to have_size 1
      (expect get_images pdf, 3).to have_size 1
    end
  end

  context 'article' do
    it 'should center document title at top of first page of content' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title

      body
      EOS

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text).not_to be_nil
      (expect doctitle_text[:page_number]).to eql 1
      body_text = (pdf.find_text 'body')[0]
      (expect body_text).not_to be_nil
      (expect body_text[:page_number]).to eql 1
      (expect doctitle_text[:y]).to be > body_text[:y]
    end

    it 'should align document title according to value of heading_h1_align theme key' do
      pdf = to_pdf <<~'EOS', pdf_theme: { heading_h1_align: 'left' }, analyze: true
      = Document Title

      body
      EOS

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text).not_to be_nil
      body_text = (pdf.find_text 'body')[0]
      (expect body_text).not_to be_nil
      (expect doctitle_text[:x]).to eql body_text[:x]
    end

    it 'should place document title on title page if title-page attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: :page
      = Document Title
      :title-page:

      body
      EOS
      (expect pdf.pages).to have_size 2
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'body'
    end

    it 'should create document with only a title page if body is empty and title-page is set' do
      pdf = to_pdf '= Title Page Only', attribute_overrides: { 'title-page' => '' }, analyze: true
      (expect pdf.pages).to have_size 1
      (expect pdf.lines).to eql ['Title Page Only']
    end

    it 'should not include document title if notitle attribute is set' do
      pdf = to_pdf <<~'EOS', analyze: :page
      = Document Title
      :notitle:

      body
      EOS
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).to_not include 'Document Title'
    end
  end
end
