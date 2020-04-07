# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Dest' do
  it 'should define a dest named __anchor-top at top of the first body page' do
    pdf = to_pdf <<~'EOS', doctype: :book
    = Document Title

    first page of content
    EOS

    names = get_names pdf
    (expect names).to have_key '__anchor-top'
    top_dest = pdf.objects[names['__anchor-top']]
    top_page_num = get_page_number pdf, top_dest[0]
    top_y = top_dest[3]
    (expect top_page_num).to be 2
    _, page_height = get_page_size pdf, top_page_num
    (expect top_y).to eql page_height
  end

  it 'should register dest for every block that has an ID' do
    ['', 'abstract', 'example', 'open', 'sidebar', 'quote', 'verse', 'listing', 'literal', 'NOTE'].each do |style|
      pdf = to_pdf <<~EOS
      [#{style}#disclaimer]
      All views expressed are my own.
      EOS

      names = get_names pdf
      (expect names).to have_key 'disclaimer'
    end
  end

  it 'should register dest for unordered list that has an ID' do
    pdf = to_pdf <<~'EOS'
    [#takeaways]
    * one
    * two
    EOS

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for ordered list that has an ID' do
    pdf = to_pdf <<~'EOS'
    [#takeaways]
    . one
    . two
    EOS

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should register dest for description list that has an ID' do
    pdf = to_pdf <<~'EOS'
    [#takeaways]
    reuse:: try to avoid binning it in the first place
    recycle:: if you do bin it, make sure the material gets reused
    EOS

    (expect get_names pdf).to have_key 'takeaways'
  end

  it 'should define a dest at the location of an inline anchor' do
    ['[[details]]details', '[#details]#details#'].each do |details|
      pdf = to_pdf <<~EOS
      Here's the intro.

      <<<

      Here are all the #{details}.
      EOS

      names = get_names pdf
      (expect names).to have_key 'details'
      details_dest = pdf.objects[names['details']]
      details_dest_pagenum = get_page_number pdf, details_dest[0]
      (expect details_dest_pagenum).to be 2
    end
  end

  it 'should keep anchor with text if text is advanced to next page' do
    pdf = to_pdf <<~EOS
    jump to <<anchor>>

    #{(['paragraph'] * 25).join %(\n\n)}

    #{(['paragraph'] * 16).join ' '} [#anchor]#supercalifragilisticexpialidocious#
    EOS

    names = get_names pdf
    (expect names).to have_key 'anchor'
    anchor_dest = pdf.objects[names['anchor']]
    anchor_dest_pagenum = get_page_number pdf, anchor_dest[0]
    (expect anchor_dest_pagenum).to be 2
    (expect (pdf.page 2).text).to eql 'supercalifragilisticexpialidocious'
  end
end
