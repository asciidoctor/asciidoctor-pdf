require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Dests' do
  it 'should define a dest named __anchor-top at top of the first body page' do
    pdf = to_pdf <<~'EOS', doctype: 'book'
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
end
