require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Outline' do
  it 'should create an outline to navigate the document structure' do
    pdf = to_pdf <<~'EOS', doctype: 'book'
    = Document Title

    == First Chapter

    === Chapter Section

    == Middle Chapter

    == Last Chapter
    EOS

    outline = extract_outline pdf
    (expect outline.size).to eql 4
    (expect outline[0][:title]).to eql 'Document Title'
    (expect outline[0][:dest][:pagenum]).to eql 1
    (expect outline[0][:dest][:top]).to be true
    (expect outline[0][:children].size).to eql 0
    (expect outline[1][:title]).to eql 'First Chapter'
    (expect outline[1][:dest][:pagenum]).to eql 2
    (expect outline[1][:dest][:top]).to be true
    (expect outline[1][:children].size).to eql 1
    (expect outline[1][:children][0][:title]).to eql 'Chapter Section'
    (expect outline[1][:children][0][:dest][:pagenum]).to eql 2
    (expect outline[1][:children][0][:dest][:top]).to be false
    (expect outline[1][:children][0][:children].size).to be 0
    chapter_section_ref = (get_names pdf)['_chapter_section']
    (expect chapter_section_ref).not_to be_nil
    chapter_section_obj = pdf.objects[chapter_section_ref]
    (expect outline[1][:children][0][:dest][:y]).to eql chapter_section_obj[3]
    (expect outline[1][:children][0][:dest][:pagenum]).to eql get_page_number pdf, chapter_section_obj[0]
    (expect outline[3][:title]).to eql 'Last Chapter'
    (expect outline[3][:dest][:pagenum]).to eql 4
    (expect outline[3][:dest][:top]).to be true
    (expect outline[3][:children].size).to eql 0
  end

  it 'should sanitize titles' do
    pdf = to_pdf <<~'EOS', doctype: 'book'
    = _Document_ *Title*

    == _First_ *Chapter*
    EOS

    outline = extract_outline pdf
    (expect outline.size).to eql 2
    (expect outline[0][:title]).to eql 'Document Title'
    (expect outline[1][:title]).to eql 'First Chapter'
  end

  it 'should decode character references in titles' do
    pdf = to_pdf <<~'EOS', doctype: 'book'
    = ACME(TM) Catalog <&#8470; 1>

    == Paper Clips &#x2116; 4
    EOS

    outline = extract_outline pdf
    (expect outline.size).to eql 2
    (expect outline[0][:title]).to eql %(ACME\u2122 Catalog <\u2116 1>)
    (expect outline[1][:title]).to eql %(Paper Clips \u2116 4)
  end
end
