require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Cover Page' do
  it 'should add front cover page if front-cover-image is set' do
    pdf = to_pdf <<~EOS
    = Document Title
    :front-cover-image: #{fixture_file 'cover.jpg', relative: true}

    content page
    EOS

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0].text).to be_empty
    images = pdf.pages[0].xobjects.select {|_, candidate| candidate.hash[:Subtype] == :Image }.values
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should add back cover page if back-cover-image is set' do
    pdf = to_pdf <<~EOS
    = Document Title
    :front-cover-image: #{fixture_file 'cover.jpg', relative: true}
    :back-cover-image: #{fixture_file 'cover.jpg', relative: true}

    content page
    EOS

    (expect pdf.pages).to have_size 3
    (expect pdf.pages[0].text).to be_empty
    (expect pdf.pages[2].text).to be_empty
    images = pdf.pages[2].xobjects.select {|_, candidate| candidate.hash[:Subtype] == :Image }.values
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should only add cover page if front-cover-image is set and document has no content' do
    pdf = to_pdf %(:front-cover-image: #{fixture_file 'cover.jpg', relative: true})
    (expect pdf.pages).to have_size 1
    (expect pdf.pages[0].text).to be_empty
    images = pdf.pages[0].xobjects.select {|_, candidate| candidate.hash[:Subtype] == :Image }.values
    (expect images).to have_size 1
    (expect images[0].data).to eql File.binread fixture_file 'cover.jpg'
  end

  it 'should not crash if front cover image is a URI and the allow-uri-read attribute is not set' do
    pdf = nil
    (expect {
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :front-cover-image: https://example.org/cover.svg

      content
      EOS
    }).to not_raise_exception & (log_message severity: :WARN, message: '~allow-uri-read is not enabled')
    (expect pdf.pages).to have_size 1
    (expect pdf.find_text 'Document Title').to have_size 1
  end

  it 'should recognize attribute value that uses image macro syntax', integration: true do
    %w(block inline).each do |type|
      to_file = to_pdf_file <<~EOS, %(cover-page-front-cover-#{type}-image-macro.pdf)
      = Document Title
      :doctype: book
      :front-cover-image: image:#{type == 'block' ? ':' : ''}cover.jpg[]

      content page
      EOS

      (expect to_file).to visually_match 'cover-page-front-cover-image.pdf'
    end
  end

  it 'should scale front cover image to fit page by default', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-image.pdf'
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-image.pdf'
  end

  it 'should not scale front cover image to fit page if fit is none', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-image-unscaled.pdf'
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[fit=none]

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-image-unscaled.pdf'
  end

  it 'should position front cover image as specified by position attribute', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-image-positioned.pdf'
    = Document Title
    :front-cover-image: image:square.svg[pdfwidth=50%,position=top right]

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-image-positioned.pdf'
  end

  it 'should scale front cover until it reaches the boundaries of the page', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-image-max.pdf'
    = Document Title
    :front-cover-image: image:cover.jpg[]
    :pdf-page-size: Legal

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-image-max.pdf'
  end
end
