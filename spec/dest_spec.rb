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
    (expect top_page_num).to eql 2
    _, page_height = get_page_size pdf, top_page_num
    (expect top_y).to eql page_height
  end

  it 'should link self-referencing interdocument xref to built-in __anchor-top ref' do
    pdf = to_pdf Pathname.new fixture_file 'reference-to-self.adoc'
    (expect Pathname.new output_file 'reference-to-self.pdf').to exist
    annotations = get_annotations pdf
    (expect annotations).to have_size 1
    (expect annotations[0][:Dest]).to eql '__anchor-top'
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
      (expect details_dest_pagenum).to eql 2
    end
  end
end
