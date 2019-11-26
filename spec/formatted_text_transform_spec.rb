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
end
