require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Outline' do
  it 'should create an outline to navigate the document structure' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book

    == First Chapter

    === Chapter Section

    == Middle Chapter

    == Last Chapter
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 4
    (expect outline[0][:title]).to eql 'Document Title'
    (expect outline[0][:dest][:pagenum]).to eql 1
    (expect outline[0][:dest][:top]).to be true
    (expect outline[0][:children]).to be_empty
    (expect outline[1][:title]).to eql 'First Chapter'
    (expect outline[1][:dest][:pagenum]).to eql 2
    (expect outline[1][:dest][:top]).to be true
    (expect outline[1][:closed]).to be false
    (expect outline[1][:children]).to have_size 1
    (expect outline[1][:children][0][:title]).to eql 'Chapter Section'
    (expect outline[1][:children][0][:dest][:pagenum]).to eql 2
    (expect outline[1][:children][0][:dest][:top]).to be false
    (expect outline[1][:children][0][:children]).to be_empty
    chapter_section_ref = (get_names pdf)['_chapter_section']
    (expect chapter_section_ref).not_to be_nil
    chapter_section_obj = pdf.objects[chapter_section_ref]
    (expect outline[1][:children][0][:dest][:y]).to eql chapter_section_obj[3]
    (expect outline[1][:children][0][:dest][:pagenum]).to eql get_page_number pdf, chapter_section_obj[0]
    (expect outline[3][:title]).to eql 'Last Chapter'
    (expect outline[3][:dest][:pagenum]).to eql 4
    (expect outline[3][:dest][:top]).to be true
    (expect outline[3][:children]).to be_empty
  end

  it 'should limit outline depth according to value of toclevels attribute' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book
    :toclevels: 1

    == First Chapter

    === Chapter Section

    == Middle Chapter

    == Last Chapter
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 4
    (expect outline[1][:title]).to eq 'First Chapter'
    (expect outline[1][:children]).to be_empty
  end

  it 'should allow outline depth to exceed toclevels of outlinelevels attribute is set' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book
    :toclevels: 1
    :outlinelevels: 2

    == First Chapter

    === Chapter Section

    ==== Nested Section

    == Middle Chapter

    == Last Chapter
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 4
    (expect outline[1][:title]).to eq 'First Chapter'
    (expect outline[1][:closed]).to be false
    (expect outline[1][:children]).not_to be_empty
    (expect outline[1][:children][0][:title]).to eq 'Chapter Section'
    (expect outline[1][:children][0][:children]).to be_empty
  end

  it 'should limit outline depth if value of outlinelevels attribute is less than value of toclevels attribute' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book
    :toclevels: 2
    :outlinelevels: 1

    == First Chapter

    === Chapter Section

    ==== Nested Section

    == Middle Chapter

    == Last Chapter
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 4
    (expect outline[1][:title]).to eq 'First Chapter'
    (expect outline[1][:children]).to be_empty
  end

  it 'should use second argument of outlinelevels attribute to control depth at which outline is expanded' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book
    :outlinelevels: 3:1

    == Chapter

    === Section

    ==== Subsection

    == Another Chapter

    === Another Section
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 3
    (expect outline[0][:title]).to eql 'Document Title'
    (expect outline[0][:children]).to be_empty
    (expect outline[1][:title]).to eql 'Chapter'
    (expect outline[1][:closed]).to be false
    (expect outline[1][:children]).to have_size 1
    (expect outline[1][:children][0][:title]).to eql 'Section'
    (expect outline[1][:children][0][:closed]).to be true
    (expect outline[1][:children][0][:children]).to have_size 1
    (expect outline[1][:children][0][:children][0][:title]).to eql 'Subsection'
    (expect outline[1][:children][0][:children][0][:children]).to be_empty
  end

  it 'should expand outline based on depth not level' do
    pdf = to_pdf <<~'EOS'
    = Document Title
    :doctype: book
    :outlinelevels: 3:1

    = Part

    == Chapter

    === Section
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 2
    (expect outline[0][:title]).to eql 'Document Title'
    (expect outline[0][:children]).to be_empty
    (expect outline[1][:title]).to eql 'Part'
    (expect outline[1][:closed]).to be false
    (expect outline[1][:children]).to have_size 1
    (expect outline[1][:children][0][:title]).to eql 'Chapter'
    (expect outline[1][:children][0][:closed]).to be true
  end

  it 'should include doctitle in outline for book if notitle attribute is set' do
    pdf = to_pdf <<~'EOS'
    = Book Title
    :doctype: book
    :notitle:

    == Foo

    == Bar
    EOS

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0].text).to eql 'Foo'
    outline = extract_outline pdf
    (expect outline).to have_size 3
    (expect outline[0][:title]).to eql 'Book Title'
    (expect outline[1][:title]).to eql 'Foo'
    (expect outline[0][:dest][:pagenum]).to eql outline[1][:dest][:pagenum]
  end

  it 'should include doctitle in outline for article if title-page attribute is set' do
    pdf = to_pdf <<~'EOS'
    = Article Title
    :title-page:

    == Foo

    == Bar
    EOS

    (expect pdf.pages).to have_size 2
    (expect pdf.pages[0].text).to eql 'Article Title'
    (expect pdf.pages[1].text).to include 'Foo'
    outline = extract_outline pdf
    (expect outline).to have_size 3
    (expect outline[0][:title]).to eql 'Article Title'
    (expect outline[0][:dest][:pagenum]).to eql 1
    (expect outline[0][:dest][:label]).to eql 'i'
    (expect outline[1][:title]).to eql 'Foo'
    (expect outline[1][:dest][:pagenum]).to eql 2
    (expect outline[1][:dest][:label]).to eql '1'
  end

  it 'should include doctitle in outline for article' do
    pdf = to_pdf <<~'EOS'
    = Article Title

    == Foo

    == Bar
    EOS

    (expect pdf.pages).to have_size 1
    (expect pdf.pages[0].text).to include 'Article Title'
    (expect pdf.pages[0].text).to include 'Foo'
    outline = extract_outline pdf
    (expect outline).to have_size 3
    (expect outline[0][:title]).to eql 'Article Title'
    (expect outline[0][:dest][:pagenum]).to eql 1
    (expect outline[0][:dest][:label]).to eql '1'
    (expect outline[1][:title]).to eql 'Foo'
    (expect outline[1][:dest][:pagenum]).to eql 1
    (expect outline[1][:dest][:label]).to eql '1'
  end

  it 'should include doctitle in outline for article if notitle attribute is set' do
    pdf = to_pdf <<~'EOS'
    = Article Title
    :notitle:

    == Foo

    == Bar
    EOS

    (expect pdf.pages).to have_size 1
    (expect pdf.pages[0].text).not_to include 'Article Title'
    (expect pdf.pages[0].text).to include 'Foo'
    outline = extract_outline pdf
    (expect outline).to have_size 3
    (expect outline[0][:title]).to eql 'Article Title'
    (expect outline[0][:dest][:pagenum]).to eql 1
    (expect outline[0][:dest][:label]).to eql '1'
    (expect outline[1][:title]).to eql 'Foo'
    (expect outline[1][:dest][:pagenum]).to eql 1
    (expect outline[1][:dest][:label]).to eql '1'
  end

  it 'should sanitize titles' do
    pdf = to_pdf <<~'EOS'
    = _Document_ *Title*
    :doctype: book

    == _First_ *Chapter*
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 2
    (expect outline[0][:title]).to eql 'Document Title'
    (expect outline[1][:title]).to eql 'First Chapter'
  end

  it 'should decode character references in entries' do
    pdf = to_pdf <<~'EOS'
    = ACME(TM) Catalog <&#8470;&nbsp;1>
    :doctype: book

    == Paper Clips &#x2116;&nbsp;4
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 2
    (expect outline[0][:title]).to eql %(ACME\u2122 Catalog <\u2116 1>)
    (expect outline[1][:title]).to eql %(Paper Clips \u2116 4)
  end

  it 'should label front matter pages using roman numerals' do
    pdf = to_pdf <<~'EOS'
    = Book Title
    :doctype: book
    :toc:

    == Chapter 1

    == Chapter 2
    EOS

    (expect get_page_labels pdf).to eql %w(i ii 1 2)
  end

  it 'should label title page using roman numeral ii if cover page is present' do
    pdf = to_pdf <<~'EOS'
    = Book Title
    :doctype: book
    :toc:
    :front-cover-image: image:cover.jpg[]

    == Chapter 1

    == Chapter 2
    EOS

    (expect get_page_labels pdf).to eql %w(i ii iii 1 2)
    outline = extract_outline pdf
    (expect outline[0][:title]).to eql 'Book Title'
    (expect outline[0][:dest][:pagenum]).to eql 2
  end

  it 'should link doctitle dest to second page of article with front cover' do
    pdf = to_pdf <<~EOS
    = Document Title
    :front-cover-image: #{fixture_file 'cover.jpg', relative: true}

    content page
    EOS

    (expect pdf.pages).to have_size 2
    outline = extract_outline pdf
    (expect outline).to have_size 1
    doctitle_entry = outline[0]
    (expect doctitle_entry[:title]).to eql 'Document Title'
    (expect doctitle_entry[:dest][:pagenum]).to eql 2
    (expect doctitle_entry[:dest][:label]).to eql '1'
  end

  it 'should link doctitle dest to second page of book with front cover' do
    pdf = to_pdf <<~EOS
    = Document Title
    :doctype: book
    :front-cover-image: #{fixture_file 'cover.jpg', relative: true}

    content page
    EOS

    (expect pdf.pages).to have_size 3
    outline = extract_outline pdf
    (expect outline).to have_size 1
    doctitle_entry = outline[0]
    (expect doctitle_entry[:title]).to eql 'Document Title'
    (expect doctitle_entry[:dest][:pagenum]).to eql 2
    (expect doctitle_entry[:dest][:label]).to eql 'ii'
  end

  it 'should label first page starting with 1 if no front matter is present' do
    pdf = to_pdf <<~'EOS', doctype: :book
    no front matter

    <<<

    more content
    EOS

    (expect get_page_labels pdf).to eql %w(1 2)
  end

  it 'should set doctitle in outline to value of untitled-label attribute if document has no doctitle or sections' do
    pdf = to_pdf 'body only'

    outline = extract_outline pdf
    (expect outline).to have_size 1
    (expect outline[0][:title]).to eql 'Untitled'
    (expect outline[0][:children]).to be_empty
  end

  it 'should set doctitle in outline to value of untitled-label attribute if document has no doctitle and has sections' do
    pdf = to_pdf <<~'EOS'
    == First Section

    == Last Section
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 3
    (expect outline[0][:title]).to eql 'Untitled'
    (expect outline[0][:children]).to be_empty
  end

  it 'should set not set doctitle in outline if document has no doctitle, has sections, and untitled-label attribute is unset' do
    pdf = to_pdf <<~'EOS'
    :untitled-label!:

    == First Section

    == Last Section
    EOS

    outline = extract_outline pdf
    (expect outline).to have_size 2
    (expect outline[0][:title]).to eql 'First Section'
    (expect outline[1][:title]).to eql 'Last Section'
  end

  it 'should not crash if doctitle is not set and untitled-label attribute is unset and document has no sections' do
    pdf = to_pdf <<~'EOS'
    :untitled-label!:

    body only
    EOS

    (expect extract_outline pdf).to be_empty
  end
end
