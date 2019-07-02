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

  it 'should scale front cover image to fit page', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-exact.pdf', attributes: { 'imagesdir' => fixtures_dir }
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-exact.pdf'
  end

  it 'should recognize attribute value that uses block macro syntax', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-block-macro.pdf', attributes: { 'imagesdir' => fixtures_dir }
    = Document Title
    :doctype: book
    :front-cover-image: image::cover.jpg[]

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-exact.pdf'
  end

  it 'should scale and clip front cover image to cover whole page', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-page-front-cover-clipped.pdf', attributes: { 'imagesdir' => fixtures_dir }
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]
    :pdf-page-size: Legal

    content page
    EOS

    (expect to_file).to visually_match 'cover-page-front-cover-clipped.pdf'
  end
end
