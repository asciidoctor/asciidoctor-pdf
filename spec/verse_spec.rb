require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Verse' do
  it 'should expand tabs and preserve indentation' do
    pdf = to_pdf <<~EOS, analyze: true
    [verse]
    ____
    here
    \twe
    \t\tgo
    again
    ____
    EOS

    lines = pdf.lines
    (expect lines).to have_size 4
    (expect lines[1]).to eql %(\u00a0   we)
    (expect lines[2]).to eql %(\u00a0       go)
  end

  it 'should not draw left border if border_width is 0' do
    pdf = to_pdf <<~EOS, pdf_theme: { blockquote_border_width: 0 }, analyze: :line
    ____
    here
    we
    go
    ____
    EOS

    (expect pdf.lines).to be_empty
  end
end
