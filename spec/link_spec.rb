require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Link' do
  it 'should convert a raw URL to a link' do
    input = 'The home page for Asciidoctor is located at https://asciidoctor.org.'
    pdf = to_pdf input
    annotations = get_annotations pdf, 1
    (expect annotations.size).to eql 1
    link_annotation = annotations[0]
    (expect link_annotation[:Subtype]).to eql :Link
    (expect link_annotation[:A][:URI]).to eql 'https://asciidoctor.org'

    pdf = to_pdf input, analyze: true
    link_text = (pdf.find_text string: 'https://asciidoctor.org')[0]
    (expect link_text).not_to be_nil
    (expect link_text[:font_color]).to eql '428BCA'
    (expect link_text[:x]).to eql link_annotation[:Rect][0]
  end

  it 'should reveal URL of link when media=print or media=prepress' do
    %w(print prepress).each do |media|
      pdf = to_pdf <<~'EOS', attribute_overrides: { 'media' => 'print' }, analyze: true
      https://asciidoctor.org[Asciidoctor] is a text processor.
      EOS

      (expect pdf.lines).to eql ['Asciidoctor [https://asciidoctor.org] is a text processor.']
    end
  end
end
