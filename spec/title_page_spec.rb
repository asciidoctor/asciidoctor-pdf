# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Title Page' do
  context 'book doctype' do
    it 'should not include title page if notitle attribute is set' do
      pdf = to_pdf <<~'END', doctype: :book, analyze: :page
      = Document Title
      :notitle:

      body
      END
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).not_to include 'Document Title'
    end

    it 'should not include title page if title_page key in theme is false' do
      pdf = to_pdf <<~'END', doctype: :book, pdf_theme: { title_page: false }, analyze: :page
      = Document Title

      body
      END
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).not_to include 'Document Title'
    end

    it 'should not include title page if showtitle attribute is unset when Asciidoctor >= 2.0.11' do
      pdf = to_pdf <<~'END', doctype: :book, analyze: :page
      = Document Title
      :!showtitle:

      body
      END
      if (Gem::Version.new Asciidoctor::VERSION) >= (Gem::Version.new '2.0.11')
        (expect pdf.pages[0][:strings]).not_to include 'Document Title'
      else
        (expect pdf.pages[0][:strings]).to include 'Document Title'
      end
    end

    it 'should place document title on title page when doctype is book' do
      pdf = to_pdf <<~'END', doctype: :book, analyze: true
      = Document Title

      body
      END

      (expect pdf.pages).to have_size 2
      text = pdf.text
      (expect text).to have_size 2
      (expect pdf.pages[0][:text]).to have_size 1
      doctitle_text = pdf.pages[0][:text][0]
      (expect doctitle_text[:string]).to eql 'Document Title'
      (expect doctitle_text[:font_size]).to be 27
      (expect pdf.pages[1][:text]).to have_size 1
    end

    it 'should create book with only a title page if doctitle is specified and body is empty' do
      pdf = to_pdf '= Title Page Only', doctype: :book, analyze: true
      (expect pdf.pages).to have_size 1
      (expect pdf.lines).to eql ['Title Page Only']
    end

    it 'should include revision number, date, and remark on title page' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      Author Name
      v1.0, 2019-01-01: Draft
      :doctype: book
      END

      (expect pdf.lines).to include 'Version 1.0, 2019-01-01: Draft'
    end

    it 'should display author names under document title on title page' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      Doc Writer; Antonín Dvořák
      :doctype: book

      body
      END

      title_page_lines = pdf.lines pdf.find_text page_number: 1
      (expect title_page_lines).to eql ['Document Title', 'Doc Writer, Antonín Dvořák']
    end

    it 'should not overwrite url property when promoting authors for use on title page' do
      pdf_theme = {
        title_page_authors_content_with_email: '{author} // {email}',
        title_page_authors_content_with_url: '{author} // {url}',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      Doc Writer <https://example.org/doc>; Junior Writer <jr@example.org>
      :doctype: book
      :url: https://opensource.org

      {url}
      END

      title_page_lines = pdf.lines pdf.find_text page_number: 1
      (expect title_page_lines).to eql ['Document Title', 'Doc Writer // https://example.org/doc, Junior Writer // jr@example.org']
      body_lines = pdf.lines pdf.find_text page_number: 2
      (expect body_lines).to eql %w(https://opensource.org)
    end

    it 'should not carry over url from one author to the next' do
      pdf_theme = { title_page_authors_content_with_url: '{author} // {url}' }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      Doc Writer <https://example.org/doc>; Junior Writer
      :doctype: book
      :url: https://opensource.org

      {url}
      END

      title_page_lines = pdf.lines pdf.find_text page_number: 1
      (expect title_page_lines).to eql ['Document Title', 'Doc Writer // https://example.org/doc, Junior Writer']
      body_lines = pdf.lines pdf.find_text page_number: 2
      (expect body_lines).to eql %w(https://opensource.org)
    end

    it 'should apply base font style when document has title page' do
      pdf = to_pdf <<~'END', pdf_theme: { base_font_style: 'bold' }, analyze: true
      = Document Title
      Author Name
      v1.0, 2020-01-01
      :doctype: book

      bold body
      END

      (expect pdf.pages).to have_size 2
      (expect pdf.text.map {|it| it[:font_name] }.uniq).to eql %w(NotoSerif-Bold)
    end
  end

  context 'title-page attribute' do
    it 'should not include title page if notitle attribute is set' do
      pdf = to_pdf <<~'END', analyze: :page
      = Document Title
      :title-page:
      :notitle:

      what's it gonna do?
      END
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0][:strings]).not_to include 'Document Title'
    end

    it 'should place document title on title page if title-page attribute is set' do
      pdf = to_pdf <<~'END', analyze: :page
      = Document Title
      :title-page:

      body
      END
      (expect pdf.pages).to have_size 2
      (expect pdf.pages[0][:strings]).to include 'Document Title'
      (expect pdf.pages[1][:strings]).to include 'body'
    end

    it 'should create document with only a title page if body is empty and title-page is set' do
      pdf = to_pdf '= Title Page Only', attribute_overrides: { 'title-page' => '' }, analyze: true
      (expect pdf.pages).to have_size 1
      (expect pdf.lines).to eql ['Title Page Only']
    end
  end

  context 'Logo' do
    it 'should add logo specified by title-logo-image document attribute to title page' do
      pdf = to_pdf <<~'END'
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[]
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should not add border to raster logo image if border is specified for image block in theme' do
      pdf_theme = { image_border_width: 1, image_border_color: '000000' }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[]

      content
      END

      (expect pdf.lines).to be_empty
    end

    it 'should not add border to SVG logo image if border is specified for image block in theme' do
      pdf_theme = { image_border_width: 1, image_border_color: '0000EE' }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :line
      = Document Title
      :doctype: book
      :title-logo-image: image:square.svg[]

      content
      END

      image_border_lines = pdf.lines.select {|it| it[:color] == '0000EE' }
      (expect image_border_lines).to be_empty
    end

    it 'should add remote logo specified by title-logo-image document attribute to title page' do
      with_local_webserver do |base_url|
        [%(#{base_url}/tux.png), %(image:#{base_url}/tux.png[])].each do |image_url|
          pdf = to_pdf <<~END, attribute_overrides: { 'allow-uri-read' => '' }
          = Document Title
          :doctype: book
          :title-logo-image: #{image_url}
          END

          images = get_images pdf, 1
          (expect images).to have_size 1
          (expect images[0].hash[:Width]).to be 204
          (expect images[0].hash[:Height]).to be 240
        end
      end
    end

    it 'should add logo specified by title-logo-image document attribute with data URI to title page' do
      image_data = File.binread fixture_file 'tux.png'
      encoded_image_data = [image_data].pack 'm0'
      image_url = %(image:data:image/jpg;base64,#{encoded_image_data}[])
      pdf = to_pdf <<~END
      = Document Title
      :doctype: book
      :title-logo-image: #{image_url}
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should use image format for title logo specified by format attribute' do
      source_file = (dest_file = fixture_file 'square') + '.svg'
      FileUtils.cp source_file, dest_file
      pdf = to_pdf <<~END, enable_footer: true, analyze: :rect
      = Document Title
      :title-page:
      :title-logo-image: image:#{dest_file}[format=svg]
      END
      (expect pdf.rectangles).to have_size 1
      rect = pdf.rectangles[0]
      (expect rect[:width]).to eql 200.0
      (expect rect[:height]).to eql 200.0
    ensure
      File.unlink dest_file
    end

    it 'should not allow PDF to be used as title logo image' do
      (expect do
        pdf = to_pdf <<~'END'
        = Document Title
        :doctype: book
        :title-logo-image: image:red-green-blue.pdf[page=1]
        END

        # QUESTION: should we validate page background color?
        (expect pdf.pages).to have_size 1
      end).to log_message severity: :ERROR, message: '~PDF format not supported for title page logo image'
    end

    it 'should position logo using value of top attribute with vh units on image macro in title-logo-image attribute' do
      pdf = to_pdf <<~'END', analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left,top=0vh]
      END

      left_margin = 0.67 * 72
      page_height = 841.89 # ~11.69in

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:y]).to eql page_height
    end

    it 'should position logo using value of top attribute with in units on image macro in title-logo-image attribute' do
      pdf = to_pdf <<~'END', analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left,top=1in]
      END

      left_margin = 0.67 * 72
      top_margin = 0.5 * 72
      page_height = 841.89 # ~11.69in

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:y]).to eql (page_height - top_margin - 72)
    end

    it 'should position logo using value of top attribute with unrecognized units on image macro in title-logo-image attribute' do
      pdf = to_pdf <<~'END', analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left,top=1ft]
      END

      left_margin = 0.67 * 72
      top_margin = 0.5 * 72
      page_height = 841.89 # ~11.69in

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:y]).to eql (page_height - top_margin - 1)
    end

    it 'should align logo using value of align attribute specified on image macro', visual: true do
      to_file = to_pdf_file <<~'END', 'title-page-logo-align-attribute.pdf'
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]
      END

      (expect to_file).to visually_match 'title-page-logo-align-left.pdf'
    end

    it 'should inherit align value from title page if align not specified on logo in theme' do
      pdf_theme = {
        title_page_logo_align: nil,
        title_page_text_align: 'center',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[]
      END

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:x]).to be > 48.24
    end

    it 'should inherit align attribute if value on macro is invalid' do
      pdf_theme = {
        title_page_logo_align: nil,
        title_page_text_align: 'left',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=foo]
      END

      images = pdf.images
      (expect images).to have_size 1
      (expect images[0][:x]).to eql 48.24
    end

    it 'should allow left margin to be set for left-aligned logo image' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_logo_margin_left: 10 }, analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]
      END

      left_margin = 0.67 * 72

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:page_number]).to be 1
      (expect title_page_image[:x]).to eql left_margin + 10.0
    end

    it 'should allow right margin to be set for right-aligned logo image' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_logo_margin_right: 10 }, analyze: :image
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=right]
      END

      right_margin = (8.27 - 0.67) * 72

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:page_number]).to be 1
      (expect title_page_image[:x]).to be_within(0.5).of(right_margin - 10.0 - title_page_image[:width])
    end

    it 'should resize raster logo to keep it on title page' do
      pdf = to_pdf <<~'END', analyze: :image
      = Document Title
      :title-page:
      :title-logo-image: image:cover.jpg[pdfwidth=100%,top=70%]

      content
      END

      (expect pdf.page_count).to eql 2
      images = pdf.images
      (expect images).to have_size 1
      logo_image = images[0]
      (expect logo_image[:page_number]).to be 1
      (expect logo_image[:y]).to be < 300
    end

    it 'should resize SVG logo to keep it on title page' do
      pdf = to_pdf <<~'END', analyze: :line
      = Document Title
      :title-page:
      :title-logo-image: image:red-blue-squares.svg[pdfwidth=50%,top=70%]

      content
      END

      (expect pdf.lines.map {|it| it[:page_number] }.uniq).to eql [1]
    end
  end

  context 'Background' do
    it 'should set background image of title page from title-page-background-image attribute' do
      pdf = to_pdf <<~'END'
      = The Amazing
      Author Name
      :doctype: book
      :title-page-background-image: image:bg.png[]

      beginning

      <<<

      middle

      <<<

      end
      END

      (expect pdf.pages).to have_size 4
      [1, 0, 0, 0].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        (expect images).to have_size expected_num_images
      end
    end

    it 'should set background image of title page when document has image cover page' do
      pdf = to_pdf <<~'END'
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
      END

      (expect pdf.pages).to have_size 5
      [1, 1, 0, 0, 0].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        (expect images).to have_size expected_num_images
      end
    end

    it 'should set background image of title page and body pages when document has PDF cover page' do
      pdf = to_pdf <<~'END'
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
      END

      images_by_page = []
      (expect pdf.pages).to have_size 5
      [0, 1, 1, 1, 1].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        images_by_page << images
        (expect images).to have_size expected_num_images
      end

      (expect images_by_page[1][0].data).not_to eql images_by_page[2][0].data
      (expect images_by_page[2..-1].uniq {|it| it[0].data }).to have_size 1
    end

    it 'should not create extra blank page when document has cover page and raster page background image' do
      image_data = File.binread fixture_file 'cover.jpg'

      pdf = to_pdf <<~'END'
      = The Amazing
      Author Name
      :doctype: book
      :front-cover-image: image:blue-letter.pdf[]
      :title-page-background-image: image:cover.jpg[]
      :page-background-image: image:tux.png[]
      END

      (expect pdf.pages).to have_size 2
      images_by_page = []
      [0, 1].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        images_by_page << images
        (expect images).to have_size expected_num_images
      end
      (expect images_by_page[1][0].data).to eql image_data
      cover_page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (cover_page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 1.0 scn']
    end

    it 'should not create extra blank page when document has cover page and SVG page background image', visual: true do
      to_file = to_pdf_file <<~'END', 'title-page-background-image-svg-with-cover.pdf'
      = The Amazing
      Author Name
      :doctype: book
      :front-cover-image: image:blue-letter.pdf[]
      :title-page-background-image: image:example-stamp.svg[]
      :page-background-image: image:watermark.svg[]

      content
      END

      (expect to_file).to visually_match 'title-page-background-image-svg-with-cover.pdf'
    end

    it 'should not create extra blank page when document has PDF cover page and doctype is book' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :front-cover-image: image:red-green-blue.pdf[page=1]
      END

      (expect pdf.pages).to have_size 2
      doctitle_text = pdf.find_unique_text 'Document Title'
      (expect doctitle_text[:page_number]).to eql 2
    end

    it 'should be able to set size and position of title page background image', visual: true do
      to_file = to_pdf_file <<~'END', 'title-page-background-image-size-position.pdf'
      = Document Title
      :doctype: book
      :title-page-background-image: image:tux.png[fit=none,position=bottom left]

      content
      END

      (expect to_file).to visually_match 'title-page-background-image-size-position.pdf'
    end
  end

  context 'Theming' do
    it 'should allow theme to control margins around elements' do
      reference_pdf_theme = {
        title_page_authors_margin_top: 5,
        title_page_revision_margin_top: 5,
      }

      pdf_theme = {
        title_page_title_margin_top: 10,
        title_page_title_margin_bottom: 5,
        title_page_subtitle_margin_top: 5,
        title_page_subtitle_margin_bottom: 10,
        title_page_authors_margin_top: nil,
        title_page_authors_margin_bottom: 10,
        title_page_revision_margin_top: nil,
        title_page_revision_margin_bottom: 10,
      }

      input = <<~'END'
      = Document Title: Subtitle
      :doctype: book
      Author Name
      v1.0
      END

      reference_pdf = to_pdf input, pdf_theme: reference_pdf_theme, analyze: true
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true

      reference_title_page_texts = reference_pdf.find_text page_number: 1
      title_page_texts = pdf.find_text page_number: 1

      (expect title_page_texts[0][:y]).to eql (reference_title_page_texts[0][:y] - 10)
      (expect title_page_texts[1][:y]).to eql (reference_title_page_texts[1][:y] - 20)
      (expect title_page_texts[2][:y]).to eql (reference_title_page_texts[2][:y] - 25)
      (expect title_page_texts[3][:y]).to eql (reference_title_page_texts[3][:y] - 30)
    end

    it 'should allow theme to customize content of authors line' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_authors_content: '{url}[{author}]' }
      = Document Title
      Doc Writer <doc@example.org>; Junior Writer <https://github.com/ghost>
      :doctype: book

      body
      END

      (expect (pdf.page 1).text).to include 'Doc Writer, Junior Writer'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 2
      author1_annotation = annotations[0]
      (expect author1_annotation[:Subtype]).to be :Link
      (expect author1_annotation[:A][:URI]).to eql 'mailto:doc@example.org'
      author2_annotation = annotations[1]
      (expect author2_annotation[:Subtype]).to be :Link
      (expect author2_annotation[:A][:URI]).to eql 'https://github.com/ghost'
    end

    it 'should normalize whitespace in authors content' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_authors_content: %({url}\n[{author}]) }, analyze: true
      = Document Title
      Doc Writer <doc@example.org>
      :doctype: book

      body
      END

      (expect pdf.lines).to include 'mailto:doc@example.org [Doc Writer]'
    end

    it 'should drop lines with missing attribute reference in authors content' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_authors_content: %(keep: {firstname}\ndrop{no-such-attr}\nkeep: {lastname}) }, analyze: true
      = Document Title
      Doc Writer <doc@example.org>
      :doctype: book

      body
      END

      (expect pdf.lines).to include 'keep: Doc keep: Writer'
    end

    it 'should honor explicit hard line breaks in authors content' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_authors_content: %({firstname} +\n{lastname}) }, analyze: true
      = Document Title
      Doc Writer <doc@example.org>
      :doctype: book

      body
      END

      title_page_lines = pdf.lines pdf.find_text page_number: 1
      (expect title_page_lines).to eql ['Document Title', 'Doc', 'Writer']
    end

    it 'should allow theme to customize content of authors line by available metadata' do
      pdf_theme = {
        title_page_authors_content_name_only: '{authorinitials}',
        title_page_authors_content_with_email: '{lastname}, {firstname} <{email}>',
        title_page_authors_content_with_url: '{url}[{author}]',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme
      = Document Title
      Doc Writer <doc@example.org>; Junior Writer <https://github.com/ghost>; Jane Doe
      :doctype: book

      body
      END

      (expect (pdf.page 1).text).to include 'Writer, Doc <doc@example.org>, Junior Writer, JD'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 2
      author1_annotation = annotations[0]
      (expect author1_annotation[:Subtype]).to be :Link
      (expect author1_annotation[:A][:URI]).to eql 'mailto:doc@example.org'
      author2_annotation = annotations[1]
      (expect author2_annotation[:Subtype]).to be :Link
      (expect author2_annotation[:A][:URI]).to eql 'https://github.com/ghost'
    end

    it 'should allow theme to customize style of link in authors line using custom role' do
      pdf_theme = {
        role_author_font_color: '00AA00',
        title_page_authors_content: '{url}[{author},role=author]',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      Junior Writer <https://github.com/ghost>
      :doctype: book

      body
      END

      author_text = (pdf.find_text 'Junior Writer')[0]
      (expect author_text[:font_color]).to eql '00AA00'
    end

    it 'should be able to use an icon in an author entry' do
      pdf_theme = {
        title_page_authors_content: '{author} {url}[icon:twitter[]]',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      Doc Writer <https://twitter.com/asciidoctor>
      :icons: font
      :doctype: book

      body
      END

      title_page_lines = pdf.lines pdf.find_text page_number: 1
      (expect title_page_lines).to include %(Doc Writer \uf099)
    end

    it 'should allow delimiter for authors and revision info to be set' do
      pdf_theme = {
        title_page_authors_delimiter: ' / ',
        title_page_revision_delimiter: ' - ',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      Doc Writer; Junior Writer
      v1.0, 2019-01-01
      :doctype: book

      content
      END

      lines = pdf.lines
      (expect lines).to include 'Doc Writer / Junior Writer'
      (expect lines).to include 'Version 1.0 - 2019-01-01'
    end

    it 'should allow theme to customize content of revision line' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_revision_content: '{revdate} (*v{revnumber}*)' }
      = Document Title
      Author Name
      v1.0, 2022-10-22
      :doctype: book

      body
      END

      (expect (pdf.page 1).text).to include '2022-10-22 (v1.0)'
    end

    it 'should include version label in revision line if revnumber attribute is set' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      Author Name
      v1.0, 2022-10-22
      :doctype: book

      body
      END

      (expect pdf.lines).to include 'Version 1.0, 2022-10-22'
    end

    it 'should not include version label in revision line if version-label attribute is unset' do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      Author Name
      v1.0, 2022-10-22
      :doctype: book
      :!version-label:

      body
      END

      (expect pdf.lines).to include '1.0, 2022-10-22'
    end

    it 'should add logo specified by title_page_logo_image theme key to title page' do
      pdf_theme = {
        __dir__: fixtures_dir,
        title_page_logo_image: 'image:tux.png[]',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }
      = Document Title
      :doctype: book
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should use title page logo image if specified as absolute path' do
      %w({docdir}/tux.png image:{docdir}/tux.png[]).each do |title_page_logo_image|
        pdf_theme = { title_page_logo_image: title_page_logo_image }

        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, attribute_overrides: { 'docdir' => fixtures_dir }
        = Document Title
        :doctype: book
        END

        images = get_images pdf, 1
        (expect images).to have_size 1
        (expect images[0].hash[:Width]).to be 204
        (expect images[0].hash[:Height]).to be 240
      end
    end

    it 'should resolve title page logo image specified using path in theme relative to themesdir' do
      pdf_theme = {
        __dir__: fixtures_dir,
        title_page_logo_image: 'tux.png',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should resolve title page logo image specified using path in theme relative to themesdir in classloader', if: RUBY_ENGINE == 'jruby' do
      require fixture_file 'pdf-themes.jar'
      pdf = to_pdf <<~'END', attribute_overrides: { 'pdf-theme' => 'uri:classloader:/pdf-themes/title-page-logo-image-theme.yml' }
      = Document Title
      :doctype: book
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should resolve title page logo image with absolute path for theme loaded from classloader', if: RUBY_ENGINE == 'jruby' do
      require fixture_file 'pdf-themes.jar'
      pdf = to_pdf <<~'END', attribute_overrides: { 'pdf-theme' => 'uri:classloader:/pdf-themes/title-page-logo-image-from-fixturesdir-theme.yml', 'fixturesdir' => fixtures_dir }
      = Document Title
      :doctype: book
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should ignore missing attribute reference when resolve title page logo image from theme' do
      (expect do
        to_pdf <<~'END', pdf_theme: { title_page_logo_image: 'image:{no-such-attribute}{attribute-missing}.png[]' }, attribute_overrides: { 'attribute-missing' => 'warn' }
        = Document Title
        :doctype: book
        END
      end).to log_message severity: :WARN, message: '~skip.png'
    end

    it 'should add remote logo specified by title_page_logo_image theme key to title page' do
      with_local_webserver do |base_url|
        [%(#{base_url}/tux.png), %(image:#{base_url}/tux.png[])].each do |image_url|
          pdf = to_pdf <<~'END', pdf_theme: { title_page_logo_image: image_url }, attribute_overrides: { 'allow-uri-read' => '' }
          = Document Title
          :doctype: book
          END

          images = get_images pdf, 1
          (expect images).to have_size 1
          (expect images[0].hash[:Width]).to be 204
          (expect images[0].hash[:Height]).to be 240
        end
      end
    end

    it 'should add logo specified by title-logo-image document attribute with data URI to title page' do
      image_data = File.binread fixture_file 'tux.png'
      encoded_image_data = [image_data].pack 'm0'
      image_url = %(image:data:image/jpg;base64,#{encoded_image_data}[])
      pdf = to_pdf <<~'END', pdf_theme: { title_page_logo_image: image_url }
      = Document Title
      :doctype: book
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should resolve title page logo image from theme relative to themedir' do
      pdf_theme = {
        __dir__: examples_dir,
        title_page_logo_image: 'image:sample-logo.jpg[]',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      END

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 331
      (expect images[0].hash[:Height]).to be 369
    end

    it 'should move logo down from top margin of page by % value of title_page_logo_top key' do
      [nil, '10%'].each do |top|
        pdf_theme = {
          title_page_logo_top: top,
        }

        pdf = to_pdf <<~'END', analyze: :image, pdf_theme: pdf_theme
        = Document Title
        :doctype: book
        :title-logo-image: image:tux.png[align=left]

        image::tux.png[]
        END

        left_margin = 0.67 * 72
        top_margin = 0.5 * 72
        bottom_margin = 0.67 * 72
        page_height = 841.89 # ~11.69in

        images = pdf.images
        (expect images).to have_size 2
        title_page_image = images[0]
        reference_image = images[1]
        (expect title_page_image[:page_number]).to be 1
        (expect reference_image[:page_number]).to be 2
        (expect title_page_image[:x]).to eql left_margin
        (expect title_page_image[:x]).to eql reference_image[:x]
        effective_page_height = page_height - top_margin - bottom_margin
        expected_top = reference_image[:y] - (effective_page_height * (top.to_f / 100))
        (expect title_page_image[:y]).to eql expected_top
      end
    end

    it 'should move logo down from top margin of page by numeric value of title_page_logo_top key' do
      pdf_theme = { title_page_logo_top: 20 }

      pdf = to_pdf <<~'END', analyze: :image, pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]

      image::tux.png[]
      END

      left_margin = 0.67 * 72

      images = pdf.images
      (expect images).to have_size 2
      title_page_image = images[0]
      reference_image = images[1]
      (expect title_page_image[:page_number]).to be 1
      (expect reference_image[:page_number]).to be 2
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:x]).to eql reference_image[:x]
      expected_top = reference_image[:y] - 20
      (expect title_page_image[:y]).to eql expected_top
    end

    it 'should move logo down from top margin of page by pt value of title_page_logo_top key' do
      pdf_theme = {
        title_page_logo_top: '20pt',
      }

      pdf = to_pdf <<~'END', analyze: :image, pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]

      image::tux.png[]
      END

      left_margin = 0.67 * 72

      images = pdf.images
      (expect images).to have_size 2
      title_page_image = images[0]
      reference_image = images[1]
      (expect title_page_image[:page_number]).to be 1
      (expect reference_image[:page_number]).to be 2
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:x]).to eql reference_image[:x]
      expected_top = reference_image[:y] - 20
      (expect title_page_image[:y]).to eql expected_top
    end

    it 'should move logo down from top of page by vh value of title_page_logo_top key' do
      pdf_theme = {
        title_page_logo_top: '5vh',
      }

      pdf = to_pdf <<~'END', analyze: :image, pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]
      END

      left_margin = 0.67 * 72
      page_height = 841.89 # ~11.69in

      images = pdf.images
      (expect images).to have_size 1
      title_page_image = images[0]
      (expect title_page_image[:page_number]).to be 1
      (expect title_page_image[:x]).to eql left_margin
      expected_top = page_height - (page_height * 0.05)
      (expect title_page_image[:y]).to eql expected_top
    end

    it 'should move title down from top margin by % value of title_page_title_top key' do
      pdf_theme = {
        title_page_title_top: '10%',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      content
      END

      page_height = 841.89 # ~11.69in
      top_margin = 0.5 * 72
      bottom_margin = 0.67 * 72

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to be 1
      effective_page_height = page_height - top_margin - bottom_margin
      expected_top = page_height - top_margin - (effective_page_height * 0.10)
      (expect doctitle_text[:y] + doctitle_text[:font_size]).to be_within(0.5).of(expected_top)
    end

    it 'should move title down from top margin by numeric value of title_page_title_top key' do
      pdf_theme = { title_page_title_top: 20 }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      content
      END

      page_height = 841.89 # ~11.69in
      top_margin = 0.5 * 72

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to be 1
      expected_top = page_height - top_margin - 20
      (expect doctitle_text[:y] + doctitle_text[:font_size]).to be_within(0.5).of(expected_top)
    end

    it 'should move title down from top margin by pt value of title_page_title_top key' do
      pdf_theme = {
        title_page_title_top: '20pt',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      content
      END

      page_height = 841.89 # ~11.69in
      top_margin = 0.5 * 72

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to be 1
      expected_top = page_height - top_margin - 20
      (expect doctitle_text[:y] + doctitle_text[:font_size]).to be_within(0.5).of(expected_top)
    end

    it 'should move title down from top of page by vh value of title_page_title_top key' do
      pdf_theme = {
        title_page_title_top: '0vh',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      content
      END

      page_height = 841.89 # ~11.69in

      doctitle_text = (pdf.find_text 'Document Title')[0]
      (expect doctitle_text[:page_number]).to be 1
      (expect doctitle_text[:y] + doctitle_text[:font_size]).to be_within(0.5).of(page_height)
    end

    it 'should allow left margin of elements on title page to be configured' do
      input = <<~'END'
      = Book Title: Bring Out Your Dead Trees
      Author Name
      v1.0, 2001-01-01

      body
      END

      pdf_theme = { title_page_text_align: 'left' }

      pdf = to_pdf input, doctype: :book, pdf_theme: pdf_theme, analyze: true

      expected_x = (pdf.find_text page_number: 1).map {|it| it[:x] + 10 }

      pdf_theme.update \
        title_page_title_margin_left: 10,
        title_page_subtitle_margin_left: 10,
        title_page_authors_margin_left: 10,
        title_page_revision_margin_left: 10

      pdf = to_pdf input, doctype: :book, pdf_theme: pdf_theme, analyze: true

      actual_x = (pdf.find_text page_number: 1).map {|it| it[:x] }
      (expect actual_x).to eql expected_x
    end

    it 'should allow right margin of elements on title page to be configured' do
      input = <<~'END'
      = Book Title: Bring Out Your Dead Trees
      Author Name
      v1.0, 2001-01-01

      body
      END

      pdf = to_pdf input, doctype: :book, analyze: true

      expected_x = (pdf.find_text page_number: 1).map {|it| it[:x] - 10 }

      pdf_theme = {
        title_page_title_margin_right: 10,
        title_page_subtitle_margin_right: 10,
        title_page_authors_margin_right: 10,
        title_page_revision_margin_right: 10,
      }

      pdf = to_pdf input, doctype: :book, pdf_theme: pdf_theme, analyze: true

      actual_x = (pdf.find_text page_number: 1).map {|it| it[:x] }
      (expect actual_x).to eql expected_x
    end

    it 'should be able to set background color of title page', visual: true do
      pdf_theme = {
        title_page_background_color: '000000',
        title_page_title_font_color: 'EFEFEF',
        title_page_authors_font_color: 'DBDBDB',
      }

      to_file = to_pdf_file <<~'END', 'title-page-background-color.pdf', pdf_theme: pdf_theme
      = Dark and Stormy
      Author Name
      :doctype: book

      body
      END

      (expect to_file).to visually_match 'title-page-background-color.pdf'
    end

    it 'should set background color when document has PDF cover page' do
      pdf = to_pdf <<~'END', pdf_theme: { title_page_background_color: 'eeeeee' }
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
      END

      images_by_page = []
      (expect pdf.pages).to have_size 5
      [0, 0, 1, 1, 1].each_with_index do |expected_num_images, idx|
        images = get_images pdf, idx.next
        images_by_page << images
        (expect images).to have_size expected_num_images
      end

      (expect images_by_page[2..-1].uniq {|it| it[0].data }).to have_size 1
    end

    it 'should use title page background specified in theme resolved relative to theme dir' do
      [true, false].each do |macro|
        pdf_theme = {
          __dir__: fixtures_dir,
          title_page_background_image: (macro ? 'image:bg.png[]' : 'bg.png'),
        }
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme
        = Document Title
        :doctype: book

        content
        END

        (expect pdf.pages).to have_size 2
        (expect get_images pdf, 1).to have_size 1
        (expect get_images pdf, 2).to have_size 0
      end
    end

    it 'should not use page background on title page if title-page-background-image attribute is set to none or empty' do
      pdf_theme = {
        title_page_background_image: %(image:#{fixture_file 'bg.png'}[]),
      }
      [' none', ''].each do |val|
        pdf = to_pdf <<~END, pdf_theme: pdf_theme
        = Document Title
        :doctype: book
        :title-page-background-image:#{val}

        content
        END

        (expect pdf.pages).to have_size 2
        (expect get_images pdf).to be_empty
      end
    end

    it 'should not use page background on title page if page_background is set to none in theme' do
      pdf_theme = {
        page_background_image: %(image:#{fixture_file 'bg.png'}[]),
        title_page_background_image: 'none',
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme
      = Document Title
      :doctype: book

      == Chapter 1

      content

      == Chapter 2

      content
      END

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

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme
      = Document Title: Subtitle
      :doctype: book
      :title-logo-image: image:tux.png[]
      Author Name
      v1.0, 2020-01-01

      first page of content
      END

      (expect pdf.pages).to have_size 2
      (expect (pdf.page 1).text).to eql 'Document Title'
      (expect get_images pdf, 1).to be_empty
    end

    it 'should only display subtitle if document has subtitle and title is disabled' do
      pdf_theme = {
        title_page_title_display: 'none',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      = Document Title: Subtitle
      :doctype: book

      first page of content
      END

      title_page_lines = pdf.lines pdf.find_text page_number: 1
      (expect title_page_lines).to eql %w(Subtitle)
    end

    it 'should advanced past title page if all elements are disabled' do
      pdf_theme = {
        title_page_title_display: 'none',
        title_page_subtitle_display: 'none',
        title_page_authors_display: 'none',
        title_page_revision_display: 'none',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme
      = Document Title: Subtitle
      :doctype: book
      :title-page-background-image: image:cover.jpg[]
      Author Name
      v1.0, 2020-01-01

      first page of content
      END

      (expect pdf.pages).to have_size 2
      title_page_text = (pdf.page 1).text
      (expect title_page_text).to be_empty

      image_data = File.binread fixture_file 'cover.jpg'
      title_page_images = get_images pdf, 1
      (expect title_page_images).to have_size 1
      (expect title_page_images[0].data).to eql image_data
    end

    it 'should not remove title page if all elements are disabled' do
      pdf_theme = {
        title_page_title_display: 'none',
        title_page_subtitle_display: 'none',
        title_page_authors_display: 'none',
        title_page_revision_display: 'none',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme
      = Document Title: Subtitle
      :doctype: book
      :title-page-background-image: image:cover.jpg[]
      Author Name
      v1.0, 2020-01-01
      END

      (expect pdf.pages).to have_size 1
      title_page_text = (pdf.page 1).text
      (expect title_page_text).to be_empty

      image_data = File.binread fixture_file 'cover.jpg'
      title_page_images = get_images pdf, 1
      (expect title_page_images).to have_size 1
      (expect title_page_images[0].data).to eql image_data
    end

    it 'should truncate contents of title page so it does not exceed the height of a single page' do
      pdf_theme = {
        title_page_title_top: '50%',
        title_page_title_font_size: 92,
        title_page_authors_margin_top: 36,
        title_page_authors_font_size: 64,
      }

      pdf = nil
      (expect do
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        = Document Title
        Author Name
        v1.0
        :doctype: book

        == First Chapter

        content
        END
      end).to log_message severity: :WARN, message: 'the title page contents has been truncated to prevent it from overrunning the bounds of a single page'

      (expect pdf.pages).to have_size 2
      author_text = pdf.find_unique_text 'Author Name'
      (expect author_text[:page_number]).to eql 1
      revision_text = pdf.find_unique_text 'Version 1.0'
      (expect revision_text).to be_nil
      chapter_title_text = pdf.find_unique_text 'First Chapter'
      (expect chapter_title_text[:page_number]).to eql 2
    end
  end
end
