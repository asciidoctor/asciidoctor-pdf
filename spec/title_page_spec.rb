# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Title Page' do
  it 'should place document title on title page when doctype is book' do
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
    (expect doctitle_text[:font_size]).to be 27
    (expect pdf.pages[1][:text]).to have_size 1
  end

  it 'should create book with only a title page if doctitle is specified and body is empty' do
    pdf = to_pdf '= Title Page Only', doctype: :book, analyze: true
    (expect pdf.pages).to have_size 1
    (expect pdf.lines).to eql ['Title Page Only']
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

  it 'should display author names under document title on title page' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    Doc Writer; Junior Writer
    :doctype: book

    body
    EOS

    title_page_lines = pdf.lines pdf.find_text page_number: 1
    (expect title_page_lines).to eql ['Document Title', 'Doc Writer, Junior Writer']
  end

  context 'title-page' do
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
  end

  context 'Logo' do
    it 'should add logo specified by title-logo-image document attribute to title page' do
      pdf = to_pdf <<~'EOS'
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[]
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should add remote logo specified by title-logo-image document attribute to title page' do
      with_local_webserver do |base_url|
        [%(#{base_url}/tux.png), %(image:#{base_url}/tux.png[])].each do |image_url|
          pdf = to_pdf <<~EOS, attribute_overrides: { 'allow-uri-read' => '' }
          = Document Title
          :doctype: book
          :title-logo-image: #{image_url}
          EOS

          images = get_images pdf, 1
          (expect images).to have_size 1
          (expect images[0].hash[:Width]).to be 204
          (expect images[0].hash[:Height]).to be 240
        end
      end
    end

    it 'should add logo specified by title-logo-image document attribute with data URI to title page' do
      image_data = File.binread fixture_file 'tux.png'
      encoded_image_data = Base64.strict_encode64 image_data
      image_url = %(image:data:image/jpg;base64,#{encoded_image_data}[])
      pdf = to_pdf <<~EOS
      = Document Title
      :doctype: book
      :title-logo-image: #{image_url}
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should use image format for title logo specified by format attribute' do
      source_file = (dest_file = fixture_file 'square') + '.svg'
      begin
        FileUtils.cp source_file, dest_file
        pdf = to_pdf <<~EOS, enable_footer: true, analyze: :rect
        = Document Title
        :title-page:
        :title-logo-image: image:#{dest_file}[format=svg]
        EOS
        (expect pdf.rectangles).to have_size 1
        rect = pdf.rectangles[0]
        (expect rect[:width]).to eql 200.0
        (expect rect[:height]).to eql 200.0
      ensure
        File.unlink dest_file
      end
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
      (expect title_page_image[:page_number]).to be 1
      (expect title_page_image[:x]).to eql left_margin
      (expect title_page_image[:y]).to eql page_height
    end

    it 'should align logo using value of align attribute specified on image macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'title-page-logo-align-attribute.pdf'
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=left]
      EOS

      (expect to_file).to visually_match 'title-page-logo-align-left.pdf'
    end

    it 'should ignore align attribute on logo macro if value is invalid', visual: true do
      to_file = to_pdf_file <<~'EOS', 'title-page-logo-align-invalid.pdf', pdf_theme: { title_page_logo_align: 'left' }
      = Document Title
      :doctype: book
      :title-logo-image: image:tux.png[align=foo]
      EOS

      (expect to_file).to visually_match 'title-page-logo-align-left.pdf'
    end
  end

  context 'Background' do
    it 'should set background image of title page from title-page-background-image attribute' do
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

    it 'should set background image of title page when document has image cover page' do
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

    it 'should set background image of title page and body pages when document has PDF cover page' do
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

    it 'should not create extra blank page when document has cover page and raster page background image' do
      image_data = File.binread fixture_file 'cover.jpg'

      pdf = to_pdf <<~'EOS'
      = The Amazing
      Author Name
      :doctype: book
      :front-cover-image: image:blue-letter.pdf[]
      :title-page-background-image: image:cover.jpg[]
      :page-background-image: image:tux.png[]
      EOS

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
      to_file = to_pdf_file <<~'EOS', 'title-page-background-image-svg-with-cover.pdf'
      = The Amazing
      Author Name
      :doctype: book
      :front-cover-image: image:blue-letter.pdf[]
      :title-page-background-image: image:example-watermark.svg[]
      :page-background-image: image:watermark.svg[]

      content
      EOS

      (expect to_file).to visually_match 'title-page-background-image-svg-with-cover.pdf'
    end

    it 'should be able to set size and position of title page background image', visual: true do
      to_file = to_pdf_file <<~'EOS', 'title-page-background-image-size-position.pdf'
      = Document Title
      :doctype: book
      :title-page-background-image: image:tux.png[fit=none,position=bottom left]

      content
      EOS

      (expect to_file).to visually_match 'title-page-background-image-size-position.pdf'
    end
  end

  context 'Theming' do
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
      (expect author1_annotation[:Subtype]).to be :Link
      (expect author1_annotation[:A][:URI]).to eql 'mailto:doc@example.org'
      author2_annotation = annotations[1]
      (expect author2_annotation[:Subtype]).to be :Link
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
      (expect author1_annotation[:Subtype]).to be :Link
      (expect author1_annotation[:A][:URI]).to eql 'mailto:doc@example.org'
      author2_annotation = annotations[1]
      (expect author2_annotation[:Subtype]).to be :Link
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

      title_page_lines = pdf.lines pdf.find_text page_number: 1
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
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should resolve title page logo image specified using path in theme relative to themesdir' do
      pdf_theme = {
        __dir__: fixtures_dir,
        title_page_logo_image: 'tux.png',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should resolve title page logo image specified using path in theme relative to themesdir in classloader', if: RUBY_ENGINE == 'jruby' do
      require fixture_file 'pdf-themes.jar'
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => 'uri:classloader:/pdf-themes/title-page-logo-image-theme.yml' }
      = Document Title
      :doctype: book
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should resolve title page logo image with absolute path for theme loaded from classloader', if: RUBY_ENGINE == 'jruby' do
      require fixture_file 'pdf-themes.jar'
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => 'uri:classloader:/pdf-themes/title-page-logo-image-from-fixturesdir-theme.yml', 'fixturesdir' => fixtures_dir }
      = Document Title
      :doctype: book
      EOS

      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 204
      (expect images[0].hash[:Height]).to be 240
    end

    it 'should ignore missing attribute reference when resolve title page logo image from theme' do
      (expect do
        to_pdf <<~'EOS', pdf_theme: { title_page_logo_image: 'image:{no-such-attribute}{attribute-missing}.png[]' }, attribute_overrides: { 'attribute-missing' => 'warn' }
        = Document Title
        :doctype: book
        EOS
      end).to log_message severity: :WARN, message: '~skip.png'
    end

    it 'should add remote logo specified by title_page_logo_image theme key to title page' do
      with_local_webserver do |base_url|
        [%(#{base_url}/tux.png), %(image:#{base_url}/tux.png[])].each do |image_url|
          pdf = to_pdf <<~'EOS', pdf_theme: { title_page_logo_image: image_url }, attribute_overrides: { 'allow-uri-read' => '' }
          = Document Title
          :doctype: book
          EOS

          images = get_images pdf, 1
          (expect images).to have_size 1
          (expect images[0].hash[:Width]).to be 204
          (expect images[0].hash[:Height]).to be 240
        end
      end
    end

    it 'should add logo specified by title-logo-image document attribute with data URI to title page' do
      image_data = File.binread fixture_file 'tux.png'
      encoded_image_data = Base64.strict_encode64 image_data
      image_url = %(image:data:image/jpg;base64,#{encoded_image_data}[])
      pdf = to_pdf <<~EOS, pdf_theme: { title_page_logo_image: image_url }
      = Document Title
      :doctype: book
      EOS

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
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      EOS

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
        (expect title_page_image[:page_number]).to be 1
        (expect reference_image[:page_number]).to be 2
        (expect title_page_image[:x]).to eql left_margin
        (expect title_page_image[:x]).to eql reference_image[:x]
        effective_page_height = page_height - top_margin - bottom_margin
        expected_top = reference_image[:y] - (effective_page_height * (top.to_f / 100))
        (expect title_page_image[:y]).to eql expected_top
      end
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
      (expect title_page_image[:page_number]).to be 1
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
      (expect doctitle_text[:page_number]).to be 1
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
      (expect doctitle_text[:page_number]).to be 1
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
      (expect doctitle_text[:page_number]).to be 1
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

      to_file = to_pdf_file <<~'EOS', 'title-page-background-color.pdf', pdf_theme: theme_overrides
      = Dark and Stormy
      Author Name
      :doctype: book

      body
      EOS

      (expect to_file).to visually_match 'title-page-background-color.pdf'
    end

    it 'should set background color when document has PDF cover page' do
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

    it 'should use title page background specified in theme resolved relative to theme dir' do
      [true, false].each do |macro|
        pdf_theme = {
          __dir__: fixtures_dir,
          title_page_background_image: (macro ? 'image:bg.png[]' : 'bg.png'),
        }
        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
        = Document Title
        :doctype: book

        content
        EOS

        (expect pdf.pages).to have_size 2
        (expect get_images pdf, 1).to have_size 1
        (expect get_images pdf, 2).to have_size 0
      end
    end

    it 'should not use page background on title page if title-page-background-image attribute is set to none' do
      pdf_theme = {
        title_page_background_image: %(image:#{fixture_file 'bg.png'}[]),
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :title-page-background-image: none

      content
      EOS

      (expect pdf.pages).to have_size 2
      (expect get_images pdf).to be_empty
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
