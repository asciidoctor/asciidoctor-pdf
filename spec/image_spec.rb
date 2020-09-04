# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Image' do
  it 'should not crash when converting block image if theme is blank' do
    image_data = File.binread example_file 'wolpertinger.jpg'
    pdf = to_pdf <<~'EOS', attribute_overrides: { 'pdf-theme' => (fixture_file 'extends-nil-empty-theme.yml'), 'imagesdir' => examples_dir }
    image::wolpertinger.jpg[]
    EOS
    images = get_images pdf, 1
    (expect images).to have_size 1
    (expect images[0].data).to eql image_data
  end

  context 'imagesdir' do
    it 'should resolve target of block image relative to imagesdir', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-wolpertinger.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[,144]
      EOS

      (expect to_file).to visually_match 'image-wolpertinger.pdf'
    end

    it 'should replace block image with alt text if image is missing' do
      (expect do
        pdf = to_pdf 'image::no-such-image.png[Missing Image]', analyze: true
        (expect pdf.lines).to eql ['[Missing Image] | no-such-image.png']
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end

    it 'should show caption for missing image' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        .A missing image
        image::no-such-image.png[Missing Image]
        EOS
        (expect pdf.lines).to eql ['[Missing Image] | no-such-image.png', 'Figure 1. A missing image']
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end

    it 'should be able to customize formatting of alt text using theme' do
      pdf_theme = { image_alt_content: '%{alt} (%{target})' }
      (expect do
        pdf = to_pdf 'image::no-such-image.png[Missing Image]', pdf_theme: pdf_theme, analyze: true
        (expect pdf.lines).to eql ['Missing Image (no-such-image.png)']
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end

    it 'should skip block if image is missing an alt text is empty' do
      pdf_theme = { image_alt_content: '' }
      (expect do
        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        paragraph one

        paragraph two

        image::no-such-image.png[Missing Image]

        paragraph three
        EOS
        (expect pdf.lines).to eql ['paragraph one', 'paragraph two', 'paragraph three']
        para_one_y = (pdf.find_text 'paragraph one')[0][:y].round 2
        para_two_y = (pdf.find_text 'paragraph two')[0][:y].round 2
        para_three_y = (pdf.find_text 'paragraph three')[0][:y].round 2
        (expect para_one_y - para_two_y).to eql para_two_y - para_three_y
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end

    it 'should warn instead of crash if block image is unreadable' do
      (expect do
        image_file = fixture_file 'logo.png'
        old_mode = (File.stat image_file).mode
        FileUtils.chmod 0o000, image_file
        pdf = to_pdf 'image::logo.png[Unreadable Image]', analyze: true
        (expect pdf.lines).to eql ['[Unreadable Image] | logo.png']
      ensure
        FileUtils.chmod old_mode, image_file
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end unless windows?

    it 'should respect value of imagesdir if changed mid-document' do
      pdf = to_pdf <<~EOS, enable_footer: true, attributes: {}
      :imagesdir: #{fixtures_dir}

      image::tux.png[tux]

      :imagesdir: #{examples_dir}

      image::wolpertinger.jpg[wolpertinger]
      EOS

      (expect get_images pdf).to have_size 2
    end
  end

  context 'Alignment' do
    it 'should align block image to value of align attribute on macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-align-right-attribute.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[align=right]
      EOS

      (expect to_file).to visually_match 'image-align-right.pdf'
    end

    it 'should align block image as indicated by text alignment role on macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-align-right-attribute.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      [.text-right]
      image::wolpertinger.jpg[]
      EOS

      (expect to_file).to visually_match 'image-align-right.pdf'
    end

    it 'should align block image to value of image_align key in theme if alignment not specified on image', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-align-right-theme.pdf', pdf_theme: { image_align: 'right' }, attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[]
      EOS

      (expect to_file).to visually_match 'image-align-right.pdf'
    end
  end

  context 'Width' do
    subject { Asciidoctor::Converter.create 'pdf' }

    it 'should resolve pdfwidth in % to pt' do
      attrs = { 'pdfwidth' => '25%' }
      (expect subject.resolve_explicit_width attrs, bounds_width: 1000).to eql 250.0
    end

    it 'should resolve pdfwidth in px to pt' do
      attrs = { 'pdfwidth' => '144px' }
      (expect subject.resolve_explicit_width attrs, bounds_width: 1000).to eql 108.0
    end

    it 'should resolve pdfwidth in pc to pt' do
      attrs = { 'pdfwidth' => '12pc' }
      (expect subject.resolve_explicit_width attrs, bounds_width: 1000).to eql 144.0
    end

    it 'should resolve pdfwidth in vw' do
      attrs = { 'pdfwidth' => '50vw' }
      result = subject.resolve_explicit_width attrs, bounds_width: 1000, support_vw: true
      (expect result.to_f).to eql 50.0
      (expect result).to be_a Asciidoctor::PDF::Converter::ViewportWidth
    end

    it 'should ignore vw unit if not supported' do
      attrs = { 'pdfwidth' => '50vw' }
      result = subject.resolve_explicit_width attrs, bounds_width: 1000
      (expect result.to_f).to eql 50.0
      (expect result).not_to be_a Asciidoctor::PDF::Converter::ViewportWidth
    end

    it 'should ignore vw unit used in fallback if not supported' do
      converter = subject
      converter.instance_variable_set :@theme, build_pdf_theme({ image_width: '50vw' })
      attrs = {}
      result = subject.resolve_explicit_width attrs, bounds_width: 1000, use_fallback: true
      (expect result.to_f).to eql 50.0
      (expect result).not_to be_a Asciidoctor::PDF::Converter::ViewportWidth
    end

    it 'should resolve scaledwidth in % to pt' do
      attrs = { 'scaledwidth' => '25%' }
      (expect subject.resolve_explicit_width attrs, bounds_width: 1000).to eql 250.0
    end

    it 'should resolve scaledwidth in px to pt' do
      attrs = { 'scaledwidth' => '144px' }
      (expect subject.resolve_explicit_width attrs, bounds_width: 1000).to eql 108.0
    end

    it 'should resolve width in % to pt' do
      attrs = { 'width' => '25%' }
      (expect subject.resolve_explicit_width attrs, bounds_width: 1000).to eql 250.0
    end

    it 'should resolve unitless width in px to pt' do
      attrs = { 'width' => '100' }
      (expect subject.resolve_explicit_width attrs, bounds_width: 1000).to eql 75.0
    end

    it 'should size image using percentage width specified by pdfwidth', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-pdfwidth-percentage.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[,144,pdfwidth=25%,scaledwidth=50%]
      EOS

      (expect to_file).to visually_match 'image-pdfwidth-percentage.pdf'
    end

    it 'should size image using percentage width specified by scaledwidth', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-scaledwidth-percentage.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[,144,scaledwidth=25%]
      EOS

      (expect to_file).to visually_match 'image-pdfwidth-percentage.pdf'
    end

    it 'should size image using percentage width specified by width', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-width-percentage.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[,144,width=25%]
      EOS

      (expect to_file).to visually_match 'image-pdfwidth-percentage.pdf'
    end

    it 'should scale image to width of page when pdfwidth=100vw and align-to-page option is set', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-full-width.pdf'
      image::square.png[pdfwidth=100vw,opts=align-to-page]
      EOS

      (expect to_file).to visually_match 'image-full-width.pdf'
    end

    it 'should interpret unrecognized units as pt' do
      pdf = to_pdf <<~'EOS', analyze: :image
      Follow the image:square.jpg[pdfwidth=12ft].
      EOS

      (expect pdf.images).to have_size 1
      (expect pdf.images[0][:width]).to eql 12.0
    end

    it 'should interpret vw units as pt if align-to-page opts is not set' do
      pdf = to_pdf <<~'EOS', analyze: :image
      Follow the image:square.jpg[pdfwidth=50vw].
      EOS

      (expect pdf.images).to have_size 1
      (expect pdf.images[0][:width]).to eql 50.0
    end

    it 'should scale down image if height exceeds available space', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-png-scale-to-fit.pdf'
      :pdf-page-layout: landscape

      image::tux.png[pdfwidth=100%]
      EOS

      (expect to_file).to visually_match 'image-png-scale-to-fit.pdf'
    end

    it 'should use the numeric width defined in the theme if an explicit width is not specified', visual: true do
      [72, '72', '1in', '6pc'].each do |image_width|
        to_file = to_pdf_file <<~'EOS', 'image-numeric-fallback-width.pdf', pdf_theme: { image_width: image_width }
        image::tux.png[pdfwidth=204px]

        image::tux.png[,204]

        image::tux.png[]
        EOS

        (expect to_file).to visually_match 'image-numeric-fallback-width.pdf'
      end
    end

    it 'should use the percentage width defined in the theme if an explicit width is not specified', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-percentage-fallback-width.pdf', pdf_theme: { image_width: '50%' }
      image::tux.png[]
      EOS

      (expect to_file).to visually_match 'image-percentage-fallback-width.pdf'
    end

    it 'should use the vw width defined in theme if explicit width is not specified', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-full-width-theme.pdf', pdf_theme: { image_width: '100vw' }
      image::square.png[opts=align-to-page]
      EOS

      (expect to_file).to visually_match 'image-full-width.pdf'
    end
  end

  context 'SVG' do
    it 'should not leave gap around SVG that specifies viewBox but no width' do
      input = <<~'EOS'
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::square-viewbox-only.svg[]

      after
      EOS

      pdf = to_pdf input, analyze: :rect
      (expect pdf.rectangles).to have_size 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'after'
      (expect text[0][:y]).to eql 176.036
    end

    it 'should not leave gap around constrained SVG that specifies viewBox but no width' do
      input = <<~'EOS'
      :pdf-page-size: 200x400
      :pdf-page-margin: 0

      image::square-viewbox-only.svg[pdfwidth=50%]

      after
      EOS

      pdf = to_pdf input, analyze: :rect
      (expect pdf.rectangles).to have_size 1
      (expect pdf.rectangles[0][:point]).to eql [0.0, 200.0]
      (expect pdf.rectangles[0][:width]).to eql 200.0
      (expect pdf.rectangles[0][:height]).to eql 200.0

      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'after'
      (expect text[0][:y]).to eql 276.036
    end

    it 'should not allow inline image to affect the cursor position of the following paragraph' do
      pdf = to_pdf <<~'EOS', analyze: true
      before

      next
      EOS

      expected_gap = ((pdf.find_unique_text 'before')[:y] - (pdf.find_unique_text 'next')[:y]).round 2

      pdf = to_pdf <<~'EOS', analyze: true
      before image:tall.svg[pdfwidth=0.5in] after

      next
      EOS

      actual_gap = ((pdf.find_unique_text %r/before/)[:y] - (pdf.find_unique_text 'next')[:y]).round 2
      (expect actual_gap).to eql expected_gap
      (expect (pdf.find_unique_text %r/before/)[:y]).to eql (pdf.find_unique_text %r/after/)[:y]
    end

    it 'should set color space on page that only has image and stamp' do
      pdf = to_pdf <<~'EOS', pdf_theme: { footer_recto_right_content: 'pg {page-number}' }, enable_footer: true
      image::square.svg[]
      EOS

      (expect (pdf.page 1).text.squeeze).to eql 'pg 1'
      raw_content = (pdf.page 1).raw_content
      color_space_idx = raw_content.index <<~'EOS'
      /DeviceRGB cs
      0.0 0.0 0.0 scn
      /DeviceRGB CS
      0.0 0.0 0.0 SCN
      EOS
      stamp_idx = raw_content.index %(\n/Stamp)
      (expect color_space_idx).to be > 0
      (expect stamp_idx).to be > 0
      (expect stamp_idx).to be > color_space_idx
    end

    it 'should scale down SVG at top of page if dimensions exceed page size', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-svg-scale-to-fit-page.pdf'
      :pdf-page-size: Letter

      image::watermark.svg[pdfwidth=100%]
      EOS

      (expect to_file).to visually_match 'image-svg-scale-to-fit-page.pdf'
    end

    it 'should scale down SVG at top of page to fit image and caption if dimensions exceed page size', visual: true do
      to_file = to_pdf_file <<~EOS, 'image-svg-with-caption-scale-to-fit-page.pdf'
      :pdf-page-size: Letter

      .#{(['title text'] * 15).join ' '}
      image::watermark.svg[pdfwidth=100%]
      EOS

      (expect to_file).to visually_match 'image-svg-with-caption-scale-to-fit-page.pdf'
    end

    it 'should scale down SVG not at top of page and advance to next page if dimensions exceed page size', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-svg-scale-to-fit-next-page-with-text.pdf'
      :pdf-page-size: Letter

      push

      image

      down

      image::watermark.svg[pdfwidth=100%]
      EOS

      to_file = to_pdf_file %(image::#{to_file}[page=2]), 'image-svg-scale-to-fit-next-page.pdf'

      (expect to_file).to visually_match 'image-svg-scale-to-fit-page.pdf'
    end

    it 'should scale down SVG to fit bounds if width is set in SVG but not on image macro', visual: true do
      to_file = to_pdf_file 'image::green-bar-width.svg[]', 'image-svg-scale-to-fit-bounds.pdf'

      (expect to_file).to visually_match 'image-svg-scale-to-fit-bounds.pdf'
    end

    it 'should not scale SVG if it can fit on next page' do
      pdf = to_pdf <<~EOS, analyze: true
      #{(%w(filler) * 6).join %(\n\n)}

      image::tall.svg[]

      below first

      <<<

      image::tall.svg[]

      below second
      EOS

      below_first_text = pdf.find_unique_text 'below first'
      below_second_text = pdf.find_unique_text 'below second'
      (expect below_first_text[:y]).to eql below_second_text[:y]
      (expect below_first_text[:page_number]).to be 2
      (expect below_second_text[:page_number]).to be 3
    end

    it 'should scale down inline SVG to fit height of page' do
      input = <<~'EOS'
      :pdf-page-size: 200x350
      :pdf-page-margin: 0

      image:tall.svg[]
      EOS

      pdf = to_pdf input, analyze: :line
      image_h = pdf.lines[1][:to][:y] - pdf.lines[1][:from][:y]
      (expect image_h).to be_within(1).of(350)
    end

    it 'should display text inside link' do
      pdf = to_pdf <<~'EOS', analyze: true
      image::svg-with-link.svg[]
      EOS

      text = pdf.find_text 'Text with link'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'mplus1mn-regular'
      (expect text[0][:font_size].to_f).to eql 12.0
      (expect text[0][:font_color]).to eql 'AA0000'
    end

    it 'should map font names in SVG to font names in document font catalog' do
      pdf = to_pdf <<~'EOS', analyze: true
      image::svg-with-text.svg[]
      EOS

      text = pdf.find_text 'This text uses a document font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'mplus1mn-regular'
      (expect text[0][:font_size].to_f).to eql 12.0
      (expect text[0][:font_color]).to eql 'AA0000'
    end

    it 'should replace unrecognized font family with base font family' do
      pdf = to_pdf <<~'EOS', analyze: true
      image::svg-with-unknown-font.svg[]
      EOS

      text = pdf.find_text 'This text uses the default SVG font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'NotoSerif'
      (expect text[0][:font_size].to_f).to eql 12.0
      (expect text[0][:font_color]).to eql 'AA0000'
    end

    it 'should map generic font family to AFM font by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      image::svg-with-generic-font.svg[]
      EOS

      text = pdf.find_text 'This text uses the serif font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'Times-Roman'
      (expect text[0][:font_size].to_f).to eql 12.0
      (expect text[0][:font_color]).to eql 'AA0000'
    end

    it 'should allow generic font family to be mapped in font catalog' do
      pdf_theme = build_pdf_theme
      pdf_theme.font_catalog['serif'] = { 'normal' => pdf_theme.font_catalog['Noto Serif']['normal'] }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      image::svg-with-generic-font.svg[]
      EOS

      text = pdf.find_text 'This text uses the serif font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'NotoSerif'
      (expect text[0][:font_size].to_f).to eql 12.0
      (expect text[0][:font_color]).to eql 'AA0000'
    end

    it 'should replace unrecognized font family in SVG with SVG fallback font family if specified in theme' do
      [true, false].each do |block|
        pdf = to_pdf <<~EOS, pdf_theme: { svg_fallback_font_family: 'Times-Roman' }, analyze: true
        #{block ? '' : 'before'}
        image:#{block ? ':' : ''}svg-with-unknown-font.svg[pdfwidth=100%]
        #{block ? '' : 'after'}
        EOS

        text = pdf.find_text 'This text uses the default SVG font.'
        (expect text).to have_size 1
        (expect text[0][:font_name]).to eql 'Times-Roman'
        (expect text[0][:font_size].to_f).to eql 12.0
        (expect text[0][:font_color]).to eql 'AA0000'
      end
    end

    it 'should embed local image in inline image', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-local-image.pdf'
      A sign of a good writer: image:svg-with-local-image.svg[pdfwidth=1.27cm]
      EOS

      (expect to_file).to visually_match 'image-svg-with-image.pdf'
    end

    it 'should embed local image in block image', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-block-svg-with-local-image.pdf'
      image::svg-with-local-image.svg[pdfwidth=1.27cm]
      EOS

      (expect to_file).to visually_match 'image-block-svg-with-image.pdf'
    end

    it 'should use width defined in image if width not specified on inline macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-own-width.pdf'
      A sign of a good writer: image:svg-with-local-image.svg[]
      EOS

      (expect to_file).to visually_match 'image-svg-with-image.pdf'
    end

    it 'should use width defined in image if width not specified on block macro', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-block-svg-with-own-width.pdf'
      image::svg-with-local-image.svg[]
      EOS

      (expect to_file).to visually_match 'image-block-svg-with-image.pdf'
    end

    it 'should not embed remote image if allow allow-uri-read attribute is not set', visual: true do
      (expect do
        to_file = to_pdf_file <<~'EOS', 'image-svg-with-remote-image-disabled.pdf'
        A sign of a good writer: image:svg-with-remote-image.svg[]
        EOS

        (expect to_file).to visually_match 'image-svg-with-missing-image.pdf'
      end).to log_message severity: :WARN, message: %(~problem encountered in image: #{fixture_file 'svg-with-remote-image.svg'}; Error retrieving URL https://cdn.jsdelivr.net/gh/asciidoctor/asciidoctor-pdf@v1.5.0.rc.2/spec/fixtures/logo.png)
    end

    it 'should embed remote image if allow allow-uri-read attribute is set', visual: true, network: true do
      to_file = to_pdf_file <<~'EOS', 'image-svg-with-remote-image.pdf', attribute_overrides: { 'allow-uri-read' => '' }
      A sign of a good writer: image:svg-with-remote-image.svg[pdfwidth=1.27cm]
      EOS

      (expect to_file).to visually_match 'image-svg-with-image.pdf'
    end

    it 'should ignore inline option for SVG on image macro' do
      pdf = to_pdf <<~'EOS', analyze: :rect
      image::square.svg[pdfwidth=200pt,opts=inline]
      EOS
      (expect pdf.rectangles).to have_size 1
      rect = pdf.rectangles[0]
      (expect rect[:point]).to eql [48.24, 605.89]
      (expect rect[:width]).to eql 200.0
      (expect rect[:height]).to eql 200.0
    end

    it 'should fail to embed broken SVG with warning' do
      { '::' => '[Broken SVG] | broken.svg', ':' => '[Broken SVG]' }.each do |macro_delim, alt_text|
        (expect do
          pdf = to_pdf %(image#{macro_delim}broken.svg[Broken SVG]), analyze: true
          (expect pdf.lines).to eql [alt_text]
        end).to log_message severity: :WARN, message: %(~could not embed image: #{fixture_file 'broken.svg'}; Missing end tag for 'rect')
      end
    end

    it 'should pass SVG warnings in main document to logger' do
      { '::' => [48.24, 605.89], ':' => [48.24, 605.14] }.each do |macro_delim, point|
        [true, false].each do |in_block|
          (expect do
            input = %(image#{macro_delim}faulty.svg[Faulty SVG])
            input = %([%unbreakable]\n--\n#{input}\n--) if in_block
            pdf = to_pdf input, analyze: :rect
            (expect pdf.rectangles).to have_size 1
            rect = pdf.rectangles[0]
            (expect rect[:point]).to eql point
            (expect rect[:width]).to eql 200.0
            (expect rect[:height]).to eql 200.0
          end).to log_message severity: :WARN, message: %(~problem encountered in image: #{fixture_file 'faulty.svg'}; Unknown tag 'foobar')
        end
      end
    end

    it 'should render linear gradient in SVG', visual: true do
      to_file = to_pdf_file 'image::gradient.svg[pdfwidth=100%]', 'image-svg-with-gradient.pdf'
      (expect to_file).to visually_match 'image-svg-with-gradient.pdf'
    end

    it 'should set graphic state for running content when image occupies whole page' do
      pdf_theme = {
        footer_recto_right_content: %(image:#{fixture_file 'svg-with-text.svg'}[]),
        footer_verso_left_content: %(image:#{fixture_file 'svg-with-text.svg'}[]),
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true
      before

      image::tall.svg[pdfwidth=50%]

      after
      EOS

      (expect pdf.pages).to have_size 3
      page_contents = pdf.objects[(pdf.page 2).page_object[:Contents]].data
      (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 0.0 scn']
    end

    it 'should set graphic state for running content when image does not occupy whole page' do
      pdf_theme = {
        footer_recto_right_content: %(image:#{fixture_file 'svg-with-text.svg'}[]),
        footer_verso_left_content: %(image:#{fixture_file 'svg-with-text.svg'}[]),
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true
      first

      <<<

      before

      image::tall.svg[pdfwidth=25%]

      after
      EOS

      (expect pdf.pages).to have_size 2
      [1, 2].each do |pagenum|
        page_contents = pdf.objects[(pdf.page pagenum).page_object[:Contents]].data
        (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.2 0.2 0.2 scn']
      end
    end
  end

  context 'Raster' do
    it 'should embed JPG image' do
      pdf = to_pdf 'image::cover.jpg[]', pdf_theme: { page_size: 'Letter' }, analyze: :image
      images = pdf.images
      (expect images).to have_size 1
      image = pdf.images[0]
      (expect image[:page_number]).to be 1
      (expect image[:intrinsic_width]).to eql 287
      (expect image[:x]).to eql 48.24
      (expect image[:y]).to eql 756.0
      (expect image[:width]).to eql 287 * 0.75
      (expect image[:data]).to eql File.binread fixture_file 'cover.jpg'
    end

    it 'should embed PNG image', visual: true do
      to_file = to_pdf_file 'image::tux.png[]', 'image-png-implicit-width.pdf'

      (expect to_file).to visually_match 'image-png-implicit-width.pdf'
    end

    it 'should set color space on page that only has image and stamp' do
      pdf = to_pdf <<~'EOS', pdf_theme: { footer_recto_right_content: 'pg {page-number}' }, enable_footer: true
      image::tux.png[]
      EOS

      (expect (pdf.page 1).text.squeeze).to eql 'pg 1'
      raw_content = (pdf.page 1).raw_content
      color_space_idx = raw_content.index <<~'EOS'
      /DeviceRGB cs
      0.0 0.0 0.0 scn
      /DeviceRGB CS
      0.0 0.0 0.0 SCN
      EOS
      stamp_idx = raw_content.index %(\n/Stamp)
      (expect color_space_idx).to be > 0
      (expect stamp_idx).to be > 0
      (expect stamp_idx).to be > color_space_idx
    end

    it 'should scale down image not at top of page and advance to next page if dimensions exceed page size' do
      pdf_theme = { page_size: 'Letter', page_margin: 50 }
      expected_top = (to_pdf 'image::cover.jpg[pdfwidth=1in]', pdf_theme: pdf_theme, analyze: :image).images[0][:y]
      expected_height = 11 * 72.0 - 100
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :image
      before

      image::cover.jpg[pdfwidth=100%]
      EOS

      images = pdf.images
      (expect images).to have_size 1
      image = images[0]
      (expect image[:page_number]).to be 2
      (expect image[:y]).to eql expected_top
      (expect image[:height]).to eql expected_height
    end

    it 'should not scale image if it can fit on next page' do
      reference_width = (to_pdf 'image::cover.jpg[]', analyze: :image).images[0][:width]

      pdf = to_pdf <<~EOS, analyze: :image
      :pdf-page-size: A5

      #{(%w(filler) * 8).join %(\n\n)}

      image::cover.jpg[]
      EOS

      (expect pdf.images[0][:width]).to eql reference_width
    end

    it 'should fail to embed interlaced PNG image with warning' do
      { '::' => '[Interlaced PNG] | interlaced.png', ':' => '[Interlaced PNG]' }.each do |macro_delim, alt_text|
        (expect do
          pdf = to_pdf %(image#{macro_delim}interlaced.png[Interlaced PNG]), analyze: true
          (expect pdf.lines).to eql [alt_text]
        end).to log_message severity: :WARN, message: %(could not embed image: #{fixture_file 'interlaced.png'}; PNG uses unsupported interlace method; install prawn-gmagick gem to add support)
      end
    end unless defined? GMagick::Image

    it 'should embed interlaced PNG image if prawn-gmagick is available' do
      ['::', ':'].each do |macro_delim|
        pdf = to_pdf %(image#{macro_delim}interlaced.png[Interlaced PNG]), analyze: :image
        (expect pdf.images).to have_size 1
      end
    end if defined? GMagick::Image

    it 'should not suggest installing prawn-gmagick if gem has already been loaded' do
      ['::', ':'].each do |macro_delim|
        (expect do
          pdf = to_pdf %(image#{macro_delim}lorem-ipsum.yml[Unrecognized image format]), analyze: :image
          (expect pdf.images).to have_size 0
        end).to log_message severity: :WARN, message: %(could not embed image: #{fixture_file 'lorem-ipsum.yml'}; image file is an unrecognised format)
      end
    end if defined? GMagick::Image

    it 'should set graphic state for running content when image occupies whole page' do
      pdf_theme = {
        footer_recto_right_content: %(image:#{fixture_file 'svg-with-text.svg'}[]),
        footer_verso_left_content: %(image:#{fixture_file 'svg-with-text.svg'}[]),
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true
      :pdf-page-size: Letter

      before

      image::cover.jpg[pdfwidth=100%]

      after
      EOS

      (expect pdf.pages).to have_size 3
      page_contents = pdf.objects[(pdf.page 2).page_object[:Contents]].data
      (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 0.0 scn']
    end
  end

  context 'BMP' do
    it 'should warn and replace block image with alt text if image format is unsupported' do
      (expect do
        pdf = to_pdf 'image::waterfall.bmp[Waterfall,240]', analyze: true
        (expect pdf.lines).to eql ['[Waterfall] | waterfall.bmp']
      end).to log_message severity: :WARN, message: '~could not embed image'
    end unless defined? GMagick::Image

    it 'should embed image if prawn-gmagick is available' do
      pdf = to_pdf 'image::waterfall.bmp[Waterfall,240]', analyze: :image
      (expect pdf.images).to have_size 1
      image = pdf.images[0]
      (expect image[:intrinsic_width]).to eql 240
      (expect image[:width]).to eql 180.0
    end if defined? GMagick::Image
  end

  context 'GIF' do
    it 'should warn and replace block image with alt text if image format is unsupported' do
      (expect do
        pdf = to_pdf 'image::tux.gif[Tux]', analyze: true
        (expect pdf.lines).to eql ['[Tux] | tux.gif']
      end).to log_message severity: :WARN, message: '~GIF image format not supported. Install the prawn-gmagick gem or convert tux.gif to PNG.'
    end unless defined? GMagick::Image

    it 'should warn and replace inline image with alt text if image format is unsupported' do
      (expect do
        pdf = to_pdf 'image:tux.gif[Tux,16] is always a good sign.', analyze: true
        (expect pdf.lines).to eql ['[Tux] is always a good sign.']
      end).to log_message severity: :WARN, message: '~GIF image format not supported. Install the prawn-gmagick gem or convert tux.gif to PNG.'
    end unless defined? GMagick::Image

    it 'should embed block image if prawn-gmagick is available' do
      pdf = to_pdf 'image::tux.gif[Tux]', analyze: :image
      (expect pdf.images).to have_size 1
      image = pdf.images[0]
      (expect image[:intrinsic_width]).to eql 204
      (expect image[:width]).to eql 153.0
    end if defined? GMagick::Image

    it 'should embed inline image if prawn-gmagick is available' do
      pdf = to_pdf 'image:tux.gif[Tux,16] is always a good sign.', analyze: :image
      (expect pdf.images).to have_size 1
      image = pdf.images[0]
      (expect image[:intrinsic_width]).to eql 204
      (expect image[:width]).to eql 12.0
    end if defined? GMagick::Image
  end

  context 'PDF' do
    it 'should replace block macro with alt text if PDF is missing' do
      (expect do
        pdf = to_pdf 'image::missing.pdf[PDF insert]', analyze: true
        (expect pdf.lines).to eql ['[PDF insert] | missing.pdf']
      end).to log_message severity: :WARN, message: '~pdf to insert not found or not readable'
    end

    it 'should replace block macro with alt text if remote PDF is missing' do
      image_url = nil
      (expect do
        pdf, image_url = with_local_webserver do |base_url|
          target = %(#{base_url}/missing.pdf)
          result = to_pdf %(image::#{target}[Remote PDF insert]), attribute_overrides: { 'allow-uri-read' => '' }, analyze: true
          [result, target]
        end
        (expect pdf.lines).to eql [%([Remote PDF insert] | #{image_url})]
      end).to log_message severity: :WARN, message: %(~could not retrieve remote image: #{image_url})
    end

    it 'should insert page at location of block macro if target is a PDF' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      before

      image::blue-letter.pdf[]

      after
      EOS

      pages = pdf.pages
      (expect pages).to have_size 3
      (expect pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
      (expect pages[0][:text][-1][:string]).to eql '1'
      (expect pages[1][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LETTER']
      # NOTE: no running content on imported pages
      (expect pages[1][:text]).to be_empty
      (expect pages[2][:text][-1][:string]).to eql '3'
    end

    it 'should replace empty page at location of block macro if target is a PDF' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      :page-background-image: image:bg.png[]

      before

      <<<

      image::blue-letter.pdf[]

      <<<

      after
      EOS

      pages = pdf.pages
      (expect pages).to have_size 3
      (expect pages[0][:size]).to eql PDF::Core::PageGeometry::SIZES['A4']
      (expect pages[0][:text][-1][:string]).to eql '1'
      (expect pages[1][:size].map(&:to_f)).to eql PDF::Core::PageGeometry::SIZES['LETTER']
      # NOTE: no running content on imported pages
      (expect pages[1][:text]).to be_empty
      (expect pages[2][:text][-1][:string]).to eql '3'
    end

    it 'should not break internal references when PDF is imported on first page' do
      pdf = to_pdf <<~'EOS', enable_footer: true, attribute_overrides: { 'pdf-page-size' => 'Letter' }
      image::blue-letter.pdf[]

      see <<Section>>

      <<<

      == Section

      go to <<__anchor-top,top>>

      go to <<last>>

      <<<

      [#last]
      last
      EOS

      names = get_names pdf
      (expect names).to have_size 3
      (expect names.keys).to eql %w(__anchor-top _section last)
      top_dest = pdf.objects[names['__anchor-top']]
      top_page_num = get_page_number pdf, top_dest[0]
      (expect top_page_num).to be 1
      last_dest = pdf.objects[names['last']]
      last_page_num = get_page_number pdf, last_dest[0]
      (expect last_page_num).to be 4
      annotations = get_annotations pdf
      (expect annotations).to have_size 3
      (expect annotations.map {|it| it[:Dest] }).to eql %w(_section __anchor-top last)
    end

    it 'should only import first page of multi-page PDF file by default' do
      pdf = to_pdf 'image::red-green-blue.pdf[]'
      (expect pdf.pages).to have_size 1
      page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '1.0 0.0 0.0 scn']
    end

    it 'should import specified page from PDF file' do
      pdf = to_pdf 'image::red-green-blue.pdf[page=2]'
      (expect pdf.pages).to have_size 1
      page_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (page_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 1.0 0.0 scn']
    end

    it 'should not insert blank page between consecutive PDF page imports' do
      pdf = to_pdf <<~'EOS'
      image::red-green-blue.pdf[page=1]
      image::red-green-blue.pdf[page=2]
      EOS
      (expect pdf.pages).to have_size 2
      p1_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (p1_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '1.0 0.0 0.0 scn']
      p2_contents = pdf.objects[(pdf.page 2).page_object[:Contents][0]].data
      (expect (p2_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 1.0 0.0 scn']
    end

    it 'should insert all pages specified by pages attribute without leaving blank pages in between' do
      ['pages="3,1,2"', 'pages=3;1..2'].each do |pages_attr|
        pdf = to_pdf <<~EOS
        image::red-green-blue.pdf[#{pages_attr}]
        EOS
        (expect pdf.pages).to have_size 3
        p1_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
        (expect (p1_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 1.0 scn']
        p2_contents = pdf.objects[(pdf.page 2).page_object[:Contents][0]].data
        (expect (p2_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '1.0 0.0 0.0 scn']
        p3_contents = pdf.objects[(pdf.page 3).page_object[:Contents][0]].data
        (expect (p3_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 1.0 0.0 scn']
      end
    end

    it 'should ignore page numbers not found in imported PDF' do
      pdf = to_pdf <<~'EOS'
      image::red-green-blue.pdf[pages=1..10]
      EOS
      (expect pdf.pages).to have_size 3
      p1_contents = pdf.objects[(pdf.page 1).page_object[:Contents][0]].data
      (expect (p1_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '1.0 0.0 0.0 scn']
      p2_contents = pdf.objects[(pdf.page 2).page_object[:Contents][0]].data
      (expect (p2_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 1.0 0.0 scn']
      p3_contents = pdf.objects[(pdf.page 3).page_object[:Contents][0]].data
      (expect (p3_contents.split ?\n).slice 0, 3).to eql ['q', '/DeviceRGB cs', '0.0 0.0 1.0 scn']
    end

    it 'should add destination to top of imported page if ID is specified' do
      pdf = to_pdf <<~'EOS'
      go to <<red>>

      .Red Page
      [#red]
      image::red-green-blue.pdf[page=1]
      EOS

      (expect get_names pdf).to have_key 'red'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'red'
      (expect (pdf.page 1).text).to include 'Red Page'
    end

    it 'should add destination to top of first import page if ID is specified' do
      pdf = to_pdf <<~'EOS'
      go to <<red>>

      .Red Page
      [#red]
      image::red-green-blue.pdf[pages=1..3]
      EOS

      (expect get_names pdf).to have_key 'red'
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      (expect annotations[0][:Dest]).to eql 'red'
      (expect (pdf.page 1).text).to include 'Red Page'
    end
  end

  context 'Data URI' do
    it 'should embed block image if target is a JPG data URI' do
      image_data = File.binread fixture_file 'square.jpg'
      encoded_image_data = Base64.strict_encode64 image_data
      pdf = to_pdf %(image::data:image/jpg;base64,#{encoded_image_data}[])
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 5
      (expect images[0].hash[:Height]).to be 5
      (expect images[0].data).to eql image_data
    end

    it 'should embed block image if target is an SVG data URI' do
      image_data = File.read (fixture_file 'square.svg'), mode: 'r:UTF-8'
      encoded_image_data = Base64.strict_encode64 image_data
      pdf = to_pdf %(image::data:image/svg+xml;base64,#{encoded_image_data}[]), analyze: :rect
      (expect pdf.rectangles).to have_size 1
    end

    it 'should embed inline image if target is a JPG data URI' do
      image_data = File.binread fixture_file 'square.jpg'
      encoded_image_data = Base64.strict_encode64 image_data
      pdf = to_pdf %(image:data:image/jpg;base64,#{encoded_image_data}[] base64)
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Width]).to be 5
      (expect images[0].hash[:Height]).to be 5
      (expect images[0].data).to eql image_data
    end

    it 'should embed inline image if target is an SVG data URI' do
      image_data = File.read (fixture_file 'square.svg'), mode: 'r:UTF-8'
      encoded_image_data = Base64.strict_encode64 image_data
      pdf = to_pdf %(image:data:image/svg+xml;base64,#{encoded_image_data}[]), analyze: :rect
      (expect pdf.rectangles).to have_size 1
    end
  end

  context 'Remote' do
    it 'should warn and show alt text with URL if block image is remote and allow-uri-read is not set' do
      (expect do
        image_url = nil
        pdf = with_local_webserver do |base_url|
          image_url = %(#{base_url}/logo.png)
          to_pdf %(image::#{image_url}[Remote Image]), analyze: true
        end
        (expect pdf.lines).to eql [%([Remote Image] | #{image_url})]
      end).to log_message severity: :WARN, message: '~allow-uri-read is not enabled; cannot embed remote image'
    end

    it 'should warn and show alt text if inline image is remote and allow-uri-read is not set' do
      (expect do
        image_url = nil
        pdf = with_local_webserver do |base_url|
          image_url = %(#{base_url}/logo.png)
          to_pdf %(Observe image:#{image_url}[Remote Image]), analyze: true
        end
        (expect pdf.lines).to eql ['Observe [Remote Image]']
      end).to log_message severity: :WARN, message: '~allow-uri-read is not enabled; cannot embed remote image'
    end

    it 'should read remote image if allow-uri-read is set' do
      converter, pdf = with_local_webserver do |base_url|
        doc = to_pdf %(image::#{base_url}/logo.png[Remote Image]), analyze: :document, to_file: (pdf_io = StringIO.new), attribute_overrides: { 'allow-uri-read' => '' }
        [doc.converter, (PDF::Reader.new pdf_io)]
      end
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect (pdf.page 1).text).to be_empty
      # NOTE: we could assert no log messages instead, but that assumes the remove_tmp_files method is even called
      (expect converter.instance_variable_get :@tmp_files).to be_empty
    end

    it 'should read image if allow-uri-read is set and imagesdir is a URL' do
      pdf = with_local_webserver do |base_url|
        to_pdf %(image::logo.png[Remote Image]), attribute_overrides: { 'allow-uri-read' => '', 'imagesdir' => %(#{base_url}/) }
      end
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect (pdf.page 1).text).to be_empty
    end

    it 'should read remote image with no file extension if allow-uri-read is set' do
      FileUtils.cp (fixture_file 'logo.png'), (fixture_file 'logo')
      pdf = with_local_webserver do |base_url|
        to_pdf %(image::#{base_url}/logo[Remote Image]), attribute_overrides: { 'allow-uri-read' => '' }
      end
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect images[0].hash[:Filter]).to eql [:FlateDecode]
      (expect (pdf.page 1).text).to be_empty
    ensure
      File.unlink fixture_file 'logo'
    end

    it 'should only read remote image once if allow-uri-read is set' do
      pdf = with_local_webserver do |base_url, thr|
        image_macro = %(image::#{base_url}/logo.png[Remote Image])
        result = to_pdf <<~EOS, attribute_overrides: { 'allow-uri-read' => '' }
        #{image_macro}

        ====
        #{image_macro}
        ====
        EOS
        requests = thr[:requests]
        (expect requests).to have_size 1
        (expect requests[0]).to include '/logo.png'
        result
      end
      images = get_images pdf, 1
      (expect images).to have_size 2
      (expect (pdf.page 1).text).to be_empty
    end

    it 'should only read missing remote image once if allow-uri-read is set' do
      with_local_webserver do |base_url, thr|
        image_url = %(#{base_url}/no-such-image.png)
        (expect do
          image_macro = %(image::#{image_url}[Remote Image])
          pdf = to_pdf <<~EOS, attribute_overrides: { 'allow-uri-read' => '' }
          #{image_macro}

          ====
          #{image_macro}
          ====
          EOS
          requests = thr[:requests]
          (expect requests).to have_size 1
          (expect requests[0]).to include '/no-such-image.png'
          images = get_images pdf, 1
          (expect images).to have_size 0
          text = (pdf.page 1).text
          (expect (text.scan %([Remote Image] | #{image_url})).size).to eql 2
        end).to log_message severity: :WARN, message: %(~could not retrieve remote image: #{image_url}; 404 Not Found)
      end
    end

    it 'should read same remote image for each unique query string if allow-uri-read is set' do
      with_local_webserver do |base_url, thr|
        pdf = to_pdf <<~EOS, attribute_overrides: { 'allow-uri-read' => '' }
        image::#{base_url}/logo.png?v=1[Remote Image,format=png]

        image::#{base_url}/logo.png?v=2[Remote Image,format=png]
        EOS
        requests = thr[:requests]
        (expect requests).to have_size 2
        (expect requests[0]).to include '/logo.png?v=1'
        (expect requests[1]).to include '/logo.png?v=2'
        images = get_images pdf, 1
        (expect images).to have_size 2
        (expect (pdf.page 1).text).to be_empty
      end
    end

    it 'should only read remote image once if used in both main and running content if allow-uri-read is set' do
      pdf = with_local_webserver do |base_url, thr|
        pdf_theme = {
          header_height: 30,
          header_columns: '=100%',
          header_recto_center_content: %(image:#{base_url}/logo.png[Remote Image]),
          footer_columns: '=100%',
          footer_recto_center_content: %(image:#{base_url}/logo.png[Remote Image]),
        }
        result = to_pdf <<~EOS, pdf_theme: pdf_theme, enable_footer: true, attribute_overrides: { 'allow-uri-read' => '' }
        image::#{base_url}/logo.png[Remote Image]
        EOS
        requests = thr[:requests]
        (expect requests).to have_size 1
        (expect requests[0]).to include '/logo.png'
        result
      end
      images = get_images pdf, 1
      (expect images).to have_size 3
      (expect (pdf.page 1).text).to be_empty
    end

    it 'should read remote image over HTTPS if allow-uri-read is set', network: true do
      pdf = to_pdf 'image::https://cdn.jsdelivr.net/gh/asciidoctor/asciidoctor-pdf@v1.5.0.rc.2/spec/fixtures/logo.png[Remote Image]', attribute_overrides: { 'allow-uri-read' => '' }
      images = get_images pdf, 1
      (expect images).to have_size 1
      (expect (pdf.page 1).text).to be_empty
    end

    it 'should log warning if remote image cannot be fetched' do
      with_local_webserver do |base_url|
        image_url = %(#{base_url}/no-such-image.png)
        (expect do
          pdf = to_pdf %(image::#{image_url}[No Such Image]), attribute_overrides: { 'allow-uri-read' => '' }, analyze: true
          (expect pdf.lines).to eql [%([No Such Image] | #{image_url})]
        end).to log_message severity: :WARN, message: %(~could not retrieve remote image: #{image_url}; 404 Not Found)
      end
    end

    it 'should use image format specified by format attribute' do
      pdf = with_local_webserver do |base_url|
        to_pdf <<~EOS, attribute_overrides: { 'allow-uri-read' => '' }, analyze: :rect
        :pdf-page-size: 200x400
        :pdf-page-margin: 0

        image::#{base_url}/square.svg?v=1[format=svg,pdfwidth=100%]
        EOS
      end
      (expect pdf.rectangles).to have_size 1
      rect = pdf.rectangles[0]
      (expect rect[:point]).to eql [0.0, 200.0]
      (expect rect[:width]).to eql 200.0
      (expect rect[:height]).to eql 200.0
    end

    it 'should not inherit format from document' do
      (expect do
        FileUtils.cp (fixture_file 'square.svg'), (fixture_file 'square')
        pdf = with_local_webserver do |base_url|
          to_pdf <<~EOS, attribute_overrides: { 'allow-uri-read' => '' }, analyze: :rect
          :pdf-page-size: 200x400
          :pdf-page-margin: 0
          :format: svg

          image::#{base_url}/square[pdfwidth=100%]
          EOS
        ensure
          File.unlink fixture_file 'square'
        end
        (expect pdf.rectangles).to be_empty
      end).to log_message severity: :WARN, message: %(~image file is an unrecognised format)
    end

    context 'Cache' do
      before :context do
        (expect defined? OpenURI::Cache).to be_falsy
        with_local_webserver do |base_url|
          to_pdf %(image::#{base_url}/logo.png[]), attribute_overrides: { 'allow-uri-read' => '', 'cache-uri' => '' }
        end
        (expect defined? OpenURI::Cache).to be_truthy
        OpenURI::Cache.cache_path = output_file 'open-uri-cache'
      end

      after :context do
        OpenURI.singleton_class.send :remove_method, :open_uri
        OpenURI.singleton_class.send :alias_method, :open_uri, :original_open_uri
      end

      before do
        FileUtils.rm_r OpenURI::Cache.cache_path, force: true, secure: true
      end

      it 'should cache remote image if cache-uri document attribute is set' do
        with_local_webserver do |base_url, thr|
          image_url = %(#{base_url}/logo.png)
          (expect OpenURI::Cache.get image_url).to be_nil
          2.times do
            pdf = to_pdf %(image::#{image_url}[Remote Image]), attribute_overrides: { 'allow-uri-read' => '', 'cache-uri' => '' }
            requests = thr[:requests]
            (expect requests).to have_size 1
            (expect requests[0]).to include '/logo.png'
            (expect OpenURI::Cache.get image_url).not_to be_nil
            images = get_images pdf, 1
            (expect images).to have_size 1
            (expect (pdf.page 1).text).to be_empty
          end
          OpenURI::Cache.invalidate image_url
        end
      end
    end unless (Gem::Specification.stubs_for 'open-uri-cached').empty?
  end

  context 'Inline' do
    it 'should resolve target of inline image relative to imagesdir', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline.pdf', attribute_overrides: { 'imagesdir' => examples_dir }
      image:sample-logo.jpg[ACME,12] ACME products are the best!
      EOS

      (expect to_file).to visually_match 'image-inline.pdf'
    end

    it 'should replace inline image with alt text if image is missing' do
      (expect do
        pdf = to_pdf 'You cannot see that which is image:not-there.png[not there].', analyze: true
        (expect pdf.lines).to eql ['You cannot see that which is [not there].']
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end

    it 'should not fail to parse inline image if alt text contains a double quote character' do
      (expect do
        pdf = to_pdf 'Look for image:logo.png[the "no cow" brand] when you buy.', analyze: :image
        (expect pdf.images).to have_size 1
      end).to not_log_message
    end

    it 'should warn instead of crash if inline image is unreadable' do
      (expect do
        image_file = fixture_file 'logo.png'
        old_mode = (File.stat image_file).mode
        FileUtils.chmod 0o000, image_file
        pdf = to_pdf 'image:logo.png[Unreadable Image,16] Company Name', analyze: true
        (expect pdf.lines).to eql ['[Unreadable Image] Company Name']
      ensure
        FileUtils.chmod old_mode, image_file
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end unless windows?

    # NOTE: this test also verifies space is allocated for an inline image at the start of a line
    it 'should convert multiple images on the same line', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-multiple-inline.pdf'
      image:logo.png[Asciidoctor,12] is developed on image:tux.png[Linux,12].
      EOS

      (expect to_file).to visually_match 'image-multiple-inline.pdf'
    end

    it 'should not mangle character spacing in line if inline image wraps', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-wrap-inline.pdf'
      [cols="30e,58,12",width=75%]
      |===
      |Name |Description |Min # data points

      |Confidence interval of the mean
      |The confidence interval of the mean is image:equation.svg[width=118], where image:symbol-m.svg[width=11] is the mean, image:symbol-s.svg[width=6] is the estimated sample standard deviation, and so on.
      |2

      |Confidence interval of the mean
      a|The confidence interval of the mean is image:equation.svg[width=118], where image:symbol-m.svg[width=11] is the mean, image:symbol-s.svg[width=6] is the estimated sample standard deviation, and so on.
      |2
      |===
      EOS

      (expect to_file).to visually_match 'image-wrap-inline.pdf'
    end

    it 'should increase line height if height if image height is more than 1.5x line height', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline-extends-line-height.pdf'
      see tux run +
      see image:tux.png[tux] run +
      see tux run
      EOS

      (expect to_file).to visually_match 'image-inline-extends-line-height.pdf'
    end

    it 'should not increase line height if image height does not exceed 1.5x line height' do
      pdf = to_pdf <<~'EOS', analyze: true
      see tux run +
      see tux run +
      see image:tux.png[tux,24] run
      EOS

      text = pdf.text
      line1_spacing = (text[0][:y] - text[1][:y]).round 2
      line2_spacing = (text[1][:y] - text[2][:y]).round 2
      (expect line1_spacing).to eql line2_spacing
    end

    it 'should not scale image if pdfwidth matches intrinsic width' do
      pdf = to_pdf <<~'EOS', analyze: :image
      see image:tux.png[pdfwidth=204] run
      EOS

      images = pdf.images
      (expect images).to have_size 1
      image = images[0]
      (expect image[:width]).to eql image[:intrinsic_width].to_f
      (expect image[:height]).to eql image[:intrinsic_height].to_f
    end

    it 'should scale image down to fit available height', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline-scale-down-height.pdf'
      :pdf-page-size: A6
      :pdf-page-layout: landscape

      image:cover.jpg[]
      EOS

      (expect to_file).to visually_match 'image-inline-scale-down-height.pdf'
    end

    it 'should scale image down to fit available width', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline-scale-down-width.pdf'
      :pdf-page-size: A6

      image:cover.jpg[]
      EOS

      (expect to_file).to visually_match 'image-inline-scale-down-width.pdf'
    end

    it 'should compute scaled width relative to container size' do
      midpoint = (get_page_size to_pdf 'body', analyze: true)[0] * 0.5

      input = <<~'EOS'
      ****
      ====
      ******
      ========
      left

      image:tux.png[scaledwidth=50%]midpoint
      ========
      ******
      ====
      ****
      EOS

      pdf = to_pdf input, analyze: true
      midpoint_text = pdf.find_unique_text 'midpoint'
      (expect midpoint_text[:x]).to eql midpoint
      left_text = pdf.find_unique_text 'left'

      pdf = to_pdf input, analyze: :image
      images = pdf.images
      (expect images).to have_size 1
      image = images[0]
      (expect image[:x]).to eql left_text[:x]
      (expect image[:width]).to eql ((midpoint_text[:x] - left_text[:x]).round 2)
    end

    it 'should scale image down to fit line if fit=line', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline-fit-line.pdf'
      See image:tux.png[fit=line] run.
      EOS

      (expect to_file).to visually_match 'image-inline-fit-line.pdf'
    end

    it 'should not alter character spacing of text in inline SVG image', visual: true do
      to_file = to_pdf_file <<~'EOS', 'image-inline-svg-with-text.pdf'
      before image:svg-with-text.svg[width=200] after
      EOS

      (expect to_file).to visually_match 'image-inline-svg-with-text.pdf'
    end

    it 'should size inline image with percentage width relative to page width' do
      pdf = to_pdf 'see image:tux.png[,50%] run', attribute_overrides: { 'pdf-page-size' => 'Letter' }, analyze: :image
      expected_width = (8.5 * 72 - (0.67 * 2 * 72)) * 0.5
      images = pdf.images
      (expect images).to have_size 1
      image = images[0]
      (expect image[:width]).to eql expected_width
    end
  end

  context 'Link' do
    it 'should add link around block raster image if link attribute is set' do
      pdf = to_pdf <<~'EOS'
      image::tux.png[pdfwidth=1in,link=https://www.linuxfoundation.org/projects/linux/]
      EOS

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://www.linuxfoundation.org/projects/linux/'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 72.0
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 84.7
      (expect link_rect[0]).to eql 48.24
    end

    it 'should add link around block image aligned to right' do
      input = 'image::tux.png[pdfwidth=1in,link=https://www.linuxfoundation.org/projects/linux/,align=right]'

      pdf = to_pdf input

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://www.linuxfoundation.org/projects/linux/'
      link_rect = link_annotation[:Rect]
      link_coords = { x: link_rect[0], y: link_rect[3], width: ((link_rect[2] - link_rect[0]).round 4), height: ((link_rect[3] - link_rect[1]).round 4) }

      pdf = to_pdf input, analyze: :image
      image = pdf.images[0]
      image_coords = { x: image[:x], y: image[:y], width: image[:width], height: image[:height] }
      (expect link_coords).to eql image_coords
    end

    it 'should add link around block SVG image if link attribute is set' do
      pdf = to_pdf <<~'EOS'
      image::square.svg[pdfwidth=1in,link=https://example.org]
      EOS

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 72.0
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 72.0
      (expect link_rect[0]).to eql 48.24
    end

    it 'should use link in alt text if image is missing' do
      (expect do
        pdf = to_pdf 'image::no-such-image.png[Missing Image,link=https://example.org]'
        text = (pdf.page 1).text
        (expect text).to eql '[Missing Image] | no-such-image.png'
        annotations = get_annotations pdf, 1
        (expect annotations).to have_size 1
        link_annotation = annotations[0]
        (expect link_annotation[:Subtype]).to be :Link
        (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      end).to log_message severity: :WARN, message: '~image to embed not found or not readable'
    end

    it 'should add link around inline image if link attribute is set' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'imagesdir' => examples_dir }
      image:sample-logo.jpg[ACME,pdfwidth=1pc,link=https://example.org] is a sign of quality!
      EOS

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 12.0
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 14.3
      (expect link_rect[0]).to eql 48.24
    end

    it 'should add link around inline image if image macro is enclosed in link macro' do
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'imagesdir' => examples_dir }
      https://example.org[image:sample-logo.jpg[ACME,pdfwidth=1pc]] is a sign of quality!
      EOS

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 12.0
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 14.3
      (expect link_rect[0]).to eql 48.24
    end
  end

  context 'Caption' do
    it 'should render caption under an image with a title' do
      input = <<~'EOS'
      .Tux, the Linux mascot
      image::tux.png[tux]
      EOS

      pdf = to_pdf input, analyze: :image
      images = pdf.images
      (expect images).to have_size 1
      image_bottom = images[0][:y] - images[0][:height]

      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      caption_text = text[0]
      (expect caption_text[:string]).to eql 'Figure 1. Tux, the Linux mascot'
      (expect caption_text[:font_name]).to eql 'NotoSerif-Italic'
      (expect caption_text[:y]).to be < image_bottom
    end

    it 'should set caption align to image align if theme sets caption align to inherit' do
      pdf_theme = {
        image_caption_align: 'inherit',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, attribute_overrides: { 'imagesdir' => examples_dir }, analyze: true
      .Behold, the great Wolpertinger!
      image::wolpertinger.jpg[,144,align=right]
      EOS

      midpoint = (get_page_size pdf)[0] * 0.5
      (expect pdf.text[0][:x]).to be > midpoint
    end

    it 'should restrict caption width to specified percentage of available width if max-width is percentage value' do
      pdf_theme = {
        image_caption_align: 'center',
        image_caption_max_width: '25%',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      .This is a picture of our beloved Tux.
      image::tux.png[]
      EOS

      midpoint = (get_page_size pdf, 1)[0] * 0.5
      (expect pdf.lines).to eql ['Figure 1. This is a picture', 'of our beloved Tux.']
      first_line_text, second_line_text = pdf.text
      (expect first_line_text[:x]).to be > 48.24
      (expect first_line_text[:x] + first_line_text[:width]).to be > midpoint
      (expect second_line_text[:x]).to be > first_line_text[:x]
    end

    it 'should restrict caption width to width of image if max-width is fit-content' do
      pdf_theme = {
        image_caption_align: 'inherit',
        image_caption_max_width: 'fit-content',
      }

      input = <<~'EOS'
      .This is a picture of our beloved Tux.
      image::tux.png[align=right]
      EOS

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :image

      images = pdf.images
      (expect images).to have_size 1
      tux_image = images[0]

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true

      caption_texts = pdf.text
      (expect caption_texts).to have_size 2
      caption_text_l1, caption_text_l2 = caption_texts
      (expect caption_text_l1[:y]).to be > caption_text_l2[:y]
      (expect caption_text_l1[:string]).to start_with 'Figure 1.'
      (expect caption_text_l1[:width]).to be < tux_image[:width]
      (expect caption_text_l2[:width]).to be < tux_image[:width]
      (expect caption_text_l1[:x]).to be > tux_image[:x]
      (expect caption_text_l2[:x]).to be > caption_text_l1[:x]
      (expect caption_text_l1[:x] + caption_text_l1[:width]).to be_within(1).of caption_text_l2[:x] + caption_text_l2[:width]
    end

    it 'should align caption within width of image if alignment is fixed and max-width is fit-content' do
      pdf_theme = {
        image_caption_align: 'left',
        image_caption_max_width: 'fit-content',
      }

      input = <<~'EOS'
      .This is a picture of our beloved Tux.
      image::tux.png[align=right]
      EOS

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :image

      images = pdf.images
      (expect images).to have_size 1
      tux_image = images[0]

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true

      caption_texts = pdf.text
      (expect caption_texts).to have_size 2
      caption_text_l1, caption_text_l2 = caption_texts
      (expect caption_text_l1[:y]).to be > caption_text_l2[:y]
      (expect caption_text_l1[:string]).to start_with 'Figure 1.'
      (expect caption_text_l1[:width]).to be < tux_image[:width]
      (expect caption_text_l2[:width]).to be < tux_image[:width]
      (expect caption_text_l1[:x]).to eql tux_image[:x]
      (expect caption_text_l2[:x]).to eql caption_text_l1[:x]
    end
  end

  context 'Border' do
    # NOTE: tests center alignment
    it 'should draw border around PNG image if border width and border color are set in the theme', visual: true do
      pdf_theme = {
        image_border_width: 0.5,
        image_border_color: 'DDDDDD',
        image_border_radius: 2,
      }

      to_file = to_pdf_file <<~'EOS', 'image-border.pdf', pdf_theme: pdf_theme
      .Tux
      image::tux.png[align=center]
      EOS

      (expect to_file).to visually_match 'image-border.pdf'
    end

    it 'should draw border around left-aligned PNG image if border width and border color are set in the theme', visual: true do
      pdf_theme = {
        image_border_width: 0.5,
        image_border_color: '5D5D5D',
      }

      to_file = to_pdf_file <<~'EOS', 'image-border-align-left.pdf', pdf_theme: pdf_theme
      .Tux
      image::tux.png[]
      EOS

      (expect to_file).to visually_match 'image-border-align-left.pdf'
    end

    it 'should stretch border around PNG image to bounds if border fit key is auto', visual: true do
      pdf_theme = {
        image_border_width: 0.5,
        image_border_color: 'DDDDDD',
        image_border_radius: 2,
        image_border_fit: 'auto',
      }

      to_file = to_pdf_file <<~'EOS', 'image-border-fit-page.pdf', pdf_theme: pdf_theme
      .Tux
      image::tux.png[align=center]
      EOS

      (expect to_file).to visually_match 'image-border-fit-page.pdf'
    end

    # NOTE: tests right alignment
    it 'should draw border around SVG if border width and border color are set in the theme', visual: true do
      pdf_theme = {
        image_border_width: 1,
        image_border_color: '000000',
      }

      to_file = to_pdf_file <<~'EOS', 'image-svg-border.pdf', pdf_theme: pdf_theme
      .Square
      image::square.svg[align=right,pdfwidth=25%]
      EOS

      (expect to_file).to visually_match 'image-svg-border.pdf'
    end

    it 'should stretch border around SVG to bounds if border fit key is auto', visual: true do
      pdf_theme = {
        image_border_width: 1,
        image_border_color: '000000',
        image_border_fit: 'auto',
      }

      to_file = to_pdf_file <<~'EOS', 'image-svg-border-fit-page.pdf', pdf_theme: pdf_theme
      .Square
      image::square.svg[align=center,pdfwidth=25%]
      EOS

      (expect to_file).to visually_match 'image-svg-border-fit-page.pdf'
    end

    it 'should not draw border around raster image if noborder role is present', visual: true do
      pdf_theme = {
        image_border_width: 1,
        image_border_color: '000000',
      }
      to_file = to_pdf_file <<~'EOS', 'image-raster-noborder.pdf', pdf_theme: pdf_theme, attribute_overrides: { 'imagesdir' => examples_dir }
      image::wolpertinger.jpg[,144,role=specimen noborder]
      EOS

      (expect to_file).to visually_match 'image-wolpertinger.pdf'
    end

    it 'should not draw border around SVG image if noborder role is present' do
      pdf_theme = {
        image_border_width: 1,
        image_border_color: 'DEDEDE',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: :line
      image::square-viewbox-only.svg[role=noborder]
      EOS

      (expect pdf.lines.select {|it| it[:color] == 'DEDEDE' }).to be_empty
    end
  end
end
