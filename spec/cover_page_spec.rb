# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Cover Page' do
  it 'should add front cover page if front-cover-image attribute is set to bare path' do
    pdf = to_pdf <<~END
    = Document Title
    :front-cover-image: #{fixture_file 'cover.jpg', relative: true}

    content page
    END

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0].text).to be_empty
    images = get_images pdf, 1
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should add front cover page if front-cover-image attribute is set to image macro' do
    pdf = to_pdf <<~'END'
    = Document Title
    :front-cover-image: image:cover.jpg[]

    content page
    END

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0].text).to be_empty
    images = get_images pdf, 1
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should add front cover page if front-cover-image attribute is set to data URI' do
    image_data = File.binread fixture_file 'cover.jpg'
    encoded_image_data = [image_data].pack 'm0'
    pdf = to_pdf <<~END
    = Document Title
    :front-cover-image: image:data:image/jpg;base64,#{encoded_image_data}[]

    content page
    END

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0].text).to be_empty
    images = get_images pdf, 1
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should not add cover page if file cannot be resolved' do
    (expect do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :doctype: book
      :front-cover-image: image:no-such-file.jpg[]

      content page
      END

      (expect pdf.pages).to have_size 2
      (expect pdf.lines pdf.find_text page_number: 1).to eql ['Document Title']
    end).to log_message severity: :WARN, message: %(front cover image not found or readable: #{fixture_file 'no-such-file.jpg'})
  end

  it 'should not add cover page if image cannot be embedded' do
    (expect do
      pdf = to_pdf <<~'END', analyze: true
      :front-cover-image: image:broken.svg[]

      content page
      END

      (expect pdf.pages).to have_size 1
      (expect pdf.lines pdf.find_text page_number: 1).to eql ['content page']
    end).to log_message severity: :WARN, message: %(~could not embed front cover image: #{fixture_file 'broken.svg'}; The data supplied is not a valid SVG document.)
  end

  it 'should not add cover page if value is ~' do
    pdf = to_pdf <<~'END', analyze: true
    = Document Title
    :doctype: book
    :front-cover-image: ~

    content page
    END

    (expect pdf.pages).to have_size 2
    (expect pdf.lines pdf.find_text page_number: 1).to eql ['Document Title']
  end

  it 'should apply recto margin to title page of prepress book when value of front-cover-image attribute is ~' do
    pdf = to_pdf <<~'END', pdf_theme: { title_page_text_align: 'left' }, analyze: true
    = Document Title
    :doctype: book
    :media: prepress
    :front-cover-image: ~

    first page

    <<<

    second page
    END

    (expect pdf.pages).to have_size 4
    doctitle_text = pdf.find_unique_text 'Document Title'
    (expect doctitle_text[:page_number]).to eql 1
    (expect doctitle_text[:x]).to eql 54.0
    first_page_text = pdf.find_unique_text 'first page'
    (expect first_page_text[:page_number]).to eql 3
    (expect first_page_text[:x]).to eql 54.0
    second_page_text = pdf.find_unique_text 'second page'
    (expect second_page_text[:page_number]).to eql 4
    (expect second_page_text[:x]).to eql 42.48
  end

  it 'should apply recto margin to title page of prepress book when value of front-cover-image theme key is ~' do
    pdf_theme = {
      title_page_text_align: 'left',
      cover_front_image: '~',
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
    = Document Title
    :doctype: book
    :media: prepress

    content
    END

    (expect pdf.pages).to have_size 3
    doctitle_text = pdf.find_unique_text 'Document Title'
    (expect doctitle_text[:page_number]).to eql 1
    (expect doctitle_text[:x]).to eql 54.0
  end

  it 'should add front cover page if cover_front_image theme key is set' do
    pdf_theme = { cover_front_image: (fixture_file 'cover.jpg') }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme
    = Document Title

    content page
    END

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0].text).to be_empty
    images = get_images pdf, 1
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should add back cover page if back-cover-image attribute is set to raw path' do
    pdf = to_pdf <<~END
    = Document Title
    :front-cover-image: #{fixture_file 'cover.jpg', relative: true}
    :back-cover-image: #{fixture_file 'cover.jpg', relative: true}

    content page
    END

    (expect pdf.pages).to have_size 3
    (expect pdf.pages[0].text).to be_empty
    (expect pdf.pages[2].text).to be_empty
    images = get_images pdf, 3
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should add back cover page if back-cover-image attribute is set to image macro' do
    pdf = to_pdf <<~'END'
    = Document Title
    :front-cover-image: image:cover.jpg[]
    :back-cover-image: image:cover.jpg[]

    content page
    END

    (expect pdf.pages).to have_size 3
    (expect pdf.pages[0].text).to be_empty
    (expect pdf.pages[2].text).to be_empty
    images = get_images pdf, 3
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should add back cover page if back-cover-image attribute is set to data URI' do
    image_data = File.binread fixture_file 'cover.jpg'
    encoded_image_data = [image_data].pack 'm0'
    pdf = to_pdf <<~END
    = Document Title
    :front-cover-image: image:data:image/jpg;base64,#{encoded_image_data}[]
    :back-cover-image: image:data:image/jpg;base64,#{encoded_image_data}[]

    content page
    END

    (expect pdf.pages).to have_size 3
    (expect pdf.pages[0].text).to be_empty
    (expect pdf.pages[2].text).to be_empty
    images = get_images pdf, 3
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should add back cover page if cover_back_image theme key is set' do
    pdf_theme = {
      cover_front_image: (fixture_file 'cover.jpg'),
      cover_back_image: (fixture_file 'cover.jpg'),
    }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme
    = Document Title

    content page
    END

    (expect pdf.pages).to have_size 3
    (expect pdf.pages[0].text).to be_empty
    (expect pdf.pages[2].text).to be_empty
    images = get_images pdf, 3
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should prefer attribute over theme key' do
    pdf_theme = { cover_back_image: (fixture_file 'not-this-one.jpg') }
    pdf = to_pdf <<~'END', pdf_theme: pdf_theme
    = Document Title
    :back-cover-image: image:cover.jpg[]

    content page
    END

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[1].text).to be_empty
    images = get_images pdf, 2
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should create blank page if front or back cover image is empty' do
    pdf = to_pdf <<~'END'
    = Book Title
    :doctype: book
    :front-cover-image:
    :back-cover-image:

    == Chapter

    text
    END

    (expect pdf.pages).to have_size 4
    (expect (pdf.page 1).text).to be_empty
    (expect (pdf.page 2).text).to include 'Book Title'
    (expect (pdf.page 4).text).to be_empty
  end

  it 'should create document with cover page only if front-cover-image is set and document has no content' do
    %w(article book).each do |doctype|
      pdf = to_pdf %(:front-cover-image: #{fixture_file 'cover.jpg', relative: true}), doctype: doctype
      (expect pdf.pages).to have_size 1
      (expect pdf.pages[0].text).to be_empty
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
      (expect extract_outline pdf).to be_empty
    end
  end

  it 'should not crash if front cover image is a URI and the allow-uri-read attribute is not set' do
    pdf = nil
    (expect do
      pdf = to_pdf <<~'END', analyze: true
      = Document Title
      :front-cover-image: https://example.org/cover.svg

      content
      END
    end).to not_raise_exception & (log_message severity: :WARN, message: '~allow-uri-read attribute not enabled')
    (expect pdf.pages).to have_size 1
    (expect pdf.find_text 'Document Title').to have_size 1
  end

  it 'should recognize attribute value that uses image macro syntax and resolve relative to imagesdir', visual: true do
    %w(block inline).each do |type|
      to_file = to_pdf_file <<~END, %(cover-page-front-cover-#{type}-image-macro.pdf)
      = Document Title
      :doctype: book
      :front-cover-image: image:#{type == 'block' ? ':' : ''}cover.jpg[]

      content page
      END

      (expect to_file).to visually_match 'cover-page-front-cover-image-contain.pdf'
    end
  end

  it 'should resolve bare image path relative to docdir', visual: true do
    input_file = Pathname.new fixture_file 'hello.adoc'
    to_file = to_pdf_file input_file, 'cover-page-front-cover-image-path.pdf', attribute_overrides: { 'imagesdir' => 'does-not-exist', 'front-cover-image' => 'cover.jpg' }
    (expect to_file).to visually_match 'cover-page-front-cover-image-path.pdf'
  end

  it 'should scale front cover image to boundaries of page by default', visual: true do
    ['', 'fit=contain'].each do |image_opts|
      to_file = to_pdf_file <<~END, %(cover-page-front-cover-image-#{image_opts.empty? ? 'default' : 'contain'}.pdf)
      = Document Title
      :doctype: book
      :front-cover-image: image:cover.jpg[#{image_opts}]

      content page
      END

      (expect to_file).to visually_match 'cover-page-front-cover-image-contain.pdf'
    end
  end

  it 'should stretch front cover image to boundaries of page if fit=fill', visual: true do
    to_file = to_pdf_file <<~'END', 'cover-page-front-cover-image-fill.pdf'
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[fit=fill]
    :pdf-page-size: Letter

    content page
    END

    (expect to_file).to visually_match 'cover-page-front-cover-image-fill.pdf'
  end

  it 'should not scale front cover image to fit page if fit is none', visual: true do
    to_file = to_pdf_file <<~'END', 'cover-page-front-cover-image-unscaled.pdf'
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[fit=none]

    content page
    END

    (expect to_file).to visually_match 'cover-page-front-cover-image-unscaled.pdf'
  end

  it 'should scale front cover down until it is contained within the boundaries of the page', visual: true do
    ['', 'fit=scale-down'].each do |image_opts|
      to_file = to_pdf_file <<~END, %(cover-page-front-cover-image-#{image_opts.empty? ? 'max' : 'scale-down'}.pdf)
      :front-cover-image: image:cover.jpg[#{image_opts}]
      :pdf-page-size: A7

      content page
      END

      (expect to_file).to visually_match 'cover-page-front-cover-image-max.pdf'
    end
  end

  it 'should scale front cover image until it covers page if fit=cover', visual: true do
    to_file = to_pdf_file <<~'END', 'cover-page-front-cover-image-cover.pdf'
    = Document Title
    :front-cover-image: image:cover.jpg[fit=cover]

    content page
    END

    (expect to_file).to visually_match 'cover-page-front-cover-image-cover.pdf'
  end

  it 'should scale front cover image with aspect ratio taller than page until it covers page if fit=cover' do
    pdf_page_size = get_page_size (to_pdf 'content', attribute_overrides: { 'pdf-page-size' => 'Letter' }), 1

    pdf = to_pdf <<~'END', analyze: :image
    = Document Title
    :pdf-page-size: Letter
    :front-cover-image: image:cover.jpg[fit=cover]

    content page
    END

    images = pdf.images
    (expect images).to have_size 1
    cover_image = images[0]
    (expect cover_image[:x].to_f).to eql 0.0
    (expect cover_image[:width]).to eql pdf_page_size[0].to_f
    (expect cover_image[:height]).to be > pdf_page_size[1]
    (expect cover_image[:y]).to be > pdf_page_size[1]
  end

  it 'should position front cover image as specified by position attribute', visual: true do
    to_file = to_pdf_file <<~'END', 'cover-page-front-cover-image-positioned.pdf'
    = Document Title
    :front-cover-image: image:square.svg[fit=none,pdfwidth=50%,position=top right]

    content page
    END

    (expect to_file).to visually_match 'cover-page-front-cover-image-positioned.pdf'
  end

  it 'should use specified image format', visual: true do
    source_file = (dest_file = fixture_file 'square') + '.svg'
    FileUtils.cp source_file, dest_file
    to_file = to_pdf_file <<~'END', 'cover-page-front-cover-image-format.pdf'
    = Document Title
    :front-cover-image: image:square[format=svg]

    content page
    END

    (expect to_file).to visually_match 'cover-page-front-cover-image-format.pdf'
  ensure
    File.unlink dest_file
  end

  it 'should set the base font for a book when front cover image is a PDF and title page is off' do
    pdf = to_pdf <<~END, analyze: true
    = Document Title
    :front-cover-image: #{fixture_file 'blue-letter.pdf', relative: true}
    :doctype: book
    :notitle:

    content
    END

    (expect (pdf.find_unique_text 'content')[:font_name]).to eql 'NotoSerif'
  end

  it 'should set the base font for an article when front cover image is a PDF and title page is off' do
    pdf = to_pdf <<~END, analyze: true
    = Document Title
    :front-cover-image: #{fixture_file 'blue-letter.pdf', relative: true}

    content
    END

    (expect (pdf.find_unique_text 'content')[:font_name]).to eql 'NotoSerif'
  end

  it 'should not allow page size of PDF cover page to affect page size of document' do
    input = <<~END
    = Document Title
    :front-cover-image: #{fixture_file 'blue-letter.pdf', relative: true}

    content
    END

    pdf = to_pdf input, analyze: :rect
    rects = pdf.rectangles
    (expect rects).to have_size 1
    (expect rects[0]).to eql point: [0.0, 0.0], width: 612.0, height: 792.0, fill_color: '0000FF', page_number: 1

    pdf = to_pdf input, analyze: true
    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0][:text]).to be_empty
    (expect pdf.pages[0][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LETTER']
    (expect pdf.pages[1][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
    (expect pdf.pages[1][:text]).not_to be_empty
  end

  it 'should import specified page from PDF file defined using front-cover-image attribute' do
    pdf = to_pdf <<~'END'
    :front-cover-image: image:red-green-blue.pdf[page=3]

    content
    END
    (expect pdf.pages).to have_size 2
    page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
    (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 1.0 scn']
  end

  it 'should import specified page from PDF file defined using cover_front_image theme key' do
    pdf_theme = { cover_front_image: %(image:#{fixture_file 'red-green-blue.pdf'}[page=3]) }
    pdf = to_pdf 'content', pdf_theme: pdf_theme
    (expect pdf.pages).to have_size 2
    page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
    (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 1.0 scn']
  end

  it 'should not add front cover if reference page in PDF file does not exist' do
    pdf = to_pdf <<~'END'
    :front-cover-image: image:red-green-blue.pdf[page=10]

    one

    <<<

    two
    END

    (expect pdf.pages).to have_size 2
    (expect (pdf.page 1).text).to eql 'one'
    outline = extract_outline pdf
    (expect outline[0][:title]).to eql 'Untitled'
    (expect outline[0][:dest][:label]).to eql '1'
  end

  it 'should add back cover using referenced page in PDF file' do
    pdf = to_pdf <<~'END'
    :back-cover-image: image:red-green-blue.pdf[page=3]

    content
    END

    (expect pdf.pages).to have_size 2
    (expect (pdf.page 1).text).to eql 'content'
    page_contents = pdf.objects[(pdf.page 2).page_object[:Contents][0]].data
    (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 1.0 scn']
  end

  it 'should not add back cover if referenced page in PDF file does not exist' do
    pdf = to_pdf <<~'END'
    :back-cover-image: image:red-green-blue.pdf[page=10]

    content
    END

    (expect pdf.pages).to have_size 1
    (expect (pdf.page 1).text).to eql 'content'
  end

  it 'should not add front cover if PDF file has no pages' do
    pdf = to_pdf <<~'END'
    :front-cover-image: image:no-pages.pdf[]

    one

    <<<

    two
    END

    (expect pdf.pages).to have_size 2
    (expect (pdf.page 1).text).to eql 'one'
    outline = extract_outline pdf
    (expect outline[0][:title]).to eql 'Untitled'
    (expect outline[0][:dest][:label]).to eql '1'
  end

  it 'should not add back cover if PDF file has no pages' do
    pdf = to_pdf <<~'END'
    :back-cover-image: image:no-pages.pdf[]

    content
    END

    (expect pdf.pages).to have_size 1
    (expect (pdf.page 1).text).to eql 'content'
  end
end
