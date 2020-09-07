# frozen_string_literal: true

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

  it 'should create fragment for emphasized text' do
    input = '<em>fast</em>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql 'fast'
    (expect fragments[0][:styles]).to eql [:italic].to_set
  end

  it 'should create fragment for sup text' do
    input = 'x<sup>2</sup>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 2
    (expect fragments[0][:text]).to eql 'x'
    (expect fragments[1][:text]).to eql '2'
    (expect fragments[1][:styles].to_a).to eql [:superscript]
  end

  it 'should create fragment for sub text' do
    input = 'H<sub>2</sub>O'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 3
    (expect fragments[0][:text]).to eql 'H'
    (expect fragments[1][:text]).to eql '2'
    (expect fragments[1][:styles].to_a).to eql [:subscript]
    (expect fragments[2][:text]).to eql 'O'
  end

  it 'should create fragment for del text' do
    input = '<del>old</del>new'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 2
    (expect fragments[0][:text]).to eql 'old'
    (expect fragments[0][:styles].to_a).to eql [:strikethrough]
    (expect fragments[1][:text]).to eql 'new'
  end

  it 'should not create fragment for empty element' do
    input = 'foo <strong></strong> bar'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 2
    (expect fragments[0][:text]).to eql 'foo'
    (expect fragments[1][:text]).to eql ' bar'
  end

  it 'should create fragment with custom font name' do
    input = '<font name="Helvetica">Helvetica</font>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql 'Helvetica'
    (expect fragments[0][:font]).to eql 'Helvetica'
  end

  it 'should create fragment with custom font size' do
    input = '<font size="20">big</font>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql 'big'
    (expect fragments[0][:size]).to eql 20.0
  end

  it 'should create fragment with custom hex color' do
    input = '<color rgb="#ff0000">red</color>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql 'red'
    (expect fragments[0][:color]).to eql 'ff0000'
  end

  it 'should create fragment with custom cmyk color' do
    input = '<color rgb="[50.5, 100, 0, 0]">color</color>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql 'color'
    (expect fragments[0][:color]).to eql [50.5, 100, 0, 0]
  end

  it 'should return nil if text contains invalid markup' do
    input = 'before <foo>bar</foo> after'
    (expect parser.parse input).to be_nil
  end

  it 'should convert named entity' do
    input = '&quot;&lt;&amp;&gt;&quot;'
    parsed = parser.parse input
    fragments = subject.apply parsed.content
    (expect fragments).to have_size 5
    (expect fragments[0][:text]).to eql ?"
    (expect fragments[1][:text]).to eql ?<
    (expect fragments[2][:text]).to eql ?&
    (expect fragments[3][:text]).to eql ?>
    (expect fragments[4][:text]).to eql ?"
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

  it 'should apply inherited styles' do
    input = '<a href="https://asciidoctor.org">Asciidoctor</a>'
    parsed = parser.parse input
    fragments = subject.apply parsed.content, [], styles: [:bold].to_set
    (expect fragments).to have_size 1
    (expect fragments[0][:text]).to eql 'Asciidoctor'
    (expect fragments[0][:styles].to_a).to eql [:bold]
  end

  it 'should apply styles to inherited styles' do
    input = 'Go <strong>get</strong> them!'
    parsed = parser.parse input
    fragments = subject.apply parsed.content, [], styles: [:italic].to_set
    (expect fragments).to have_size 3
    get_fragment = fragments.find {|it| it[:text] == 'get' }
    (expect get_fragment[:styles].to_a.sort).to eql [:bold, :italic]
  end
end
