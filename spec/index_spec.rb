# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Index' do
  it 'should not add index entries to the document if an index section is not present' do
    pdf = to_pdf <<~'EOS', analyze: true
    You can add a ((visible index entry)) to your document by surrounding it in double round brackets.
    EOS

    (expect pdf.find_text 'visible index entry').to be_empty
  end

  it 'should add the index entries to the section with the index style' do
    pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
    = Document Title

    == Chapter About Cats

    We know that ((cats)) control the internet.
    But they sort run nature too.
    (((cats,big cats,lion)))
    After all, the ((king of the jungle)) is the lion, which is a big cat.

    == Chapter About Dogs

    Cats may rule, well, everything.
    But ((dogs)) are a human's best friend.

    [index]
    == Index
    EOS

    index_text = pdf.find_text string: 'Index', page_number: 4, font_size: 22
    (expect index_text).to have_size 1
    category_c_text = pdf.find_text string: 'C', page_number: 4
    (expect category_c_text).to have_size 1
    (expect category_c_text[0][:font_name].downcase).to include 'bold'
    category_d_text = pdf.find_text string: 'D', page_number: 4
    (expect category_d_text).to have_size 1
    (expect category_d_text[0][:font_name].downcase).to include 'bold'
    category_k_text = pdf.find_text string: 'K', page_number: 4
    (expect category_k_text).to have_size 1
    (expect category_k_text[0][:font_name].downcase).to include 'bold'
    (expect (pdf.lines pdf.find_text page_number: 4).join ?\n).to eql <<~'EOS'.chomp
    Index
    C
    cats, 1
    big cats
    lion, 1
    D
    dogs, 2
    K
    king of the jungle, 1
    EOS
  end

  it 'should create link from entry in index to location of term' do
    input = <<~'EOS'
    = Document Title
    :doctype: book

    == Chapter About Dogs

    Cats may rule, well, everything.
    But ((dogs)) are a human's best friend.

    [index]
    == Index
    EOS

    pdf = to_pdf input, analyze: true
    dogs_text = (pdf.find_text 'dogs are a human’s best friend.')[0]

    pdf = to_pdf input
    annotations = get_annotations pdf, 3
    (expect annotations).to have_size 1
    dest = annotations[0][:Dest]
    names = get_names pdf
    (expect names).to have_key dest
    (expect pdf.objects[names[dest]][2]).to eql dogs_text[:x]
    term_pgnum = get_page_number pdf, pdf.objects[pdf.objects[names[dest]][0]]
    (expect term_pgnum).to eql 2
  end

  it 'should not assign number or chapter label to index section' do
    pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
    = Cats & Dogs
    :sectnums:

    == Cats

    We know that ((cats)) control the internet.

    == Dogs

    Cats may rule, well, everything.
    But ((dogs)) are a human's best friend.

    [index]
    == Index
    EOS

    index_text = pdf.find_text string: 'Chapter 3. Index', page_number: 4
    (expect index_text).to be_empty
    index_text = pdf.find_text string: 'Index', page_number: 4
    (expect index_text).to have_size 1
  end

  it 'should generate anchor names for indexterms which are reproducible between runs' do
    input = <<~'EOS'
    = Cats & Dogs
    :reproducible:

    == Cats

    We know that ((cats)) control the internet.

    == Dogs

    Cats may rule, well, everything.
    But ((dogs)) are a human's best friend.

    [index]
    == Index
    EOS

    to_file_a = to_pdf_file input, 'index-reproducible-a.pdf', doctype: :book
    to_file_b = to_pdf_file input, 'index-reproducible-b.pdf', doctype: :book
    (expect FileUtils.compare_file to_file_a, to_file_b).to be true
  end

  it 'should not automatically promote nested index terms' do
    pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
    = Document Title

    == Big Cats

    (((cats,big cats)))
    (((cats,big cats,lion)))
    The king of the jungle is the lion, which is a big cat.

    [index]
    == Index
    EOS

    category_c_text = pdf.find_text string: 'C', page_number: 3
    (expect category_c_text).to have_size 1
    (expect category_c_text[0][:font_name].downcase).to include 'bold'
    category_b_text = pdf.find_text string: 'B', page_number: 3
    (expect category_b_text).to be_empty
    category_l_text = pdf.find_text string: 'L', page_number: 3
    (expect category_l_text).to be_empty
    (expect (pdf.lines pdf.find_text page_number: 3).join ?\n).to eql <<~'EOS'.chomp
    Index
    C
    cats
    big cats, 1
    lion, 1
    EOS
  end

  it 'should group index entries that start with symbol under symbol category' do
    pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
    = Document Title

    == Symbols

    Use the ((@Transactional)) annotation to mark a bean as transactional.

    Use the ((&#169;)) symbol to indicate the copyright.

    [index]
    == Index
    EOS

    (expect (pdf.lines pdf.find_text page_number: 3).join ?\n).to eql <<~'EOS'.chomp
    Index
    @
    @Transactional, 1
    ©, 1
    EOS
  end

  it 'should not put letters outside of ASCII charset in symbol category' do
    pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
    = Document Title

    == Unicode Party

    ((étudier)) means to study.

    Use a ((λ)) to define a lambda function.

    [index]
    == Index
    EOS

    (expect (pdf.lines pdf.find_text page_number: 3).join ?\n).to eql <<~'EOS'.chomp
    Index
    É
    étudier, 1
    Λ
    λ, 1
    EOS
  end

  it 'should sort terms in index, ignoring case' do
    pdf = to_pdf <<~'EOS', analyze: true
    = Document Title
    :doctype: book

    == Chapter A

    ((AsciiDoc)) is a lightweight markup language.
    It is used for content ((authoring)).

    == Chapter B

    ((Asciidoctor)) is an AsciiDoc processor.

    == Chapter C

    If an element has an ((anchor)), you can link to it.

    [index]
    == Index
    EOS

    index_pagenum = (pdf.find_text 'Index')[0][:page_number]
    index_page_lines = pdf.lines pdf.find_text page_number: index_pagenum
    terms = index_page_lines.select {|it| it.include? ',' }.map {|it| (it.split ',', 2)[0] }
    (expect terms).to eql %w(anchor AsciiDoc Asciidoctor authoring)
  end

  it 'should not combine range if same index entry occurs on sequential pages when media is screen' do
    pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
    = Document Title

    == First Chapter

    ((coming soon))

    == Second Chapter

    ((coming soon))

    == Third Chapter

    ((coming soon))

    [index]
    == Index
    EOS

    (expect (pdf.lines pdf.find_text page_number: 5).join ?\n).to include 'coming soon, 1, 2, 3'
  end

  it 'should combine range if same index entry occurs on sequential pages when media is not screen' do
    pdf = to_pdf <<~'EOS', doctype: :book, attribute_overrides: { 'media' => 'print' }, analyze: true
    = Document Title

    == First Chapter

    ((coming soon))

    == Second Chapter

    ((coming soon))

    == Third Chapter

    ((coming soon))

    [index]
    == Index
    EOS

    (expect (pdf.lines pdf.find_text page_number: 5).join ?\n).to include 'coming soon, 1-3'
  end

  it 'should apply hanging indent to wrapped lines equal to twice level indent' do
    pdf = to_pdf <<~'EOS', doctype: :book, analyze: true
    = Document Title

    text(((searching,for fun and profit)))(((searching,when you have absolutely no clue where to begin)))

    [index]
    == Index
    EOS

    searching_text = (pdf.find_text page_number: 3, string: 'searching')[0]
    fun_profit_text = (pdf.find_text page_number: 3, string: /^for fun/)[0]
    begin_text = (pdf.find_text page_number: 3, string: /^begin/)[0]
    left_margin = searching_text[:x]
    level_indent = fun_profit_text[:x] - left_margin
    hanging_indent = begin_text[:x] - fun_profit_text[:x]
    (expect hanging_indent.round).to eql (level_indent * 2).round
  end
end
