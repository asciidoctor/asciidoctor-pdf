require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Lists' do
  context 'Ordered List' do
    it 'should number list items using arabic numbering by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      . a
      . b
      . c
      EOS

      (expect pdf.strings).to eql %w(1. a 2. b 3. c)
      (expect pdf.lines).to eql ['1.a', '2.b', '3.c']
    end
  end

  context 'Description List' do
    it 'should convert qanda to ordered list' do
      pdf = to_pdf <<~'EOS', analyze: true
      [qanda]
      What is Asciidoctor?::
      An implementation of the AsciiDoc processor in Ruby.

      What is the answer to the Ultimate Question?::
      42
      EOS
      (expect pdf.strings).to eql [
        '1.',
        'What is Asciidoctor?',
        'An implementation of the AsciiDoc processor in Ruby.',
        '2.',
        'What is the answer to the Ultimate Question?',
        '42'
      ]
    end
  end
end
