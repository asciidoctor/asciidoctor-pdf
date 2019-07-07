require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Cover Page' do
  it 'should add front cover page if front-cover-image is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]

    content page
    EOS

    (expect pdf.pages).to have_size 3
    (expect pdf.pages[0][:text]).to be_empty
  end

  it 'should not crash if front cover image is a URI and the allow-uri-read attribute is not set' do
    pdf = nil
    (expect {
      pdf = to_pdf <<~'EOS', analyze: true
      = Document Title
      :front-cover-image: image:https://example.org/cover.svg[]

      content
      EOS
    }).to not_raise_exception & (log_message severity: :WARN, message: '~allow-uri-read is not enabled')
    (expect pdf.pages).to have_size 1
    (expect pdf.find_text 'Document Title').to have_size 1
  end

  it 'should scale front cover image to fit page', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-image.pdf'
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-image.pdf'
  end

  it 'should recognize attribute value that uses block macro syntax', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-image-block-macro.pdf'
    = Document Title
    :doctype: book
    :front-cover-image: image::cover.jpg[]

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-image.pdf'
  end

  it 'should scale and clip front cover image to cover whole page', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-image-clipped.pdf'
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]
    :pdf-page-size: Legal

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-image-clipped.pdf'
  end
end
