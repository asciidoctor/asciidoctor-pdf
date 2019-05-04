require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Index' do
  it 'should not add index entries to the document if an index section is not present' do
    pdf = to_pdf <<~'EOS', analyze: true
    You can add a ((visible index entry)) to your document by surrounding it in double round brackets.
    EOS

    (expect pdf.find_text 'visible index entry').to be_empty
  end

  it 'should add the index entries the section with the index style' do
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
    (expect index_text.size).to eql 1
    category_c_text = pdf.find_text string: 'C', page_number: 4
    (expect category_c_text.size).to eql 1
    (expect category_c_text[0][:font_name].downcase).to include 'bold'
    category_d_text = pdf.find_text string: 'D', page_number: 4
    (expect category_d_text.size).to eql 1
    (expect category_d_text[0][:font_name].downcase).to include 'bold'
    category_k_text = pdf.find_text string: 'K', page_number: 4
    (expect category_k_text.size).to eql 1
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
    (expect category_c_text.size).to eql 1
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
    pdf = to_pdf <<~'EOS', doctype: :book, attributes: { 'media' => 'print', 'nofooter' => '' }, analyze: true
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
end
