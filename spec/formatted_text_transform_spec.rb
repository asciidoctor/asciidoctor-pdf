require_relative 'spec_helper'

describe Asciidoctor::PDF::FormattedText::Transform do
  let(:parser) { Asciidoctor::PDF::FormattedText::MarkupParser.new }

  it 'should create fragment for strong text' do
    input = '<strong>write tests!</strong>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql 'write tests!'
    (expect fragments[0][:styles]).to eql [:bold].to_set
  end

  it 'should not merge adjacent text nodes by default' do
    input = 'foo<br>bar'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 3
    (expect fragments[0][:text]).to eql 'foo'
    (expect fragments[1][:text]).to eql ?\n
    (expect fragments[2][:text]).to eql 'bar'
  end

  it 'should merge adjacent text nodes if specified' do
    input = 'foo<br>bar'
    parsed = parser.parse input
    fragments = (subject.class.new merge_adjacent_text_nodes: true).apply parsed.content
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql %(foo\nbar)
  end
end
