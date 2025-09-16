# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - List' do
  context 'Unordered' do
    it 'should use different marker for first three list levels' do
      pdf = to_pdf <<~'END', analyze: true
      * level one
       ** level two
        *** level three
         **** level four
      * back to level one
      END

      expected_lines = [
        '• level one',
        '◦ level two',
        '▪ level three',
        '▪ level four',
        '• back to level one',
      ]

      (expect pdf.lines).to eql expected_lines
    end

    it 'should indent each nested list' do
      pdf = to_pdf <<~'END', analyze: true
      * level one
       ** level two
        *** level three
      * back to level one
      END

      prev_it = nil
      %w(one two three).each do |it|
        if prev_it
          text = pdf.find_unique_text %(level #{it})
          prev_text = pdf.find_unique_text %(level #{prev_it})
          (expect text[:x]).to be > prev_text[:x]
        end
        prev_it = it
      end
      (expect (pdf.find_unique_text 'level one')[:x]).to eql (pdf.find_unique_text 'back to level one')[:x]
    end

    it 'should use list item spacing between lineal lists' do
      pdf = to_pdf <<~'END', analyze: true
      * yak
      * foo
       ** bar
      * yin
       ** yang
      END

      item_texts = pdf.find_text %r/^\p{Alpha}/
      (expect item_texts).to have_size 5
      item_spacings = []
      0.upto item_texts.length - 2 do |idx|
        item_spacings << ((item_texts[idx][:y] - item_texts[idx + 1][:y]).round 2)
      end
      (expect item_spacings.uniq).to eql [21.78]
    end

    it 'should disable indent for list if list_indent is 0' do
      pdf = to_pdf <<~'END', pdf_theme: { list_indent: 0 }, analyze: true
      before

      * a
      * b
      * c

      after
      END

      (expect pdf.lines).to include %(\u2022 a)
      before_text = pdf.find_unique_text 'before'
      list_item_text = pdf.find_unique_text 'a'
      (expect before_text[:x]).to eql list_item_text[:x]
    end

    it 'should use marker specified by style' do
      pdf = to_pdf <<~'END', analyze: true
      [square]
      * one
      * two
      * three
      END

      (expect pdf.lines).to eql ['▪ one', '▪ two', '▪ three']
    end

    it 'should emit warning if list style is unrecognized and fall back to disc' do
      (expect do
        pdf = to_pdf <<~'END', analyze: true
        [oval]
        * one
        * two
        * three
        END

        (expect pdf.find_text ?\u2022).to have_size 3
      end).to log_message severity: :WARN, message: 'unknown unordered list style: oval'
    end

    it 'should not emit warning if list style is unrecognized in scratch document' do
      (expect do
        pdf = to_pdf <<~'END', analyze: true
        [%unbreakable]
        --
        [foobarbaz]
        * foo
        * bar
        * baz
        --
        END

        (expect pdf.find_text ?\u2022).to have_size 3
      end).to log_message severity: :WARN, message: 'unknown unordered list style: foobarbaz' # asserts count of 1
    end

    it 'should make bullets invisible if list has no-bullet style' do
      pdf = to_pdf <<~'END', analyze: true
      reference

      [no-bullet]
      * wood
      * hammer
      * nail
      END

      (expect pdf.lines[1..-1]).to eql %w(wood hammer nail)
      left_margin = pdf.text[0][:x]
      indents = pdf.text[1..-1].map {|it| it[:x] }
      (expect indents).to have_size 3
      (expect indents.uniq).to have_size 1
      (expect indents[0]).to be > left_margin
    end

    it 'should disable indent for no-bullet list if list_indent is 0' do
      pdf = to_pdf <<~'END', pdf_theme: { list_indent: 0 }, analyze: true
      before

      [no-bullet]
      * a
      * b
      * c

      after
      END

      (expect pdf.lines).to include 'a'
      before_text = pdf.find_unique_text 'before'
      list_item_text = pdf.find_unique_text 'a'
      (expect before_text[:x]).to eql list_item_text[:x]
    end

    it 'should apply proper indentation for each list style that hides the marker' do
      pdf = to_pdf <<~'END', analyze: true
      reference

      [unstyled]
      * unstyled

      [no-bullet]
      * no-bullet

      [none]
      * none
      END

      (expect pdf.text).to have_size 4
      left_margin = (pdf.find_unique_text 'reference')[:x]
      unstyled_item = pdf.find_unique_text 'unstyled'
      (expect unstyled_item[:x]).to eql left_margin
      no_bullet_item = pdf.find_unique_text 'no-bullet'
      (expect no_bullet_item[:x]).to eql 56.3805
      none_item = pdf.find_unique_text 'none'
      (expect none_item[:x]).to eql 66.24
    end

    it 'should not indent list with no marker if list indent is not set or set to 0 in theme' do
      [nil, 0].each do |indent|
        pdf = to_pdf <<~'END', pdf_theme: { list_indent: indent }, analyze: true
        before

        [no-bullet]
        * a
        * b
        * c

        after
        END

        left_margin = (pdf.find_unique_text 'before')[:x]
        none_item = pdf.find_unique_text 'a'
        (expect none_item[:x]).to eql left_margin
      end
    end

    it 'should allow theme to change marker characters' do
      pdf_theme = {
        ulist_marker_disc_content: ?\u25ca,
        ulist_marker_circle_content: ?\u25cc,
        ulist_marker_square_content: '$',
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      * diamond
       ** dotted circle
        *** dollar
      END

      (expect pdf.lines).to eql [%(\u25ca diamond), %(\u25cc dotted circle), '$ dollar']
    end

    it 'should allow theme to change marker color for ulist' do
      [:list_marker_font_color, :ulist_marker_font_color].each do |key|
        pdf = to_pdf <<~'END', pdf_theme: { key => '00FF00' }, analyze: true
        * all
        * the
        * things
        END

        marker_colors = (pdf.find_text ?\u2022).map {|it| it[:font_color] }.uniq
        (expect marker_colors).to eql ['00FF00']
      end
    end

    it 'should allow theme to change marker font size, font family, and line height for ulist' do
      pdf_theme = {
        extends: 'default-with-font-fallbacks',
        ulist_marker_font_family: 'M+ 1p Fallback',
        ulist_marker_font_size: 21,
        ulist_marker_line_height: 0.625,
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      * all
      * the
      * things
      END

      marker = (pdf.find_text %(\u2022))[0]
      text = pdf.find_unique_text 'all'
      (expect marker[:font_name]).to eql 'mplus-1p-regular'
      (expect marker[:font_size]).to eql 21
      (expect marker[:y]).to be < text[:y]
    end

    it 'should allow theme to change marker font style for ulist' do
      pdf_theme = { ulist_marker_font_style: 'bold' }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      * one
      * two
      * three
      END

      marker = (pdf.find_text ?\u2022)[0]
      (expect marker[:font_name]).to eql 'NotoSerif-Bold'
    end

    it 'should allow theme to change specific marker font style for ulist' do
      pdf_theme = { ulist_marker_circle_font_style: 'bold' }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      [circle]
      * one
      * two
      * three
      END

      marker = (pdf.find_text ?\u25e6)[0]
      (expect marker[:font_name]).to eql 'NotoSerif-Bold'
    end

    it 'should reserve enough space for marker that is not found in any font' do
      pdf_theme = {
        extends: 'default-with-font-fallbacks',
        ulist_marker_disc_content: ?\u2055,
      }
      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      * missing marker
      END

      marker_text = pdf.find_unique_text ?\u2055
      (expect marker_text[:width]).to eql 5.25
    end

    it 'should allow FontAwesome icon to be used as list marker' do
      %w(fa far).each do |font_family|
        pdf_theme = {
          ulist_marker_disc_font_family: font_family,
          ulist_marker_disc_content: ?\uf192,
        }

        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        * bullseye!
        END

        (expect pdf.lines).to eql [%(\uf192 bullseye!)]
        marker_text = pdf.find_unique_text ?\uf192
        (expect marker_text).not_to be_nil
        (expect marker_text[:font_name]).to eql 'FontAwesome5Free-Regular'
      end
    end

    it 'should not insert extra blank line if list item text is forced to break' do
      pdf = to_pdf <<~END, analyze: true
      * #{'a' * 100}
      * b +
      b
      END

      a1_marker_text, b1_marker_text = pdf.find_text ?\u2022
      a1_text, a2_text = pdf.find_text %r/^a+$/
      b1_text, b2_text = pdf.find_text %r/^b$/
      (expect a1_text[:y]).to eql a1_marker_text[:y]
      (expect b1_text[:y]).to eql b1_marker_text[:y]
      (expect (a1_text[:y] - a2_text[:y]).round 2).to eql ((b1_text[:y] - b2_text[:y]).round 2)
    end

    it 'should use consistent line height even if list item is entirely monospace' do
      pdf = to_pdf <<~'END', analyze: true
      * foo
      * `mono`
      * bar
      END

      mark_texts = pdf.find_text '•'
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
    end

    it 'should apply consistent line height to wrapped line that only contained monospaced text' do
      pdf = to_pdf <<~'END', analyze: true
      * A list item containing a `short code phrase` and a `slightly longer code phrase` and a `very long code phrase that wraps to the next line`
      * B +
      `code phrase for reference`
      * C
      END

      mark_texts = pdf.find_text ?\u2022
      a1_text = pdf.find_unique_text %r/^A /
      b1_text = pdf.find_unique_text 'B'
      a_code_phrase_text, b_code_phrase_text = pdf.find_text %r/^code phrase /
      (expect mark_texts).to have_size 3
      item1_to_item2_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      item2_to_item3_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect item1_to_item2_spacing).to eql item2_to_item3_spacing
      (expect (a1_text[:y] - a_code_phrase_text[:y]).round 2).to eql ((b1_text[:y] - b_code_phrase_text[:y]).round 2)
    end

    it 'should apply correct margin if primary text of list item is blank' do
      pdf = to_pdf <<~'END', analyze: true
      * foo
      * {blank}
      * bar
      END

      mark_texts = pdf.find_text '•'
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
    end

    it 'should align first block of list item with marker if primary text is blank' do
      pdf = to_pdf <<~'END', analyze: true
      * {blank}
      +
      text
      END

      text = pdf.text
      (expect text).to have_size 2
      (expect text[0][:y]).to eql text[1][:y]
    end

    it 'should keep list marker with primary text' do
      pdf = to_pdf <<~END, analyze: true
      :pdf-page-size: 52mm x 74mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      * list item
      END

      marker_text = pdf.find_unique_text ?\u2022
      (expect marker_text[:page_number]).to be 2
      item_text = pdf.find_unique_text 'list item'
      (expect item_text[:page_number]).to be 2
    end

    it 'should position marker correctly when media is prepress and list item is advanced to next page' do
      pdf = to_pdf <<~'END', pdf_theme: { prose_margin_bottom: 705.5 }, analyze: true
      :media: prepress

      filler

      * first
      * middle
      * last
      END

      marker_texts = pdf.find_text '•', page_number: 2
      (expect marker_texts).to have_size 2
      (expect marker_texts[0][:x]).to eql marker_texts[1][:x]
    end

    it 'should position marker correctly when media is prepress and list item is split across page' do
      pdf = to_pdf <<~'END', pdf_theme: { prose_margin_bottom: 705 }, analyze: true
      :media: prepress

      filler

      * first
      * middle +
      more middle
      * last
      END

      (expect (pdf.find_unique_text 'middle')[:page_number]).to be 1
      (expect (pdf.find_text '•')[1][:page_number]).to be 1
      (expect (pdf.find_text '•')[2][:page_number]).to be 2
    end

    it 'should reuse next page of block with background when positioning marker when media is prepress' do
      filler = ['filler']
      filler_list_item = ['* Ex nam suas nemore dignissim, vel apeirian democritum et. At ornatus splendide sed, phaedrum omittantur usu an, vix an noster voluptatibus.']
      pdf = to_pdf <<~END
      :media: prepress

      .Sidebar
      ****
      [%hardbreaks]
      #{filler * 10 * ?\n}

      image::tux.png[pdfwidth=54.75mm]

      #{filler_list_item * 15 * ?\n}

      [%hardbreaks]
      #{filler * 5 * ?\n}
      ****

      [%hardbreaks]
      #{filler * 5 * ?\n}

      <<<

      [%hardbreaks]
      #{filler * 5 * ?\n}
      END

      pages = pdf.pages
      (expect pages).to have_size 3
      3.times do |idx|
        page_content = pages[idx].raw_content
        page_content = page_content.delete_prefix %(q\n) while page_content.start_with? %(q\n)
        if idx == 2
          (expect page_content).not_to start_with %(/DeviceRGB cs\n0.93333 0.93333 0.93333 scn\n)
        else
          (expect page_content).to start_with %(/DeviceRGB cs\n0.93333 0.93333 0.93333 scn\n)
        end
      end
    end

    it 'should allow text alignment to be set using role', visual: true do
      to_file = to_pdf_file <<~END, 'list-text-left-role.pdf'
      [.text-left]
      * #{lorem_ipsum '2-sentences-1-paragraph'}
      END
      (expect to_file).to visually_match 'list-text-left.pdf'
    end

    it 'should allow text alignment to be set using theme', visual: true do
      to_file = to_pdf_file <<~END, 'list-text-left-theme.pdf', pdf_theme: { list_text_align: 'left' }
      * #{lorem_ipsum '2-sentences-1-paragraph'}
      END
      (expect to_file).to visually_match 'list-text-left.pdf'
    end
  end

  context 'Checklist' do
    it 'should replace markers with checkboxes in checklist' do
      pdf = to_pdf <<~'END', analyze: true
      * [ ] todo
      * [x] done
      END

      (expect pdf.lines).to eql [%(\u2610 todo), %(\u2611 done)]
    end

    it 'should allow theme to change checkbox characters' do
      pdf_theme = {
        ulist_marker_unchecked_content: ?\u25d8,
        ulist_marker_checked_content: ?\u25d9,
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      * [ ] todo
      * [x] done
      END

      (expect pdf.lines).to eql [%(\u25d8 todo), %(\u25d9 done)]
    end

    it 'should use glyph from fallback font if not present in main font', visual: true do
      pdf_theme = {
        extends: 'default-with-font-fallbacks',
        ulist_marker_checked_content: ?\u303c,
      }
      to_file = to_pdf_file <<~'END', 'list-checked-glyph-fallback.pdf', pdf_theme: pdf_theme
      * [x] done
      END

      (expect to_file).to visually_match 'list-checked-glyph-fallback.pdf'
    end

    it 'should allow theme to use FontAwesome icon for checkbox characters' do
      %w(fa fas).each do |font_family|
        pdf_theme = {
          ulist_marker_unchecked_font_family: font_family,
          ulist_marker_unchecked_content: ?\uf096,
          ulist_marker_checked_font_family: font_family,
          ulist_marker_checked_content: ?\uf046,
        }

        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        * [ ] todo
        * [x] done
        END

        (expect pdf.lines).to eql [%(\uf096 todo), %(\uf046 done)]
        unchecked_marker_text = pdf.find_unique_text ?\uf096
        (expect unchecked_marker_text).not_to be_nil
        (expect unchecked_marker_text[:font_name]).to eql 'FontAwesome5Free-Solid'
        checked_marker_text = pdf.find_unique_text ?\uf046
        (expect checked_marker_text).not_to be_nil
        (expect checked_marker_text[:font_name]).to eql 'FontAwesome5Free-Solid'
      end
    end
  end

  context 'Ordered' do
    it 'should number list items using arabic, loweralpha, lowerroman, upperalpha, upperroman numbering by default' do
      pdf = to_pdf <<~'END', analyze: true
      . 1
       .. a
        ... i
         .... A
          ..... I
      . 2
      . 3
      END

      (expect pdf.lines).to eql ['1. 1', 'a. a', 'i. i', 'A. A', 'I. I', '2. 2', '3. 3']
    end

    it 'should indent each nested list' do
      pdf = to_pdf <<~'END', analyze: true
      . 1
       .. a
        ... i
         .... A
          ..... I
      . 2
      . 3
      END

      prev_it = nil
      %w(1 a i A I).each do |it|
        if prev_it
          text = (pdf.find_text it)[0]
          prev_text = (pdf.find_text prev_it)[0]
          (expect text[:x]).to be > prev_text[:x]
        end
        prev_it = it
      end
      (expect (pdf.find_text '1')[0][:x]).to eql (pdf.find_text '2')[0][:x]
    end

    it 'should use marker specified by style' do
      pdf = to_pdf <<~'END', analyze: true
      [lowerroman]
      . one
      . two
      . three
      END

      (expect pdf.lines).to eql ['i. one', 'ii. two', 'iii. three']
    end

    it 'should fall back to arabic if list style is unknown' do
      (expect do
        pdf = to_pdf <<~'END', analyze: true
        [binary]
        . one
        . two
        . three
        END

        (expect pdf.lines[0]).to eql '1. one'
      end).not_to log_message
    end

    it 'should support decimal marker style' do
      blank_line = %(\n\n)
      pdf = to_pdf <<~END, analyze: true
      [decimal]
      #{(?a..?z).map {|c| '. ' + c }.join blank_line}
      END

      lines = pdf.lines
      (expect lines).to have_size 26
      (expect lines[0]).to eql '01. a'
      (expect lines[-1]).to eql '26. z'
    end

    it 'should support decimal marker style when start value has two digits' do
      blank_line = %(\n\n)
      pdf = to_pdf <<~END, analyze: true
      [decimal,start=10]
      #{(?a..?z).map {|c| '. ' + c }.join blank_line}
      END

      lines = pdf.lines
      (expect lines).to have_size 26
      (expect lines[0]).to eql '10. a'
      (expect lines[-1]).to eql '35. z'
    end

    it 'should allow theme to change marker color for olist' do
      [:list_marker_font_color, :olist_marker_font_color].each do |key|
        pdf = to_pdf <<~'END', pdf_theme: { key => '00FF00' }, analyze: true
        . one
        . two
        . three
        END

        marker_colors = (pdf.find_text %r/\d\./).map {|it| it[:font_color] }.uniq
        (expect marker_colors).to eql ['00FF00']
      end
    end

    it 'should allow theme to change marker font size, font family, and line height for olist' do
      pdf_theme = {
        olist_marker_font_family: 'M+ 1mn',
        olist_marker_font_size: 12.75,
        olist_marker_line_height: 0.976,
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      . one
      . two
      . three
      END

      marker = pdf.find_unique_text '1.'
      text = pdf.find_unique_text 'one'
      (expect marker[:font_name]).to eql 'mplus1mn-regular'
      (expect marker[:font_size]).to eql 12.75
      (expect marker[:y].round 2).to eql (text[:y].round 2)
    end

    it 'should allow theme to change marker font style for olist' do
      pdf_theme = { olist_marker_font_style: 'bold' }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      . one
      . two
      . three
      END

      marker = pdf.find_unique_text '1.'
      (expect marker[:font_name]).to eql 'NotoSerif-Bold'
    end

    it 'should use consistent line height even if list item is entirely monospace' do
      pdf = to_pdf <<~'END', analyze: true
      . foo
      . `mono`
      . bar
      END

      mark_texts = pdf.text.select {|it| it[:string].end_with? '.' }
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
    end

    it 'should align list numbers to right and extend towards left margin' do
      pdf = to_pdf <<~'END', analyze: true
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
      END

      nine_text = pdf.find_unique_text 'nine'
      ten_text = pdf.find_unique_text 'ten'

      (expect nine_text[:x]).to eql ten_text[:x]

      no9_text = pdf.find_unique_text '9.'
      no10_text = pdf.find_unique_text '10.'
      (expect no9_text[:x]).to be > no10_text[:x]
    end

    it 'should number list in reverse order for each style if reversed option is set' do
      items = %w(ten nine eight seven six five four three two one)
      {
        '' => %w(10 1),
        'decimal' => %w(10 01),
        'lowergreek' => %W(\u03ba \u03b1),
        'loweralpha' => %w(j a),
        'upperalpha' => %w(J A),
      }.each do |style, (last, first)|
        pdf = to_pdf <<~END, analyze: true
        [#{style}%reversed]
        #{items.map {|it| %(. #{it}) }.join ?\n}
        END
        lines = pdf.lines
        expect(lines[0]).to eql %(#{last}. ten)
        expect(lines[-1]).to eql %(#{first}. one)
        ten_text = pdf.find_unique_text 'ten'
        one_text = pdf.find_unique_text 'one'
        (expect ten_text[:x]).to eql one_text[:x]
      end
    end

    it 'should start numbering at value of start attribute if specified' do
      pdf = to_pdf <<~'END', analyze: true
      [start=9]
      . nine
      . ten
      END

      no1_text = pdf.find_unique_text '1.'
      (expect no1_text).to be_nil
      no9_text = pdf.find_unique_text '9.'
      (expect no9_text).not_to be_nil
      (expect no9_text[:order]).to be 1
      (expect pdf.lines).to eql ['9. nine', '10. ten']
    end

    it 'should start numbering at value of specified start attribute using specified numeration style' do
      pdf = to_pdf <<~'END', analyze: true
      [upperroman,start=9]
      . nine
      . ten
      END

      no1_text = pdf.find_unique_text 'I.'
      (expect no1_text).to be_nil
      no9_text = pdf.find_unique_text 'IX.'
      (expect no9_text).not_to be_nil
      (expect no9_text[:order]).to be 1
      (expect pdf.lines).to eql ['IX. nine', 'X. ten']
    end

    it 'should ignore start attribute if marker is disabled' do
      pdf = to_pdf <<~'END', analyze: true
      [unstyled,start=10]
      . a
      . b
      . c
      END

      (expect pdf.lines).to eql %w(a b c)
    end

    it 'should ignore start value of 1' do
      pdf = to_pdf <<~'END', analyze: true
      [start=1]
      . one
      . two
      . three
      END

      (expect pdf.lines).to eql ['1. one', '2. two', '3. three']
    end

    it 'should allow start value to be less than 1 for list with arabic numbering' do
      pdf = to_pdf <<~'END', analyze: true
      [start=-1]
      . negative one
      . zero
      . positive one
      END

      (expect pdf.lines).to eql ['-1. negative one', '0. zero', '1. positive one']
    end

    it 'should allow start value to be less than 1 for list with roman numbering' do
      pdf = to_pdf <<~'END', analyze: true
      [lowerroman,start=-1]
      . negative one
      . zero
      . positive one
      END

      (expect pdf.lines).to eql ['-1. negative one', '0. zero', 'i. positive one']
    end

    it 'should allow start value to be less than 1 for list with decimal numbering' do
      pdf = to_pdf <<~'END', analyze: true
      [decimal,start=-3]
      . on
      . our
      . way
      . to
      . one
      END

      (expect pdf.lines).to eql ['-03. on', '-02. our', '-01. way', '00. to', '01. one']
    end

    # FIXME: this should be -1, 0, a
    it 'should ignore start value less than 1 for list with alpha numbering' do
      pdf = to_pdf <<~'END', analyze: true
      [loweralpha,start=-1]
      . negative one
      . zero
      . positive one
      END

      (expect pdf.lines).to eql ['a. negative one', 'b. zero', 'c. positive one']
    end

    it 'should make numbers invisible if list has unnumbered style' do
      pdf = to_pdf <<~'END', analyze: true
      reference

      [unnumbered]
      . one
      . two
      . three
      END

      (expect pdf.lines[1..-1]).to eql %w(one two three)
      left_margin = pdf.text[0][:x]
      indents = pdf.text[1..-1].map {|it| it[:x] }
      (expect indents).to have_size 3
      (expect indents.uniq).to have_size 1
      (expect indents[0]).to be > left_margin
    end

    it 'should apply proper indentation for each list style that hides the marker' do
      pdf = to_pdf <<~'END', analyze: true
      reference

      [unstyled]
      . unstyled

      [no-bullet]
      . no-bullet

      [unnumbered]
      . unnumbered

      [none]
      . none
      END

      (expect pdf.text).to have_size 5
      left_margin = (pdf.find_unique_text 'reference')[:x]
      unstyled_item = pdf.find_unique_text 'unstyled'
      (expect unstyled_item[:x]).to eql left_margin
      no_bullet_item = pdf.find_unique_text 'no-bullet'
      (expect no_bullet_item[:x]).to eql 51.6765
      unnumbered_item = pdf.find_unique_text 'unnumbered'
      (expect unnumbered_item[:x]).to eql 51.6765
      none_item = pdf.find_unique_text 'none'
      (expect none_item[:x]).to eql 66.24
    end

    it 'should keep list marker with primary text' do
      pdf = to_pdf <<~END, analyze: true
      :pdf-page-size: 52mm x 74mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      . list item
      END

      marker_text = pdf.find_unique_text '1.'
      (expect marker_text[:page_number]).to be 2
      item_text = pdf.find_unique_text 'list item'
      (expect item_text[:page_number]).to be 2
    end
  end

  context 'Mixed' do
    it 'should use correct default markers for mixed nested lists' do
      pdf = to_pdf <<~'END', analyze: true
      * l1
       . l2
        ** l3
         .. l4
          *** l5
           ... l6
      * l1
      END

      (expect pdf.lines).to eql ['• l1', '1. l2', '▪ l3', 'a. l4', '▪ l5', 'i. l6', '• l1']
    end

    # NOTE: expand this test as necessary to cover the various permutations
    it 'should not insert excess space between nested lists or list items with block content', visual: true do
      to_file = to_pdf_file <<~'END', 'list-complex-nested.pdf'
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
      END

      (expect to_file).to visually_match 'list-complex-nested.pdf'
    end
  end

  context 'Description' do
    it 'should keep term with primary text' do
      pdf = to_pdf <<~END, analyze: true
      :pdf-page-size: 52mm x 80mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      term::
      desc
      END

      term_text = pdf.find_unique_text 'term'
      (expect term_text[:page_number]).to be 2
      desc_text = pdf.find_unique_text 'desc'
      (expect desc_text[:page_number]).to be 2
    end

    it 'should keep all terms with primary text' do
      pdf = to_pdf <<~END, analyze: true
      :pdf-page-size: 52mm x 87.5mm
      :pdf-page-margin: 0

      ....
      #{['filler'] * 11 * ?\n}
      ....

      term 1::
      term 2::
      desc
      END

      term1_text = pdf.find_unique_text 'term 1'
      (expect term1_text[:page_number]).to be 2
      term2_text = pdf.find_unique_text 'term 2'
      (expect term2_text[:page_number]).to be 2
      desc_text = pdf.find_unique_text 'desc'
      (expect desc_text[:page_number]).to be 2
    end

    it 'should style term with italic text using bold italic' do
      pdf = to_pdf '_term_:: desc', analyze: true

      term_text = pdf.find_unique_text 'term'
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

      term_text = pdf.find_unique_text 'TERM'
      (expect term_text[:font_name]).to eql 'NotoSerif-BoldItalic'
      (expect term_text[:font_size]).to be 12
      (expect term_text[:font_color]).to eql 'AA0000'
    end

    it 'should allow theme to control line height of term' do
      input = <<~'END'
      first term::
      second term::
      description
      END

      pdf = to_pdf input, analyze: true

      reference_line_height = (pdf.find_unique_text 'first term')[:y] - (pdf.find_unique_text 'second term')[:y]

      pdf = to_pdf input, analyze: true, pdf_theme: { description_list_term_line_height: 2 }

      term_line_height = (pdf.find_unique_text 'first term')[:y] - (pdf.find_unique_text 'second term')[:y]

      (expect term_line_height).to be > reference_line_height
      (expect (term_line_height - reference_line_height).round 2).to eql 9.0
    end

    it 'should support complex content', visual: true do
      to_file = to_pdf_file <<~'END', 'list-complex-dlist.pdf'
      term::
      desc
      +
      more desc
      +
       literal

      yin::
      yang
      END

      (expect to_file).to visually_match 'list-complex-dlist.pdf'
    end

    it 'should put margin below description when item has an attached block' do
      pdf_theme = { base_line_height: 1, sidebar_background_color: 'transparent' }
      input = <<~'END'
      term:: desc
      +
      ****
      sidebar
      ****

      ****
      after
      ****
      END

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
        .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
      desc_text = pdf.find_unique_text 'desc'
      (expect desc_text[:y] - horizontal_lines[0][:from][:y]).to (be_within 1).of 15.0
      (expect horizontal_lines[1][:from][:y] - horizontal_lines[2][:from][:y]).to eql 12.0
    end

    it 'should use narrow spacing around lineal list' do
      pdf = to_pdf <<~'END', pdf_theme: { extends: 'base', base_line_height: 1 }, analyze: true
      yin::
      * foobar
      yang::
      END

      spacing_above = (pdf.find_unique_text %r/^yin/)[:y] - (pdf.find_unique_text 'foobar').yield_self {|it| it[:y] + it[:font_size] }
      spacing_below = (pdf.find_unique_text 'foobar')[:y] - (pdf.find_unique_text 'yang').yield_self {|it| it[:y] + it[:font_size] }
      (expect spacing_above).to (be_within 1).of 6.0 # 3.0 + font metrics
      (expect spacing_below).to (be_within 1).of 8.0 # 6.0 + font metrics
    end

    it 'should put margin below description when item has a single nested list' do
      input = <<~'END'
      term:: desc
      * nested item

      after
      END

      pdf = to_pdf input, pdf_theme: { base_line_height: 1 }, analyze: true
      desc_text = pdf.find_unique_text 'desc'
      nested_item_text = pdf.find_unique_text 'nested item'
      after_text = pdf.find_unique_text 'after'
      above_list_item = (desc_text[:y] - nested_item_text[:y]).round 2
      below_list_item = (nested_item_text[:y] - after_text[:y]).round 2
      (expect above_list_item).to eql below_list_item
      (expect desc_text[:y] - (nested_item_text[:y] + nested_item_text[:font_size])).to (be_within 1).of 15.0
    end

    it 'should support last item with no description' do
      pdf = to_pdf <<~'END', analyze: true
      yin:: yang
      foo::
      END

      (expect pdf.lines).to eql %w(yin yang foo)
      (expect pdf.find_text 'foo').not_to be_empty
      yin_text = pdf.find_unique_text 'yin'
      foo_text = pdf.find_unique_text 'foo'
      (expect foo_text[:x]).to eql yin_text[:x]
    end

    it 'should apply correct margin to last item with no description' do
      pdf = to_pdf <<~'END', analyze: true
      [cols=2*a]
      |===
      |
      term::

      []
      after

      |
      term:: desc
      |===
      END

      after_text = pdf.find_unique_text 'after'
      desc_text = pdf.find_unique_text 'desc'
      (expect desc_text[:y]).to be > after_text[:y]
      delta = desc_text[:y] - after_text[:y]
      (expect delta).to eql 9.0 # bottom margin - term spacing
    end

    context 'Horizontal' do
      it 'should not modify original document model during conversion' do
        doc = Asciidoctor.load <<~'END', backend: 'pdf'
        [horizontal]
        foo:: bar
        END

        original_dlist = doc.blocks[0]
        original_term, original_desc = (original_item = (original_items = original_dlist.items)[0])
        doc.convert
        dlist = doc.blocks[0]
        term, desc = (item = (items = dlist.items)[0])
        (expect dlist).to eq original_dlist
        (expect term).to eq original_term
        (expect items).to eq original_items
        (expect item).to eq original_item
        (expect desc).to eq original_desc
      end

      it 'should arrange horizontal list in two columns' do
        pdf = to_pdf <<~'END', analyze: true
        [horizontal]
        foo:: bar
        yin:: yang
        END

        foo_text = pdf.find_unique_text 'foo'
        bar_text = pdf.find_unique_text 'bar'
        (expect foo_text[:y]).to eql bar_text[:y]
      end

      # NOTE: font_size is not supported since it can impact the layout
      it 'should allow theme to control font properties of term' do
        pdf_theme = {
          description_list_term_font_style: 'italic',
          description_list_term_font_color: 'AA0000',
          description_list_term_text_transform: 'uppercase',
        }
        pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
        [horizontal]
        term:: desc
        END

        term_text = pdf.find_unique_text 'TERM'
        (expect term_text[:font_name]).to eql 'NotoSerif-Italic'
        (expect term_text[:font_color]).to eql 'AA0000'
      end

      it 'should allow theme to control line height of term' do
        input = <<~'END'
        [horizontal]
        first term::
        second term::
        description
        END

        pdf = to_pdf input, analyze: true

        reference_line_height = (pdf.find_unique_text 'first term')[:y] - (pdf.find_unique_text 'second term')[:y]

        pdf = to_pdf input, analyze: true, pdf_theme: { description_list_term_line_height: 2 }

        term_line_height = (pdf.find_unique_text 'first term')[:y] - (pdf.find_unique_text 'second term')[:y]

        (expect term_line_height).to be > reference_line_height
        (expect (term_line_height - reference_line_height).round 2).to eql 9.0
      end

      it 'should include title above horizontal list' do
        pdf = to_pdf <<~'END', analyze: true
        .Balance
        [horizontal]
        foo:: bar
        yin:: yang
        END

        title_text = pdf.find_text 'Balance'
        (expect title_text).to have_size 1
        title_text = title_text[0]
        (expect title_text[:font_name]).to eql 'NotoSerif-Italic'
        list_text = pdf.find_unique_text 'foo'
        (expect title_text[:y]).to be > list_text[:y]
      end

      it 'should inherit term font styles from theme' do
        pdf = to_pdf <<~'END', analyze: true
        [horizontal]
        __f__oo:: bar
        END

        text = pdf.text
        (expect text).to have_size 3
        (expect text[0][:string]).to eql 'f'
        (expect text[0][:font_name]).to eql 'NotoSerif-BoldItalic'
        (expect text[1][:string]).to eql 'oo'
        (expect text[1][:font_name]).to eql 'NotoSerif-Bold'
      end

      it 'should apply inline formatted to term even if font style is set to normal by theme' do
        pdf = to_pdf <<~'END', pdf_theme: { description_list_term_font_style: 'normal' }, analyze: true
        [horizontal]
        **f**oo:: bar
        END

        text = pdf.text
        (expect text).to have_size 3
        (expect text[0][:string]).to eql 'f'
        (expect text[0][:font_name]).to eql 'NotoSerif-Bold'
        (expect text[1][:string]).to eql 'oo'
        (expect text[1][:font_name]).to eql 'NotoSerif'
      end

      it 'should support item with no desc' do
        pdf = to_pdf <<~'END', analyze: true
        [horizontal]
        yin:: yang
        foo::
        END

        (expect pdf.find_text 'foo').not_to be_empty
        yin_text = pdf.find_unique_text 'yin'
        foo_text = pdf.find_unique_text 'foo'
        (expect foo_text[:x]).to eql yin_text[:x]
      end

      it 'should support item with only blocks' do
        pdf = to_pdf <<~'END', analyze: true
        [horizontal]
        yin::
        +
        yang

        foo:: bar
        END

        (expect pdf.lines).to eql ['yin yang', 'foo bar']
        yin_text = pdf.find_unique_text 'yin'
        yang_text = pdf.find_unique_text 'yang'
        foo_text = pdf.find_unique_text 'foo'
        bar_text = pdf.find_unique_text 'bar'
        (expect yin_text[:y] - foo_text[:y]).to eql yang_text[:y] - bar_text[:y]
      end

      it 'should support multiple terms in horizontal list' do
        pdf = to_pdf <<~'END', analyze: true
        [horizontal]
        foo::
        bar::
        baz::
        desc
        END

        (expect pdf.find_text 'foo').not_to be_empty
        (expect pdf.find_text 'bar').not_to be_empty
        (expect pdf.find_text 'baz').not_to be_empty
        (expect pdf.find_text 'desc').not_to be_empty
        foo_text = pdf.find_unique_text 'foo'
        desc_text = pdf.find_unique_text 'desc'
        (expect foo_text[:y]).to eql desc_text[:y]
      end

      it 'should start next entry after terms when terms occupy more lines than desc' do
        pdf = to_pdf <<~'END', analyze: true
        [horizontal]
        foo::
        bar::
        baz::
        desc

        fizz:: buzz
        END

        (expect (pdf.find_unique_text 'fizz')[:y]).to be < (pdf.find_unique_text 'desc')[:y]
        (expect (pdf.find_unique_text 'fizz')[:y]).to be < (pdf.find_unique_text 'baz')[:y]
      end

      it 'should keep multiple terms together when entry starts near page boundary' do
        pdf = with_content_spacer 10, 700 do |spacer_path|
          to_pdf <<~END, analyze: true
          image::#{spacer_path}[]

          [horizontal]
          foo::
          bar::
          baz::
          desc
          END
        end

        (expect (pdf.find_unique_text 'foo')[:page_number]).to eql 2
      end

      it 'should align term to top when description spans multiple lines' do
        pdf = to_pdf <<~'END', analyze: true
        [horizontal]
        foo::
        desc +
        _more desc_
        +
        even more desc
        END

        (expect pdf.find_text 'foo').not_to be_empty
        (expect pdf.find_text 'desc').not_to be_empty
        foo_text = pdf.find_unique_text 'foo'
        desc_text = pdf.find_unique_text 'desc'
        (expect foo_text[:y]).to eql desc_text[:y]
        more_desc_text = pdf.find_unique_text 'more desc'
        (expect more_desc_text[:font_name]).to eql 'NotoSerif-Italic'
      end

      it 'should not break term that does not extend past the midpoint of the page' do
        pdf = to_pdf <<~END, analyze: true
        [horizontal]
        handoverallthekeystoyourkingdom:: #{(['submit'] * 50).join ' '}
        END

        (expect pdf.lines[0]).to start_with 'handoverallthekeystoyourkingdom submit submit'
      end

      it 'should break term that extends past the midpoint of the page' do
        pdf = to_pdf <<~END, analyze: true
        [horizontal]
        handoverallthekeystoyourkingdomtomenow:: #{(['submit'] * 50).join ' '}
        END

        (expect pdf.lines[0]).not_to start_with 'handoverallthekeystoyourkingdomtomenow'
      end

      it 'should support complex content in horizontal list', visual: true do
        to_file = to_pdf_file <<~'END', 'list-horizontal-dlist.pdf'
        [horizontal]
        term::
        desc
        +
        more desc
        +
         literal

        yin::
        yang
        END

        (expect to_file).to visually_match 'list-horizontal-dlist.pdf'
      end

      it 'should correctly compute height of attached delimited block inside dlist at page top' do
        pdf_theme = { sidebar_background_color: 'transparent' }
        input = <<~'END'
        [horizontal]
        first term::
        +
        ****
        sidebar inside list
        ****

        ****
        sidebar outside list
        ****
        END

        horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
          .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
        (expect horizontal_lines).to have_size 4
        inside_sidebar_height = horizontal_lines[0][:from][:y] - horizontal_lines[1][:from][:y]
        outside_sidebar_height = horizontal_lines[2][:from][:y] - horizontal_lines[3][:from][:y]
        (expect (inside_sidebar_height.round 2)).to eql (outside_sidebar_height.round 2)
      end

      it 'should correctly compute height of attached delimited block inside dlist below page top' do
        pdf_theme = { sidebar_background_color: 'transparent' }
        input = <<~'END'
        ****
        sidebar outside list
        ****

        [horizontal]
        first term::
        +
        ****
        sidebar inside list
        ****
        END

        horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
          .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
        (expect horizontal_lines).to have_size 4
        outside_sidebar_height = horizontal_lines[0][:from][:y] - horizontal_lines[1][:from][:y]
        inside_sidebar_height = horizontal_lines[2][:from][:y] - horizontal_lines[3][:from][:y]
        (expect (inside_sidebar_height.round 2)).to eql (outside_sidebar_height.round 2)
      end

      it 'should leave correct spacing after last attached block' do
        pdf_theme = { sidebar_background_color: 'transparent' }
        input = <<~'END'
        [horizontal]
        first term::
        +
        ****
        sidebar for first term
        ****

        second term::
        +
        ****
        sidebar for second term
        ****

        ****
        sidebar outside list
        ****
        END

        horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
          .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
        (expect horizontal_lines).to have_size 6
        item_spacing = horizontal_lines[1][:from][:y] - horizontal_lines[2][:from][:y]
        spacing_below_list = horizontal_lines[3][:from][:y] - horizontal_lines[4][:from][:y]
        (expect item_spacing.round 2).to eql 12.0
        (expect spacing_below_list.round 2).to eql 12.0
      end

      it 'should convert horizontal dlist inside AsciiDoc table cell and not add bottom margin' do
        pdf_theme = { sidebar_background_color: 'transparent' }
        input = <<~'END'
        [frame=ends,grid=none]
        |===
        a|
        [horizontal]
        term:: desc
        +
        ****
        sidebar for term
        ****
        |===
        END

        horizontal_lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
          .select {|it| it[:from][:y] == it[:to][:y] }.sort_by {|it| -it[:from][:y] }
        (expect horizontal_lines).to have_size 4
        cell_bottom_padding = horizontal_lines[2][:from][:y] - horizontal_lines[3][:from][:y]
        (expect cell_bottom_padding.round 2).to eql 3.0
      end

      it 'should apply correct margin to last item with no description' do
        pdf = to_pdf <<~'END', analyze: true
        [cols=2*a]
        |===
        |
        term::

        []
        after regular

        |
        [horizontal]
        term::

        []
        after horizontal
        |===
        END

        term_texts = pdf.find_text 'term'
        (expect term_texts).to have_size 2
        (expect term_texts[0][:y]).to eql term_texts[1][:y]
        after_regular = pdf.find_unique_text 'after regular'
        after_horizontal = pdf.find_unique_text 'after horizontal'
        (expect after_horizontal[:y]).to eql after_regular[:y]
      end

      it 'should use prose margin around dlist nested in regular list' do
        pdf = to_pdf <<~'END', analyze: true
        [cols=2*a]
        |===
        |
        * list item
        +
        [horizontal]
        term:: desc

        * second list item

        |
        list item

        *term* desc

        second list item
        |===
        END

        ['list item', 'term', 'second list item'].each do |string|
          texts = pdf.find_text string
          (expect texts).to have_size 2
          (expect texts[0][:y].round 2).to eql (texts[1][:y].round 2)
        end
      end

      it 'should not truncate description of dlist item that spans more than one page' do
        (expect do
          pdf = to_pdf <<~END, sourcemap: true, attribute_overrides: { 'docfile' => 'test.adoc' }, analyze: true
          [horizontal]
          step 1::
          #{['* task'] * 50 * ?\n}
          END

          (expect pdf.pages.size).to eql 2
          (expect (pdf.find_unique_text 'step 1')).not_to be_nil
          (expect (pdf.find_text 'task').size).to eql 50
        end).not_to log_message
      end
    end

    context 'Unordered' do
      it 'should layout unordered description list like an unordered list with subject in bold' do
        pdf = to_pdf <<~'END', analyze: true
        [unordered]
        item a:: about item a
        +
        more about item a

        item b::
        about item b

        item c::
        +
        details about item c
        END

        (expect pdf.lines).to eql [
          '• item a: about item a',
          'more about item a',
          '• item b: about item b',
          '• item c:',
          'details about item c',
        ]
        item_a_subject_text = pdf.find_unique_text 'item a:'
        (expect item_a_subject_text).not_to be_nil
        (expect item_a_subject_text[:font_name]).to eql 'NotoSerif-Bold'
      end

      it 'should allow subject stop to be customized using subject-stop attribute' do
        pdf = to_pdf <<~'END', analyze: true
        [unordered,subject-stop=.]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        END

        (expect pdf.lines).to eql ['• item a. about item a', 'more about item a', '• item b. about item b']
      end

      it 'should not add subject stop if subject ends with stop punctuation' do
        pdf = to_pdf <<~'END', analyze: true
        [unordered,subject-stop=.]
        item a.:: about item a
        +
        more about item a

        _item b:_::
        about item b

        well?::
        yes
        END

        (expect pdf.lines).to eql ['• item a. about item a', 'more about item a', '• item b: about item b', '• well? yes']
      end

      it 'should add subject stop if subject ends with character reference' do
        pdf = to_pdf <<~'END', analyze: true
        [unordered]
        &:: ampersand
        >:: greater than
        END

        (expect pdf.lines).to eql ['• &: ampersand', '• >: greater than']
      end

      it 'should stack subject on top of text if stack role is present' do
        pdf = to_pdf <<~'END', analyze: true
        [unordered.stack]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        END

        (expect pdf.lines).to eql ['• item a', 'about item a', 'more about item a', '• item b', 'about item b']
      end

      it 'should support item with no desc' do
        pdf = to_pdf <<~'END', analyze: true
        [unordered]
        yin:: yang
        foo::
        END

        (expect pdf.find_text 'foo').not_to be_empty
        yin_text = pdf.find_unique_text 'yin:'
        foo_text = pdf.find_unique_text 'foo'
        (expect foo_text[:x]).to eql yin_text[:x]
      end
    end

    context 'Ordered' do
      it 'should layout ordered description list like an ordered list with subject in bold' do
        pdf = to_pdf <<~'END', analyze: true
        [ordered]
        item a:: about item a
        +
        more about item a

        item b::
        about item b

        item c::
        +
        details about item c
        END

        (expect pdf.lines).to eql [
          '1. item a: about item a',
          'more about item a',
          '2. item b: about item b',
          '3. item c:',
          'details about item c',
        ]
        item_a_subject_text = pdf.find_unique_text 'item a:'
        (expect item_a_subject_text).not_to be_nil
        (expect item_a_subject_text[:font_name]).to eql 'NotoSerif-Bold'
      end

      it 'should allow subject stop to be customized using subject-stop attribute' do
        pdf = to_pdf <<~'END', analyze: true
        [ordered,subject-stop=.]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        END

        (expect pdf.lines).to eql ['1. item a. about item a', 'more about item a', '2. item b. about item b']
      end

      it 'should not add subject stop if subject ends with stop punctuation' do
        pdf = to_pdf <<~'END', analyze: true
        [ordered,subject-stop=.]
        item a.:: about item a
        +
        more about item a

        _item b:_::
        about item b

        well?::
        yes
        END

        (expect pdf.lines).to eql ['1. item a. about item a', 'more about item a', '2. item b: about item b', '3. well? yes']
      end

      it 'should add subject stop if subject ends with character reference' do
        pdf = to_pdf <<~'END', analyze: true
        [ordered]
        &:: ampersand
        >:: greater than
        END

        (expect pdf.lines).to eql ['1. &: ampersand', '2. >: greater than']
      end

      it 'should stack subject on top of text if stack role is present' do
        pdf = to_pdf <<~'END', analyze: true
        [ordered.stack]
        item a:: about item a
        +
        more about item a

        item b::
        about item b
        END

        (expect pdf.lines).to eql ['1. item a', 'about item a', 'more about item a', '2. item b', 'about item b']
      end
    end
  end

  context 'Q & A' do
    it 'should convert qanda to ordered list' do
      pdf = to_pdf <<~'END', analyze: true
      [qanda]
      What is Asciidoctor?::
      An implementation of the AsciiDoc processor in Ruby.

      What is the answer to the Ultimate Question?::
      42
      END
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
      to_file = to_pdf_file <<~'END', 'list-qanda.pdf'
      [qanda]
      What's the answer to the ultimate question?:: 42

      Do you have an opinion?::
      Would you like to share it?::
      Yes and no.
      END

      (expect to_file).to visually_match 'list-qanda.pdf'
    end

    it 'should convert question with only block answer in Q & A list' do
      pdf = to_pdf <<~'END', analyze: true
      [qanda]
      Ultimate Question::
      +
      --
      How much time do you have?

      You must embark on a journey.

      Only at the end will you come to understand that the answer is 42.
      --
      END

      (expect pdf.lines).to eql ['1. Ultimate Question', 'How much time do you have?', 'You must embark on a journey.', 'Only at the end will you come to understand that the answer is 42.']
      unanswerable_q_text = pdf.find_unique_text 'Ultimate Question'
      (expect unanswerable_q_text[:font_name]).to eql 'NotoSerif-Italic'
      text = pdf.text
      (expect text[0][:y] - text[1][:y]).to eql 0.0
      (expect text[1][:y] - text[2][:y]).to be < (text[2][:y] - text[3][:y])
      (expect text[2][:y] - text[3][:y]).to eql (text[3][:y] - text[4][:y])
    end

    it 'should convert question with no answer in Q & A list' do
      pdf = to_pdf <<~'END', analyze: true
      [qanda]
      Question:: Answer
      Unanswerable Question::
      END

      unanswerable_q_text = pdf.find_unique_text 'Unanswerable Question'
      (expect pdf.lines).to eql ['1. Question', 'Answer', '2. Unanswerable Question']
      (expect unanswerable_q_text[:font_name]).to eql 'NotoSerif-Italic'
    end
  end

  context 'Callout' do
    it 'should use callout numbers as list markers and in referenced block' do
      pdf = to_pdf <<~'END', analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      END

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
      pdf = to_pdf <<~'END', analyze: true
      ....
      line one <1>
      line two <2>
      line three <3>
      ....
      <1> describe one
      <2> `describe two`
      <3> describe three
      END

      mark_texts = [(pdf.find_text ?\u2460)[-1], (pdf.find_text ?\u2461)[-1], (pdf.find_text ?\u2462)[-1]]
      (expect mark_texts).to have_size 3
      first_to_second_spacing = (mark_texts[0][:y] - mark_texts[1][:y]).round 2
      second_to_third_spacing = (mark_texts[1][:y] - mark_texts[2][:y]).round 2
      (expect first_to_second_spacing).to eql second_to_third_spacing
    end

    it 'should only separate colist and listing or literal block by list_item_spacing value' do
      %w(---- ....).each do |block_delim|
        input = <<~END
        #{block_delim}
        line one <1>
        line two
        line three <2>
        #{block_delim}
        <1> First line
        <2> Last line
        END

        pdf = to_pdf input, analyze: :line
        bottom_line_y = pdf.lines[2][:from][:y]

        pdf = to_pdf input, analyze: true
        colist_num_text = (pdf.find_text ?\u2460)[-1]
        colist_num_top_y = colist_num_text[:y] + colist_num_text[:font_size]

        gap = bottom_line_y - colist_num_top_y
        # NOTE: default outline list spacing is 6
        (expect gap).to be > 6
        (expect gap).to be < 8
      end
    end

    it 'should allow theme to control top margin of callout lists that immediately follows a code block', visual: true do
      input = <<~'END'
      ----
      line one <1>
      line two
      line three <2>
      ----
      <1> First line
      <2> Last line
      END

      pdf_theme = { callout_list_margin_top_after_code: 0 }

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      bottom_line_y = pdf.lines[2][:from][:y]

      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      colist_num_text = (pdf.find_text ?\u2460)[-1]
      colist_num_top_y = colist_num_text[:y] + colist_num_text[:font_size]

      gap = bottom_line_y - colist_num_top_y
      (expect gap).to be > 12
      (expect gap).to be < 14
    end

    it 'should not apply top margin if callout list does not follow literal or listing block' do
      pdf_theme = {
        sidebar_border_radius: 0,
        sidebar_border_width: 1,
        sidebar_border_color: '0000EE',
        sidebar_background_color: 'transparent',
      }

      ref_input = <<~'END'
      ****
      . describe first line
      ****
      END

      ref_top_line_y = (to_pdf ref_input, pdf_theme: pdf_theme, analyze: :line).lines.map {|it| it[:from][:y] }.max
      ref_text_top = (to_pdf ref_input, pdf_theme: pdf_theme, analyze: true).text[0].yield_self {|it| it[:y] + it[:font_size] }
      expected_top_padding = ref_top_line_y - ref_text_top

      input = <<~'END'
      ----
      line 1 <1>
      line 2 <2>
      ----

      ****
      <1> describe first line
      <2> describe second line

      ----
      code
      ----
      ****
      END

      lines = (to_pdf input, pdf_theme: pdf_theme, analyze: :line).lines
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      sidebar_lines = lines.select {|it| it[:color] == '0000EE' && it[:width] == 1 }
      top_line_y = sidebar_lines.map {|it| it[:from][:y] }.max
      text_top = (pdf.find_text %r/describe /)[0].yield_self {|it| it[:y] + it[:font_size] }
      top_padding = top_line_y - text_top
      (expect top_padding).to eql expected_top_padding
    end

    it 'should allow theme to control font properties and item spacing of callout list' do
      pdf_theme = {
        callout_list_font_size: 9,
        callout_list_font_color: '555555',
        callout_list_item_spacing: 3,
        callout_list_marker_font_color: '0000FF',
        conum_font_size: nil,
      }

      pdf = to_pdf <<~'END', pdf_theme: pdf_theme, analyze: true
      ----
      site:
        url: https://docs.example.org # <1>
        robots: allow # <2>
      ----
      <1> The base URL where the site is published.
      <2> Allow search engines to crawl the site.
      END

      conum_1_text = pdf.find_text ?\u2460
      (expect conum_1_text).to have_size 2
      (expect conum_1_text[0][:font_size]).to eql 11
      (expect conum_1_text[0][:font_color]).to eql 'B12146'
      (expect conum_1_text[1][:font_size]).to eql 9
      (expect conum_1_text[1][:font_color]).to eql '0000FF'
      colist_1_text = pdf.find_unique_text %r/^The base URL/
      (expect colist_1_text[:font_size]).to eql 9
      (expect colist_1_text[:font_color]).to eql '555555'
      colist_2_text = pdf.find_unique_text %r/^Allow search engines/
      (expect colist_2_text[:font_size]).to eql 9
      (expect colist_2_text[:font_color]).to eql '555555'
      (expect colist_1_text[:y] - colist_2_text[:y]).to (be_within 1).of 16
    end

    it 'should not move cursor if callout list appears at top of page' do
      pdf = to_pdf <<~END, analyze: true
      key-value pair

      ----
      key: val # <1>
      items:
      #{(['- item'] * 46).join ?\n}
      ----
      <1> key-value pair
      END

      key_val_texts = pdf.find_text 'key-value pair'
      (expect key_val_texts).to have_size 2
      (expect key_val_texts[0][:page_number]).to be 1
      (expect key_val_texts[1][:page_number]).to be 2
      (expect key_val_texts[0][:y]).to eql key_val_texts[1][:y]
    end

    it 'should not collapse top margin if previous block is not a verbatim block' do
      pdf = to_pdf <<~'END', analyze: true
      before

      ----
      key: val
      ----

      '''

      key-value pair
      END

      reference_y = (pdf.find_unique_text 'key-value pair')[:y]

      pdf = to_pdf <<~'END', analyze: true
      before

      ----
      key: val # <1>
      ----

      '''

      <1> key-value pair
      END

      actual_y = (pdf.find_unique_text 'key-value pair')[:y]
      (expect actual_y).to eql reference_y
    end

    it 'should allow conum font color to be customized by theme' do
      pdf = to_pdf <<~'END', pdf_theme: { conum_font_color: '0000ff' }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      END

      one_text = pdf.find_text ?\u2460
      (expect one_text).to have_size 2
      one_text.each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql '0000FF'
      end
    end

    it 'should allow conum font size and line height in colist to be customized by theme' do
      pdf = to_pdf <<~'END', pdf_theme: { conum_font_size: 8, conum_line_height: 1.8 }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      END

      one_text = pdf.find_text ?\u2460
      (expect one_text).to have_size 2
      (expect one_text[0][:font_size]).to eql 11
      (expect one_text[0][:y]).to eql (pdf.find_unique_text %r/^line one/)[:y]
      (expect one_text[1][:font_size]).to eql 8
      (expect one_text[1][:y]).to be > (pdf.find_unique_text %r/First line/)[:y]
      (expect one_text[1][:y]).to (be_within 1.5).of (pdf.find_unique_text %r/First line/)[:y]
    end

    it 'should support filled conum glyphs if specified in theme' do
      pdf = to_pdf <<~'END', pdf_theme: { conum_glyphs: 'filled' }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      END

      one_text = pdf.find_text ?\u2776
      two_text = pdf.find_text ?\u2777
      (expect one_text).to have_size 2
      (expect two_text).to have_size 2
      (one_text + two_text).each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql 'B12146'
      end
    end

    it 'should allow conum glyphs to be specified explicitly using numeric range' do
      pdf = to_pdf <<~'END', pdf_theme: { conum_glyphs: '1-20' }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      END

      one_text = pdf.find_text '1'
      (expect one_text).to have_size 2
    end

    it 'should allow conum glyphs to be specified explicitly using unicode range' do
      pdf = to_pdf <<~'END', pdf_theme: { conum_glyphs: '\u0031-\u0039' }, analyze: true
      ....
      line one <1>
      line two
      line three <2>
      ....
      <1> First line
      <2> Last line
      END

      one_text = pdf.find_text '1'
      (expect one_text).to have_size 2
      one_text.each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql 'B12146'
      end
    end

    it 'should allow conum glyphs to be specified explicitly using multiple unicode ranges' do
      pdf = to_pdf <<~'END', pdf_theme: { conum_glyphs: '\u2776-\u277a, \u2465-\u2468' }, analyze: true
      ----
      1 <1>
      2 <2>
      3 <3>
      4 <4>
      5 <5>
      6 <6>
      7 <7>
      8 <8>
      9 <9>
      ----
      <1> 1
      <2> 2
      <3> 3
      <4> 4
      <5> 5
      <6> 6
      <7> 7
      <8> 8
      <9> 9
      END

      conum_lines = pdf.lines.map {|l| l.delete ' 1-9' }
      (expect conum_lines).to have_size 18
      (expect conum_lines).to eql [?\u2776, ?\u2777, ?\u2778, ?\u2779, ?\u277a, ?\u2465, ?\u2466, ?\u2467, ?\u2468] * 2
    end

    it 'should allow conum glyphs to be specified as single unicode character' do
      pdf = to_pdf <<~'END', pdf_theme: { conum_glyphs: '\u2776' }, analyze: true
      ....
      the one and only line <1>
      no conum here <2>
      ....
      <1> That's all we have time for
      <2> This conum is not supported
      END

      one_text = pdf.find_text ?\u2776
      (expect one_text).to have_size 2
      one_text.each do |text|
        (expect text[:font_name]).to eql 'mplus1mn-regular'
        (expect text[:font_color]).to eql 'B12146'
      end

      lines_without_conum = pdf.lines.reject {|l| l.include? ?\u2776 }
      (expect lines_without_conum).to eql ['no conum here', 'This conum is not supported']
    end

    it 'should keep list marker with primary text' do
      pdf = to_pdf <<~END, analyze: true
      :pdf-page-size: 52mm x 72.25mm
      :pdf-page-margin: 0

      ....
      filler <1>
      #{['filler'] * 10 * ?\n}
      ....

      <1> description
      END

      marker_text = (pdf.find_text ?\u2460)[-1]
      (expect marker_text[:page_number]).to be 2
      item_text = pdf.find_unique_text 'description'
      (expect item_text[:page_number]).to be 2
    end

    it 'should allow text alignment to be set using role', visual: true do
      to_file = to_pdf_file <<~END, 'colist-text-align-left-role.pdf'
      ----
      data <1>
      ----
      [.text-left]
      <1> #{lorem_ipsum '2-sentences-1-paragraph'}
      END
      (expect to_file).to visually_match 'colist-text-align-left.pdf'
    end

    it 'should allow text alignment to be set using theme', visual: true do
      to_file = to_pdf_file <<~END, 'colist-text-align-left-theme.pdf', pdf_theme: { list_text_align: 'left' }
      ----
      data <1>
      ----
      <1> #{lorem_ipsum '2-sentences-1-paragraph'}
      END
      (expect to_file).to visually_match 'colist-text-align-left.pdf'
    end
  end

  context 'Bibliography' do
    it 'should reference bibliography entry using ID in square brackets by default' do
      pdf = to_pdf <<~'END', analyze: true
      The recommended reading includes <<bar>>.

      [bibliography]
      == Bibliography

      * [[[bar]]] Bar, Foo. All The Things. 2010.
      END

      lines = pdf.lines

      (expect lines).to include 'The recommended reading includes [bar].'
      (expect lines).to include '▪ [bar] Bar, Foo. All The Things. 2010.'
    end

    it 'should reference bibliography entry using custom reftext square brackets' do
      pdf = to_pdf <<~'END', analyze: true
      The recommended reading includes <<bar>>.

      [bibliography]
      == Bibliography

      * [[[bar,1]]] Bar, Foo. All The Things. 2010.
      END

      lines = pdf.lines
      (expect lines).to include 'The recommended reading includes [1].'
      (expect lines).to include '▪ [1] Bar, Foo. All The Things. 2010.'
    end

    it 'should create bidirectional links between first bibref reference and entry' do
      pdf = to_pdf <<~'END'
      The recommended reading includes <<bar>>.

      Did you read <<bar>>?

      <<<

      [bibliography]
      == Bibliography

      * [[[bar]]] Bar, Foo. All The Things. 2010.
      * [[[baz]]] Baz. The Rest of the Story. 2020.
      END

      forward_refs = get_annotations pdf, 1
      (expect forward_refs).to have_size 2
      (expect forward_refs.map {|it| it[:Dest] }.uniq).to eql %w(bar)
      ids = (get_names pdf).keys
      (expect ids).to include '_bibref_ref_bar'
      (expect ids).to include 'bar'
      (expect ids).to include 'baz'
      back_refs = get_annotations pdf, 2
      (expect back_refs).to have_size 1
      (expect back_refs[0][:Dest]).to eql '_bibref_ref_bar'
    end
  end
end
