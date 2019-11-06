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

    it 'should display author names under document title' do
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      Doc Writer; Junior Writer
      :doctype: book

      body
      EOS

      title_page_lines = pdf.lines(pdf.find_text page_number: 1)
      (expect title_page_lines).to eql ['Document Title', 'Doc Writer, Junior Writer']
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

    it 'should position logo using value of top attribute on image macro in title-logo-image attribute' do
      pdf = to_pdf <<~'EOS', analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left,top=0vh]
      EOS

      left_margin = 0.67 * 72
      page_height = 841.89 # ~11.69in

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:page_number]).to eql 1
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:y]).to eql page_height
    end

    it 'should align logo using value of align attribute specified on image macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'document-title-logo-align-attribute.pdf'
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]
      EOS

      (expect to_file).to visually_match 'document-title-logo-align-left.pdf'
    end

    it 'should ignore align attribute on logo macro if value is invalid', visual: true do
      to_file = to_pdf_file <<~'EOS', 'document-title-logo-align-invalid.pdf', pdf_theme: { title_page_logo_align: 'left' }
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=foo]
      EOS

      (expect to_file).to visually_match 'document-title-logo-align-left.pdf'
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

  context 'theming' do
    it 'should allow theme to customize content of authors line' do
      pdf = to_pdf <<~'EOS', pdf_theme: { title_page_authors_content: '{url}[{author}]' }
      = Document Title
      Doc Writer <doc@example.org>; Junior Writer <https://github.com/ghost>
      :doctype: book

      body
      EOS

      (expect (pdf.page 1).text).to include 'Doc Writer, Junior Writer'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 2
      author1_annotation = annotations[0]
      (expect author1_annotation[:Subtype]).to eql :Link
      (expect author1_annotation[:A][:URI]).to eql 'mailto:doc@example.org'
      author2_annotation = annotations[1]
      (expect author2_annotation[:Subtype]).to eql :Link
      (expect author2_annotation[:A][:URI]).to eql 'https://github.com/ghost'
    end

    it 'should allow theme to customize content of authors line by available metadata' do
      pdf_theme = {
        title_page_authors_content_name_only: '{authorinitials}',
        title_page_authors_content_with_email: '{lastname}, {firstname} <{email}>',
        title_page_authors_content_with_url: '{url}[{author}]',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
      = Document Title
      Doc Writer <doc@example.org>; Junior Writer <https://github.com/ghost>; Jane Doe
      :doctype: book

      body
      EOS

      (expect (pdf.page 1).text).to include 'Writer, Doc <doc@example.org>, Junior Writer, JD'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 2
      author1_annotation = annotations[0]
      (expect author1_annotation[:Subtype]).to eql :Link
      (expect author1_annotation[:A][:URI]).to eql 'mailto:doc@example.org'
      author2_annotation = annotations[1]
      (expect author2_annotation[:Subtype]).to eql :Link
      (expect author2_annotation[:A][:URI]).to eql 'https://github.com/ghost'
    end

    it 'should allow theme to customize style of link in authors line using custom role' do
      attributes = asciidoctor_1_5_7_or_better? ? {} : { 'linkattrs' => '' }
      pdf_theme = {
        role_author_font_color: '00AA00',
        title_page_authors_content: '{url}[{author},role=author]',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, attribute_overrides: attributes, analyze: true
      = Document Title
      Junior Writer <https://github.com/ghost>
      :doctype: book

      body
      EOS

      author_text = (pdf.find_text 'Junior Writer')[0]
      (expect author_text[:font_color]).to eql '00AA00'
    end

    it 'should be able to use an icon in an author entry' do
      pdf_theme = {
        title_page_authors_content: '{author} {url}[icon:twitter[]]',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      = Document Title
      Doc Writer <https://twitter.com/asciidoctor>
      :icons: font
      :doctype: book

      body
      EOS

      title_page_lines = pdf.lines(pdf.find_text page_number: 1)
      (expect title_page_lines).to include %(Doc Writer \uf099)
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

    it 'should move logo down from top margin of page by % value of title_page_logo_top key' do
      pdf_theme = {
        title_page_logo_top: '10%',
      }

      pdf = to_pdf <<~'EOS', analyze: :image, pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]

      image::tux.png[]
      EOS

      left_margin = 0.67 * 72
      top_margin = 0.5 * 72
      bottom_margin = 0.67 * 72
      page_height = 841.89 # ~11.69in

      images = pdf.images
      (expect images).to have_size 2
      title_page_image = images[0]
      reference_image = images[1]
      (expect title_page_image[:page_number]).to eql 1
      (expect reference_image[:page_number]).to eql 2
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:x]).to eql reference_image[:x]
      effective_page_height = page_height - top_margin - bottom_margin
      expected_top = reference_image[:y] - (effective_page_height * 0.10)
      (expect title_page_image[:y]).to eql expected_top
    end

    it 'should move logo down from top margin of page by pt value of title_page_logo_top key' do
      pdf_theme = {
        title_page_logo_top: '20pt',
      }

      pdf = to_pdf <<~'EOS', analyze: :image, pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]

      image::tux.png[]
      EOS

      left_margin = 0.67 * 72

      images = pdf.images
      (expect images).to have_size 2
      title_page_image = images[0]
      reference_image = images[1]
      (expect title_page_image[:page_number]).to eql 1
      (expect reference_image[:page_number]).to eql 2
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:x]).to eql reference_image[:x]
      expected_top = reference_image[:y] - 20
      (expect title_page_image[:y]).to eql expected_top
    end

    it 'should move logo down from top of page by vh value of title_page_logo_top key' do
      pdf_theme = {
        title_page_logo_top: '5vh',
      }

      pdf = to_pdf <<~'EOS', analyze: :image, pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]
      EOS

      left_margin = 0.67 * 72
      page_height = 841.89 # ~11.69in

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:page_number]).to eql 1
      (expect title_page_image[:x]).to eql left_margin
      expected_top = page_height - (page_height * 0.05)
      (expect title_page_image[:y]).to eql expected_top
    end

    it 'should move title down from top margin by % value of title_page_title_top key' do
      pdf_theme = {
        title_page_title_top: '10%',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      content
      EOS

      page_height = 841.89 # ~11.69in
      top_margin = 0.5 * 72
      bottom_margin = 0.67 * 72

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to eql 1
      effective_page_height = page_height - top_margin - bottom_margin
      expected_top = page_height - top_margin - (effective_page_height * 0.10)
      (expect doctitle_text[:y] + doctitle_text[:font_size]).to be_within(0.5).of(expected_top)
    end

    it 'should move title down from top margin by pt value of title_page_title_top key' do
      pdf_theme = {
        title_page_title_top: '20pt',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      content
      EOS

      page_height = 841.89 # ~11.69in
      top_margin = 0.5 * 72

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to eql 1
      expected_top = page_height - top_margin - 20
      (expect doctitle_text[:y] + doctitle_text[:font_size]).to be_within(0.5).of(expected_top)
    end

    it 'should move title down from top of page by vh value of title_page_title_top key' do
      pdf_theme = {
        title_page_title_top: '0vh',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      content
      EOS

      page_height = 841.89 # ~11.69in

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to eql 1
      (expect doctitle_text[:y] + doctitle_text[:font_size]).to be_within(0.5).of(page_height)
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

    it 'should allow theme to disable elements on title page' do
      pdf_theme = {
        title_page_subtitle_display: 'none',
        title_page_authors_display: 'none',
        title_page_revision_display: 'none',
        title_page_logo_display: 'none',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
      = Document Title: Subtitle
      :doctype: book
      :title-logo-image: image:tux.png[]
      Author Name
      v1.0, 2020-01-01

      first page of content
      EOS

      (expect pdf.pages).to have_size 2
      (expect (pdf.page 1).text).to eql 'Document Title'
      (expect get_images pdf, 1).to be_empty
    end

    it 'should not remove title page if all elements are disabled' do
      pdf_theme = {
        title_page_title_display: 'none',
        title_page_subtitle_display: 'none',
        title_page_authors_display: 'none',
        title_page_revision_display: 'none',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
      = Document Title: Subtitle
      :doctype: book
      :title-page-background-image: image:cover.jpg[]
      Author Name
      v1.0, 2020-01-01

      first page of content
      EOS

      (expect pdf.pages).to have_size 2
      title_page_text = (pdf.page 1).text
      (expect title_page_text).to be_empty

      image_data = File.binread fixture_file 'cover.jpg'
      title_page_images = get_images pdf, 1
      (expect title_page_images).to have_size 1
      (expect title_page_images[0].data).to eql image_data
    end
  end
end
