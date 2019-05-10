require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Lists' do
  context 'dlist' do
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
