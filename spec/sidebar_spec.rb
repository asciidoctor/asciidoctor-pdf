require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Sidebar' do
  it 'should keep sidebar together if it can fit on one page' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['filler'] * 15).join %(\n\n)}

    .Sidebar
    ****
    #{(['content'] * 15).join %(\n\n)}
    ****
    EOS

    sidebar_text = (pdf.find_text 'Sidebar')[0]
    (expect sidebar_text[:page_number]).to eql 2
  end
end
