require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - List' do
  context 'Unordered' do
    it 'should use marker specified by style' do
      pdf = to_pdf <<~'EOS', analyze: true
      [square]
      * one
      * two
      * three
      EOS

      (expect pdf.lines).to eql ['▪one', '▪two', '▪three']
    end

    it 'should make bullets invisible if list has no-bullet style' do
      pdf = to_pdf <<~'EOS', analyze: true
      reference

      [no-bullet]
      * wood
      * hammer
      * nail
      EOS

      (expect pdf.lines[1..-1]).to eql %w(wood hammer nail)
      left_margin = pdf.text[0][:x]
      indents = pdf.text[1..-1].map {|it| it[:x] }
      (expect indents.size).to eql 3
      (expect indents.uniq.size).to eql 1
      (expect indents[0]).to be > left_margin
    end

    it 'should apply proper indentation for each list style that hides the marker' do
      pdf = to_pdf <<~'EOS', analyze: true
      reference

      [unstyled]
      * unstyled

      [no-bullet]
      * no-bullet

      [none]
      * none
      EOS

      (expect pdf.text.size).to eql 4
      left_margin = (pdf.find_text string: 'reference')[0][:x]
      unstyled_item = (pdf.find_text string: 'unstyled')[0]
      (expect unstyled_item[:x]).to eql left_margin
      no_bullet_item = (pdf.find_text string: 'no-bullet')[0]
      (expect no_bullet_item[:x]).to eql 56.3805
      none_item = (pdf.find_text string: 'none')[0]
      (expect none_item[:x]).to eql 66.24
    end
  end

  context 'Ordered' do
    it 'should number list items using arabic numbering by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      . a
      . b
      . c
      EOS

      (expect pdf.strings).to eql %w(1. a 2. b 3. c)
      (expect pdf.lines).to eql ['1.a', '2.b', '3.c']
    end

    it 'should use marker specified by style' do
      pdf = to_pdf <<~'EOS', analyze: true
      [lowerroman]
      . one
      . two
      . three
      EOS

      (expect pdf.lines).to eql ['i.one', 'ii.two', 'iii.three']
    end

    it 'should align list numbers to right and extend towards left margin' do
      pdf = to_pdf <<~'EOS', analyze: true
      . one
      . two
      . three
      . four
      . five
      . six
      . seven
      . eight
      . nine
      . ten
      EOS

      nine_text = (pdf.find_text string: 'nine')[0]
      ten_text = (pdf.find_text string: 'ten')[0]

      (expect nine_text[:x]).to eql ten_text[:x]

      no9_text = (pdf.find_text string: '9.')[0]
      no10_text = (pdf.find_text string: '10.')[0]
      (expect no9_text[:x]).to be > no10_text[:x]
    end

    it 'should start numbering at value of start attribute if specified' do
      pdf = to_pdf <<~'EOS', analyze: true
      [start=9]
      . nine
      . ten
      EOS

      no1_text = (pdf.find_text string: '1.')[0]
      (expect no1_text).to be_nil
      no9_text = (pdf.find_text string: '9.')[0]
      (expect no9_text).not_to be_nil
      (expect no9_text[:order]).to eql 1
      (expect pdf.lines).to eql %w(9.nine 10.ten)
    end

    it 'should start numbering at value of specified start attribute using specified numeration style' do
      pdf = to_pdf <<~'EOS', analyze: true
      [upperroman,start=9]
      . nine
      . ten
      EOS

      no1_text = (pdf.find_text string: 'I.')[0]
      (expect no1_text).to be_nil
      no9_text = (pdf.find_text string: 'IX.')[0]
      (expect no9_text).not_to be_nil
      (expect no9_text[:order]).to eql 1
      (expect pdf.lines).to eql %w(IX.nine X.ten)
    end

    it 'should make numbers invisible if list has unnumbered style' do
      pdf = to_pdf <<~'EOS', analyze: true
      reference

      [unnumbered]
      . one
      . two
      . three
      EOS

      (expect pdf.lines[1..-1]).to eql %w(one two three)
      left_margin = pdf.text[0][:x]
      indents = pdf.text[1..-1].map {|it| it[:x] }
      (expect indents.size).to eql 3
      (expect indents.uniq.size).to eql 1
      (expect indents[0]).to be > left_margin
    end

    it 'should apply proper indentation for each list style that hides the marker' do
      pdf = to_pdf <<~'EOS', analyze: true
      reference

      [unstyled]
      . unstyled

      [no-bullet]
      . no-bullet

      [unnumbered]
      . unnumbered

      [none]
      . none
      EOS

      (expect pdf.text.size).to eql 5
      left_margin = (pdf.find_text string: 'reference')[0][:x]
      unstyled_item = (pdf.find_text string: 'unstyled')[0]
      (expect unstyled_item[:x]).to eql left_margin
      no_bullet_item = (pdf.find_text string: 'no-bullet')[0]
      (expect no_bullet_item[:x]).to eql 51.6765
      unnumbered_item = (pdf.find_text string: 'unnumbered')[0]
      (expect unnumbered_item[:x]).to eql 51.6765
      none_item = (pdf.find_text string: 'none')[0]
      (expect none_item[:x]).to eql 66.24
    end
  end

  context 'Description' do
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
