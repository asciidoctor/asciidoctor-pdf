# frozen_string_literal: true

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
        '•back to level one',
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

    it 'should allow theme to change marker characters' do
      pdf_theme = {
        ulist_marker_disc_content: %(\u25ca),
        ulist_marker_circle_content: %(\u25cc),
        ulist_marker_square_content: %(\u25a1),
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      * diamond
       ** dotted circle
        *** white square
      EOS

      (expect pdf.lines).to eql [%(\u25cadiamond), %(\u25ccdotted circle), %(\u25a1white square)]
    end

    it 'should allow FontAwesome icon to be used as list marker' do
      %w(fa far).each do |font_family|
        pdf_theme = {
          ulist_marker_disc_font_family: font_family,
          ulist_marker_disc_content: ?\uf192,
        }

        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        * bullseye!
        EOS

        (expect pdf.lines).to eql [%(\uf192bullseye!)]
        marker_text = (pdf.find_text ?\uf192)[0]
        (expect marker_text).not_to be_nil
        (expect marker_text[:font_name]).to eql 'FontAwesome5Free-Regular'
      end
    end

    it 'should use consistent line height even if list item is entirely monospace' do
      pdf = to_pdf <<~'EOS', analyze: true
      * foo
      * `mono`
      * bar
      EOS

      mark_texts = pdf.find_text '•'
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
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

    it 'should keep list marker with primary text' do
      pdf = to_pdf <<~EOS, analyze: true
      :pdf-page-size: 52mm x 74mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      * list item
      EOS

      marker_text = (pdf.find_text ?\u2022)[0]
      (expect marker_text[:page_number]).to be 2
      item_text = (pdf.find_text 'list item')[0]
      (expect item_text[:page_number]).to be 2
    end

    it 'should position marker correctly when media is prepress and list item is advanced to next page' do
      pdf = to_pdf <<~EOS, pdf_theme: { prose_margin_bottom: 705.5 }, analyze: true
      :media: prepress

      filler

      * first
      * middle
      * last
      EOS

      marker_texts = pdf.find_text string: '•', page_number: 2
      (expect marker_texts).to have_size 2
      (expect marker_texts[0][:x]).to eql marker_texts[1][:x]
    end

    it 'should position marker correctly when media is prepress and list item is split across page' do
      pdf = to_pdf <<~EOS, pdf_theme: { prose_margin_bottom: 705 }, analyze: true
      :media: prepress

      filler

      * first
      * middle +
      more middle
      * last
      EOS

      (expect (pdf.find_text 'middle')[0][:page_number]).to be 1
      (expect (pdf.find_text '•')[1][:page_number]).to be 1
      (expect (pdf.find_text '•')[2][:page_number]).to be 2
    end
  end

  context 'Checklist' do
    it 'should replace markers with checkboxes in checklist' do
      pdf = to_pdf <<~'EOS', analyze: true
      * [ ] todo
      * [x] done
      EOS

      (expect pdf.lines).to eql [%(\u2610todo), %(\u2611done)]
    end

    it 'should allow theme to change checkbox characters' do
      pdf_theme = {
        ulist_marker_unchecked_content: ?\u25d8,
        ulist_marker_checked_content: ?\u25d9,
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      * [ ] todo
      * [x] done
      EOS

      (expect pdf.lines).to eql [%(\u25d8todo), %(\u25d9done)]
    end

    it 'should use glyph from fallback font if not present in main font', visual: true do
      pdf_theme = build_pdf_theme({ ulist_marker_checked_content: ?\u303c }, 'default-with-fallback-font')

      to_file = to_pdf_file <<~'EOS', 'list-checked-glyph-fallback.pdf', pdf_theme: pdf_theme
      * [x] done
      EOS

      (expect to_file).to visually_match 'list-checked-glyph-fallback.pdf'
    end

    it 'should allow theme to use FontAwesome icon for checkbox characters' do
      %w(fa fas).each do |font_family|
        pdf_theme = {
          ulist_marker_unchecked_font_family: font_family,
          ulist_marker_unchecked_content: %(\uf096),
          ulist_marker_checked_font_family: font_family,
          ulist_marker_checked_content: %(\uf046),
        }

        pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
        * [ ] todo
        * [x] done
        EOS

        (expect pdf.lines).to eql [%(\uf096todo), %(\uf046done)]
        unchecked_marker_text = (pdf.find_text ?\uf096)[0]
        (expect unchecked_marker_text).not_to be_nil
        (expect unchecked_marker_text[:font_name]).to eql 'FontAwesome5Free-Solid'
        checked_marker_text = (pdf.find_text ?\uf046)[0]
        (expect checked_marker_text).not_to be_nil
        (expect checked_marker_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      end
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

    it 'should use consistent line height even if list item is entirely monospace' do
      pdf = to_pdf <<~'EOS', analyze: true
      . foo
      . `mono`
      . bar
      EOS

      mark_texts = pdf.text.select {|it| it[:string].end_with? '.' }
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
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
      (expect no9_text[:order]).to be 1
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
      (expect no9_text[:order]).to be 1
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

    it 'should keep list marker with primary text' do
      pdf = to_pdf <<~EOS, analyze: true
      :pdf-page-size: 52mm x 74mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      . list item
      EOS

      marker_text = (pdf.find_text '1.')[0]
      (expect marker_text[:page_number]).to be 2
      item_text = (pdf.find_text 'list item')[0]
      (expect item_text[:page_number]).to be 2
    end
  end

  context 'Mixed' do
    it 'should use correct default markers for mixed nested lists' do
      pdf = to_pdf <<~'EOS', analyze: true
      * l1
       . l2
        ** l3
         .. l4
          *** l5
           ... l6
      * l1
      EOS

      (expect pdf.lines).to eql ['•l1', '1.l2', '▪l3', 'a.l4', '▪l5', 'i.l6', '•l1']
    end

    # NOTE expand this test as necessary to cover the various permutations
    it 'should not insert excess space between nested lists or list items with block content', visual: true do
      to_file = to_pdf_file <<~'EOS', 'list-complex-nested.pdf'
      * list item
       . first
      +
      attached paragraph

       . second
      +
      attached paragraph

      * list item
      +
      attached paragraph

      * list item
      EOS

      (expect to_file).to visually_match 'list-complex-nested.pdf'
    end
  end

  context 'Description' do
    it 'should keep term with primary text' do
      pdf = to_pdf <<~EOS, analyze: true
      :pdf-page-size: 52mm x 80mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      term::
      desc
      EOS

      term_text = (pdf.find_text 'term')[0]
      (expect term_text[:page_number]).to be 2
      desc_text = (pdf.find_text 'desc')[0]
      (expect desc_text[:page_number]).to be 2
    end

    it 'should keep all terms with primary text' do
      pdf = to_pdf <<~EOS, analyze: true
      :pdf-page-size: 52mm x 87.5mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      term 1::
      term 2::
      desc
      EOS

      term1_text = (pdf.find_text 'term 1')[0]
      (expect term1_text[:page_number]).to be 2
      term2_text = (pdf.find_text 'term 2')[0]
      (expect term2_text[:page_number]).to be 2
      desc_text = (pdf.find_text 'desc')[0]
      (expect desc_text[:page_number]).to be 2
    end

    it 'should style term with italic text using bold italic' do
      pdf = to_pdf '_term_:: desc', analyze: true

      term_text = (pdf.find_text 'term')[0]
      (expect term_text[:font_name]).to eql 'NotoSerif-BoldItalic'
    end

    it 'should allow theme to control font properties of term' do
      pdf_theme = {
        description_list_term_font_style: 'italic',
        description_list_term_font_size: 12,
        description_list_term_font_color: 'AA0000',
        description_list_term_text_transform: 'uppercase',
      }
      pdf = to_pdf '*term*:: desc', pdf_theme: pdf_theme, analyze: true

      term_text = (pdf.find_text 'TERM')[0]
      (expect term_text[:font_name]).to eql 'NotoSerif-BoldItalic'
      (expect term_text[:font_size]).to be 12
      (expect term_text[:font_color]).to eql 'AA0000'
    end

    it 'should support complex content', visual: true do
      to_file = to_pdf_file <<~EOS, 'list-complex-dlist.pdf'
      term::
      desc
      +
      more desc
      +
       literal

      yin::
      yang
      EOS

      (expect to_file).to visually_match 'list-complex-dlist.pdf'
    end

    context 'Horizontal' do
      it 'should arrange horizontal list in two columns' do
        pdf = to_pdf <<~'EOS', analyze: true
        [horizontal]
        foo:: bar
        yin:: yang
        EOS

        foo_text = (pdf.find_text 'foo')[0]
        bar_text = (pdf.find_text 'bar')[0]
        (expect foo_text[:y]).to eql bar_text[:y]
      end

      it 'should support multiple terms in horizontal list' do
        pdf = to_pdf <<~'EOS', analyze: true
        [horizontal]
        foo::
        bar::
        baz::
        desc
        EOS

        (expect pdf.find_text 'foo').not_to be_empty
        (expect pdf.find_text 'bar').not_to be_empty
        (expect pdf.find_text 'baz').not_to be_empty
        (expect pdf.find_text 'desc').not_to be_empty
        foo_text = (pdf.find_text 'foo')[0]
        desc_text = (pdf.find_text 'desc')[0]
        (expect foo_text[:y]).to eql desc_text[:y]
      end

      it 'should align term to top when description spans multiple lines' do
        pdf = to_pdf <<~'EOS', analyze: true
        [horizontal]
        foo::
        desc +
        _more desc_
        +
        even more desc
        EOS

        (expect pdf.find_text 'foo').not_to be_empty
        (expect pdf.find_text 'desc').not_to be_empty
        foo_text = (pdf.find_text 'foo')[0]
        desc_text = (pdf.find_text 'desc')[0]
        (expect foo_text[:y]).to eql desc_text[:y]
        more_desc_text = (pdf.find_text 'more desc')[0]
        (expect more_desc_text[:font_name]).to eql 'NotoSerif-Italic'
      end

      it 'should not break term that not extend past the midpoint of the page' do
        pdf = to_pdf <<~EOS, analyze: true
        [horizontal]
        handoverallthekeystoyourkingdom:: #{(['submit'] * 50).join ' '}
        EOS

        (expect pdf.lines[0]).to start_with 'handoverallthekeystoyourkingdomsubmit submit'
      end

      it 'should break term that extends past the midpoint of the page' do
        pdf = to_pdf <<~EOS, analyze: true
        [horizontal]
        handoverallthekeystoyourkingdomtomenow:: #{(['submit'] * 50).join ' '}
        EOS

        (expect pdf.lines[0]).not_to start_with 'handoverallthekeystoyourkingdomtomenow'
      end

      it 'should support complex content in horizontal list', visual: true do
        to_file = to_pdf_file <<~EOS, 'list-horizontal-dlist.pdf'
        [horizontal]
        term::
        desc
        +
        more desc
        +
         literal

        yin::
        yang
        EOS

        (expect to_file).to visually_match 'list-horizontal-dlist.pdf'
      end
    end

    context 'Unordered' do
      it 'should layout unordered description list like an unordered list with subject in bold' do
        pdf = to_pdf <<~'EOS', analyze: true
        [unordered]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        EOS

        (expect pdf.lines).to eql ['•item a: about item a', 'more about item a', '•item b: about item b']
        item_a_subject_text = (pdf.find_text 'item a:')[0]
        (expect item_a_subject_text).not_to be_nil
        (expect item_a_subject_text[:font_name]).to eql 'NotoSerif-Bold'
      end

      it 'should allow subject stop to be customized using subject-stop attribute' do
        pdf = to_pdf <<~'EOS', analyze: true
        [unordered,subject-stop=.]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        EOS

        (expect pdf.lines).to eql ['•item a. about item a', 'more about item a', '•item b. about item b']
      end

      it 'should not add subject stop if subject ends with stop punctuation' do
        pdf = to_pdf <<~'EOS', analyze: true
        [unordered,subject-stop=.]
        item a.:: about item a
        +
        more about item a

        _item b:_::
        about item b

        well?::
        yes
        EOS

        (expect pdf.lines).to eql ['•item a. about item a', 'more about item a', '•item b: about item b', '•well? yes']
      end

      it 'should add subject stop if subject ends with character reference' do
        pdf = to_pdf <<~'EOS', analyze: true
        [unordered]
        &:: ampersand
        >:: greater than
        EOS

        (expect pdf.lines).to eql ['•&: ampersand', '•>: greater than']
      end

      it 'should stack subject on top of text if stack role is present' do
        pdf = to_pdf <<~'EOS', analyze: true
        [unordered.stack]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        EOS

        (expect pdf.lines).to eql ['•item a', 'about item a', 'more about item a', '•item b', 'about item b']
      end
    end

    context 'Ordered' do
      it 'should layout ordered description list like an ordered list with subject in bold' do
        pdf = to_pdf <<~'EOS', analyze: true
        [ordered]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        EOS

        (expect pdf.lines).to eql ['1.item a: about item a', 'more about item a', '2.item b: about item b']
        item_a_subject_text = (pdf.find_text 'item a:')[0]
        (expect item_a_subject_text).not_to be_nil
        (expect item_a_subject_text[:font_name]).to eql 'NotoSerif-Bold'
      end

      it 'should allow subject stop to be customized using subject-stop attribute' do
        pdf = to_pdf <<~'EOS', analyze: true
        [ordered,subject-stop=.]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        EOS

        (expect pdf.lines).to eql ['1.item a. about item a', 'more about item a', '2.item b. about item b']
      end

      it 'should not add subject stop if subject ends with stop punctuation' do
        pdf = to_pdf <<~'EOS', analyze: true
        [ordered,subject-stop=.]
        item a.:: about item a
        +
        more about item a

        _item b:_::
        about item b

        well?::
        yes
        EOS

        (expect pdf.lines).to eql ['1.item a. about item a', 'more about item a', '2.item b: about item b', '3.well? yes']
      end

      it 'should add subject stop if subject ends with character reference' do
        pdf = to_pdf <<~'EOS', analyze: true
        [ordered]
        &:: ampersand
        >:: greater than
        EOS

        (expect pdf.lines).to eql ['1.&: ampersand', '2.>: greater than']
      end

      it 'should stack subject on top of text if stack role is present' do
        pdf = to_pdf <<~'EOS', analyze: true
        [ordered.stack]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        EOS

        (expect pdf.lines).to eql ['1.item a', 'about item a', 'more about item a', '2.item b', 'about item b']
      end
    end
  end

  context 'Q & A' do
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
        '42',
      ]
    end

    it 'should layout Q & A list like a description list with questions in italic', visual: true do
      to_file = to_pdf_file <<~'EOS', 'list-qanda.pdf'
      [qanda]
      What's the answer to the ultimate question?:: 42

      Do you have an opinion?::
      Would you like to share it?::
      Yes and no.
      EOS

      (expect to_file).to visually_match 'list-qanda.pdf'
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

    it 'should use consistent line height even if list item is entirely monospace' do
      pdf = to_pdf <<~'EOS', analyze: true
      ....
      line one <1>
      line two <2>
      line three <3>
      ....
      <1> describe one
      <2> `describe two`
      <3> describe three
      EOS

      mark_texts = [(pdf.find_text ?\u2460)[-1], (pdf.find_text ?\u2461)[-1], (pdf.find_text ?\u2462)[-1]]
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
    end

    it 'should only separate colist and listing or literal block by outline_list_item_spacing value' do
      %w(---- ....).each do |block_delim|
        input = <<~EOS
        #{block_delim}
        line one <1>
        line two
        line three <2>
        #{block_delim}
        <1> First line
        <2> Last line
        EOS

        pdf = to_pdf input, analyze: :line
        bottom_line_y = pdf.lines[2][:from][:y]

        pdf = to_pdf input, analyze: true
        colist_num_text = (pdf.find_text ?\u2460)[-1]
        colist_num_top_y = colist_num_text[:y] + colist_num_text[:font_size]

        gap = bottom_line_y - colist_num_top_y
        # NOTE default outline list spacing is 6
        (expect gap).to be > 6
        (expect gap).to be < 8
      end
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

    it 'should keep list marker with primary text' do
      pdf = to_pdf <<~EOS, analyze: true
      :pdf-page-size: 52mm x 72.25mm
      :pdf-page-margin: 0

      ....
      filler <1>
      #{['filler'] * 10 * ?\n}
      ....

      <1> description
      EOS

      marker_text = (pdf.find_text ?\u2460)[-1]
      (expect marker_text[:page_number]).to be 2
      item_text = (pdf.find_text 'description')[0]
      (expect item_text[:page_number]).to be 2
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
