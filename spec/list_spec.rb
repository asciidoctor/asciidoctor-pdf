require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - List' do
  context 'Unordered' do
    it 'should use different marker for first three list levels' do
      pdf = to_pdf <<~'EOS', analyze: true
      * level one
       ** level two
        *** level three
         **** level four
      * back to level one
      EOS

      expected_lines = [
        '•level one',
        '◦level two',
        '▪level three',
        '▪level four',
        '•back to level one'
      ]

      (expect pdf.lines).to eql expected_lines
    end

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
      (expect indents).to have_size 3
      (expect indents.uniq).to have_size 1
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

      (expect pdf.text).to have_size 4
      left_margin = (pdf.find_text 'reference')[0][:x]
      unstyled_item = (pdf.find_text 'unstyled')[0]
      (expect unstyled_item[:x]).to eql left_margin
      no_bullet_item = (pdf.find_text 'no-bullet')[0]
      (expect no_bullet_item[:x]).to eql 56.3805
      none_item = (pdf.find_text 'none')[0]
      (expect none_item[:x]).to eql 66.24
    end

    it 'should apply correct margin if primary text of list item is blank' do
      pdf = to_pdf <<~'EOS', analyze: true
      * foo
      * {blank}
      * bar
      EOS

      mark_texts = pdf.find_text '•'
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
    end

    it 'should align first block of list item with marker if primary text is blank' do
      pdf = to_pdf <<~'EOS', analyze: true
      * {blank}
      +
      text
      EOS

      text = pdf.text
      (expect text).to have_size 2
      (expect text[0][:y]).to eql text[1][:y]
    end
  end

  context 'Ordered' do
    it 'should number list items using arabic, loweralpha, lowerroman, upperalpha, upperroman numbering by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      . 1
       .. a
        ... i
         .... A
          ..... I
      . 2
      . 3
      EOS

      (expect pdf.strings).to eql %w(1. 1 a. a i. i A. A I. I 2. 2 3. 3)
      (expect pdf.lines).to eql %w(1.1 a.a i.i A.A I.I 2.2 3.3)
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

      nine_text = (pdf.find_text 'nine')[0]
      ten_text = (pdf.find_text 'ten')[0]

      (expect nine_text[:x]).to eql ten_text[:x]

      no9_text = (pdf.find_text '9.')[0]
      no10_text = (pdf.find_text '10.')[0]
      (expect no9_text[:x]).to be > no10_text[:x]
    end

    it 'should start numbering at value of start attribute if specified' do
      pdf = to_pdf <<~'EOS', analyze: true
      [start=9]
      . nine
      . ten
      EOS

      no1_text = (pdf.find_text '1.')[0]
      (expect no1_text).to be_nil
      no9_text = (pdf.find_text '9.')[0]
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

      no1_text = (pdf.find_text 'I.')[0]
      (expect no1_text).to be_nil
      no9_text = (pdf.find_text 'IX.')[0]
      (expect no9_text).not_to be_nil
      (expect no9_text[:order]).to eql 1
      (expect pdf.lines).to eql %w(IX.nine X.ten)
    end

    it 'should ignore start attribute if marker is disabled' do
      pdf = to_pdf <<~'EOS', analyze: true
      [unstyled,start=10]
      . a
      . b
      . c
      EOS

      (expect pdf.lines).to eql %w(a b c)
    end

    it 'should allow start value to be less than 1 for list with arabic numbering' do
      pdf = to_pdf <<~'EOS', analyze: true
      [start=-1]
      . negative one
      . zero
      . positive one
      EOS

      (expect pdf.lines).to eql ['-1.negative one', '0.zero', '1.positive one']
    end

    it 'should allow start value to be less than 1 for list with roman numbering' do
      pdf = to_pdf <<~'EOS', analyze: true
      [lowerroman,start=-1]
      . negative one
      . zero
      . positive one
      EOS

      (expect pdf.lines).to eql ['-1.negative one', '0.zero', 'i.positive one']
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
      (expect indents).to have_size 3
      (expect indents.uniq).to have_size 1
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

      (expect pdf.text).to have_size 5
      left_margin = (pdf.find_text 'reference')[0][:x]
      unstyled_item = (pdf.find_text 'unstyled')[0]
      (expect unstyled_item[:x]).to eql left_margin
      no_bullet_item = (pdf.find_text 'no-bullet')[0]
      (expect no_bullet_item[:x]).to eql 51.6765
      unnumbered_item = (pdf.find_text 'unnumbered')[0]
      (expect unnumbered_item[:x]).to eql 51.6765
      none_item = (pdf.find_text 'none')[0]
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

  context 'Callout' do
    it 'should use callout numbers as list markers and in referenced block' do
      pdf = to_pdf <<~'EOS', analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      EOS

      one_text = pdf.find_text ?\u2460
      two_text = pdf.find_text ?\u2461
      (expect one_text).to have_size 2
      (expect two_text).to have_size 2
      (one_text + two_text).each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql 'B12146'
      end
      (expect one_text[1][:y]).to be < two_text[0][:y]
    end

    it 'should allow conum font color to be customized by theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { conum_font_color: '0000ff' }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      EOS

      one_text = pdf.find_text ?\u2460
      (expect one_text).to have_size 2
      one_text.each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql '0000FF'
      end
    end

    it 'should support filled conum glyphs if specified in theme' do
      pdf = to_pdf <<~'EOS', pdf_theme: { conum_glyphs: 'filled' }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      EOS

      one_text = pdf.find_text ?\u2776
      two_text = pdf.find_text ?\u2777
      (expect one_text).to have_size 2
      (expect two_text).to have_size 2
      (one_text + two_text).each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql 'B12146'
      end
    end

    it 'should allow conum glyphs to be specified explicitly' do
      pdf = to_pdf <<~'EOS', pdf_theme: { conum_glyphs: '\u0031-\u0039' }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      EOS

      one_text = pdf.find_text '1'
      (expect one_text).to have_size 2
      one_text.each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql 'B12146'
      end
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
