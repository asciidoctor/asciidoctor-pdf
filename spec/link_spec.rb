require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Link' do
  it 'should convert a raw URL to a link' do
    input = 'The home page for Asciidoctor is located at https://asciidoctor.org.'
    pdf = to_pdf input
    annotations = get_annotations pdf, 1
    (expect annotations).to have_size 1
    link_annotation = annotations[0]
    (expect link_annotation[:Subtype]).to eql :Link
    (expect link_annotation[:A][:URI]).to eql 'https://asciidoctor.org'

    pdf = to_pdf input, analyze: true
    link_text = (pdf.find_text 'https://asciidoctor.org')[0]
    (expect link_text).not_to be_nil
    (expect link_text[:font_color]).to eql '428BCA'
    (expect link_text[:x]).to eql link_annotation[:Rect][0]
  end

  it 'should decode character references in the href' do
    input = 'https://github.com/asciidoctor/asciidoctor-pdf/milestones?direction=asc&sort=<>&state=open'
    pdf = to_pdf input
    text = (pdf.page 1).text
    (expect text).to eql input
    link = (get_annotations pdf, 1)[0]
    (expect link[:A][:URI]).to eql input
  end

  it 'should split bare URL on breakable characters' do
    [
      'the URL on this line will get split on the ? char https://github.com/asciidoctor/asciidoctor/issues?|q=milestone%3Av2.0.x',
      'the URL on this line will get split on the / char instead https://github.com/asciidoctor/asciidoctor/|issues?q=milestone%3Av2.0.x',
      'the URL on this line will get split on the # char https://github.com/asciidoctor/asciidoctor/issues#|milestone%3Av2.0.x',
    ].each do |text|
      before, after = text.split '|', 2
      pdf = to_pdf %(#{before}#{after}), analyze: true
      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0]).to end_with before
      (expect lines[1]).to start_with after
    end
  end

  it 'should not split bare URL when using an AFM font' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_family: 'Helvetica' }, analyze: true
    this line contains a URL that falls at the end of the line and yet cannot be split https://goo.gl/search/asciidoctor
    EOS
    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[1]).to eql 'https://goo.gl/search/asciidoctor'
  end

  it 'should not split bare URL after scheme' do
    pdf = to_pdf <<~'EOS', analyze: true
    this line contains a URL that falls at the end of the line that is not split after the scheme https://goo.gl/search/asciidoctor
    EOS
    lines = pdf.lines
    (expect lines).to have_size 2
    (expect lines[1]).to eql 'https://goo.gl/search/asciidoctor'
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
