require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Cover Pages' do
  it 'should add front cover page if front-cover-image is set' do
    pdf = to_pdf <<~'EOS', attributes: { 'imagesdir' => fixtures_dir }, analyze: true
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]

    content page
    EOS

    (expect pdf.pages.size).to eql 3
    (expect pdf.pages[0][:text]).to be_empty
  end

  it 'should scale front cover image to fit page', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-pages-front-cover-exact.pdf', attributes: { 'imagesdir' => fixtures_dir }
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]

    content page
    EOS

    (expect to_file).to visually_match 'cover-pages-front-cover-exact.pdf'
  end

  it 'should scale and clip front cover image to cover whole page', integration: true do
    to_file = to_pdf_file <<~'EOS', 'cover-pages-front-cover-clipped.pdf', attributes: { 'imagesdir' => fixtures_dir }
    = Document Title
    :doctype: book
    :front-cover-image: image:cover.jpg[]
    :pdf-page-size: Legal

    content page
    EOS

    (expect to_file).to visually_match 'cover-pages-front-cover-clipped.pdf'
  end
end
