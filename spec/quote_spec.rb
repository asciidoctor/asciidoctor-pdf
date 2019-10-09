require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Quote' do
  it 'should not draw left border if border_width is 0' do
    pdf = to_pdf <<~EOS, pdf_theme: { blockquote_border_width: 0 }, analyze: :line
    ____
    let it be
    ____
    EOS

    (expect pdf.lines).to be_empty
  end
end
