require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Lists' do
  context 'Unordered List' do
    it 'should use marker specified by style' do
      pdf = to_pdf <<~'EOS', analyze: true
      [square]
      * one
      * two
      * three
      EOS

      (expect pdf.lines).to eql ['▪one', '▪two', '▪three']
    end
  end

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

  context 'Bibliography' do
    it 'should reference bibliography entry using ID in square brackets by default' do

      pdf = to_pdf <<~EOS, analyze: true
      The recommended reading includes <<bar>>.

      [bibliography]
      == Bibliography

      #{asciidoctor_1_5_7_or_better? ? '' : '[bibliography]'}
      * [[[bar]]] Bar, Foo. All The Things. 2010.
      EOS

      lines = pdf.lines
      (expect lines).to include 'The recommended reading includes [bar].'
      (expect lines).to include '▪[bar] Bar, Foo. All The Things. 2010.'
    end

    it 'should reference bibliography entry using custom reftext square brackets' do
      pdf = to_pdf <<~'EOS', analyze: true
      The recommended reading includes <<bar>>.

      [bibliography]
      == Bibliography

      * [[[bar,1]]] Bar, Foo. All The Things. 2010.
      EOS

      lines = pdf.lines
      (expect lines).to include 'The recommended reading includes [1].'
      (expect lines).to include '▪[1] Bar, Foo. All The Things. 2010.'
    end if asciidoctor_1_5_7_or_better?
  end
end
