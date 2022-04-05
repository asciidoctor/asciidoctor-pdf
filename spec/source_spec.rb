# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Source' do
  context 'Rouge' do
    it 'should use plain text lexer if language is not recognized' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,foobar]
      ----
      puts "Hello, World!"
      ----
      EOS

      puts_text = (pdf.find_text 'puts')[0]
      (expect puts_text).to be_nil
      (expect pdf.text).to have_size 1
      (expect pdf.text[0][:font_color]).to eql '333333'
    end

    it 'should expand tabs to preserve indentation' do
      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: rouge

      [source,c]
      ----
      int main() {
      \tevent_loop();
      \treturn 0;
      }
      ----
      EOS
      lines = pdf.lines
      (expect lines).to have_size 4
      (expect lines[1]).to eql %(\u00a0   event_loop();)
      (expect lines[2]).to eql %(\u00a0   return 0;)
    end

    it 'should expand tabs used for column alignment' do
      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: rouge

      [source,sql]
      ----
      SELECT
      \tname,\t firstname,\t\tlastname
      FROM
      \tusers
      WHERE
      \tusername\t=\t'foobar'
      ----
      EOS
      lines = pdf.lines
      (expect lines).to have_size 6
      (expect lines).to include %(\u00a0   name,    firstname,     lastname)
      (expect lines).to include %(\u00a0   username    =   'foobar')
    end

    it 'should enable start_inline option for PHP by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,php]
      ----
      echo "<?php";
      ----
      EOS

      echo_text = (pdf.find_text 'echo')[0]
      (expect echo_text).not_to be_nil
      # NOTE: the echo keyword should be highlighted
      (expect echo_text[:font_color]).to eql '008800'
    end

    it 'should not enable the start_inline option for PHP if the mixed option is set' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source%mixed,php]
      ----
      echo "<?php";
      ----
      EOS

      echo_text = (pdf.find_text 'echo')[0]
      # NOTE: the echo keyword should not be highlighted
      (expect echo_text).to be_nil
    end

    it 'should preserve cgi-style options when setting start_inline option for PHP' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,php?funcnamehighlighting=1]
      ----
      cal_days_in_month(CAL_GREGORIAN, 6, 2019)
      ----

      [source,php?funcnamehighlighting=0]
      ----
      cal_days_in_month(CAL_GREGORIAN, 6, 2019)
      ----
      EOS

      if (Gem::Version.new Rouge.version) >= (Gem::Version.new '2.1.0')
        ref_funcname_text = (pdf.find_text 'cal_days_in_month')[0]
        (expect ref_funcname_text).not_to be_nil
        ref_year_text = (pdf.find_text '2019')[0]
        (expect ref_year_text).not_to be_nil

        funcname_text = (pdf.find_text 'cal_days_in_month')[1]
        (expect funcname_text).not_to be_nil
        year_text = (pdf.find_text '2019')[1]
        (expect year_text).not_to be_nil

        (expect funcname_text[:font_color]).not_to eql ref_funcname_text[:font_color]
        (expect funcname_text[:font_name]).not_to eql ref_funcname_text[:font_name]
        (expect year_text[:font_color]).to eql ref_year_text[:font_color]
        (expect year_text[:font_name]).to eql ref_year_text[:font_name]
      else
        text = pdf.text
        (expect text).to have_size 2
        (expect text[0][:string]).to eql 'cal_days_in_month(CAL_GREGORIAN, 6, 2019)'
        (expect text[0][:font_color]).to eql '333333'
        (expect text[1][:string]).to eql 'cal_days_in_month(CAL_GREGORIAN, 6, 2019)'
        (expect text[1][:font_color]).to eql '333333'
      end
    end

    it 'should enable start_inline option for PHP if enabled by cgi-style option' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,php?start_inline=1]
      ----
      echo "<?php";
      ----
      EOS

      if (Gem::Version.new Rouge.version) >= (Gem::Version.new '2.1.0')
        echo_text = pdf.find_unique_text 'echo'
        (expect echo_text).not_to be_nil
        # NOTE: the echo keyword should be highlighted
        (expect echo_text[:font_color]).to eql '008800'
      end
    end

    it 'should not enable the start_inline option for PHP if the mixed option is set and other cgi-style options specified' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source%mixed,php?foo=bar]
      ----
      echo "<?php";
      ----
      EOS

      echo_text = pdf.find_unique_text 'echo'
      # NOTE: the echo keyword should not be highlighted
      (expect echo_text).to be_nil
    end

    it 'should not enable start_inline option for PHP if disabled by cgi-style option' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,php?start_inline=0]
      ----
      cal_days_in_month(CAL_GREGORIAN, 6, 2019)
      ----
      EOS

      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'cal_days_in_month(CAL_GREGORIAN, 6, 2019)'
      (expect text[0][:font_color]).to eql '333333'
    end

    it 'should respect cgi-style options for languages other than PHP' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,console?prompt=%]
      ----
      % bundle
      ----
      EOS

      if (Gem::Version.new Rouge.version) >= (Gem::Version.new '2.1.0')
        prompt_text = pdf.find_unique_text '%'
        (expect prompt_text).not_to be_nil
        (expect prompt_text[:font_color]).to eql '555555'
      end
    end

    it 'should use plain text lexer if language is not recognized and cgi-style options are present' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,foobar?start_inline=1]
      ----
      puts "Hello, World!"
      ----
      EOS

      puts_text = (pdf.find_text 'puts')[0]
      (expect puts_text).to be_nil
      (expect pdf.text).to have_size 1
      (expect pdf.text[0][:font_color]).to eql '333333'
    end

    it 'should use rouge style specified by rouge-style attribute', visual: true do
      input = <<~'EOS'
      :source-highlighter: rouge
      :rouge-style: molokai

      [source,js]
      ----
      'use strict'

      const TAG_ALL_RX = /<[^>]+>/g
      module.exports = (html) => html && html.replace(TAG_ALL_RX, '')
      ----
      EOS

      to_file = to_pdf_file input, 'source-rouge-style.pdf'
      (expect to_file).to visually_match 'source-rouge-style.pdf'

      to_file = to_pdf_file input, 'source-rouge-style.pdf', attribute_overrides: { 'rouge-style' => (Rouge::Theme.find 'molokai').new }
      (expect to_file).to visually_match 'source-rouge-style.pdf'

      to_file = to_pdf_file input, 'source-rouge-style.pdf', attribute_overrides: { 'rouge-style' => (Rouge::Theme.find 'molokai') }
      (expect to_file).to visually_match 'source-rouge-style.pdf'
    end

    it 'should disable highlighting instead of crashing if lexer fails to lex source' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        :source-highlighter: rouge

        [source,console]
        ----
        $ cd application-name\bin\
        ----
        EOS

        source_lines = pdf.lines pdf.text {|it| it.font_name.start_with? 'mplus1mn-' }
        (expect source_lines).not_to be_empty
        (expect source_lines[0]).to start_with '$ cd'
      end).not_to raise_exception
    end

    it 'should not crash if source-highlighter attribute is defined outside of document header' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        = Document Title

        :source-highlighter: rouge

        [source,ruby]
        ----
        puts 'yo, world!'
        ----
        EOS

        source_text = pdf.find_unique_text font_name: 'mplus1mn-regular'
        (expect source_text).not_to be_nil
        (expect source_text[:string]).to start_with 'puts '
      end).not_to raise_exception
    end

    it 'should apply bw style if specified' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge
      :rouge-style: bw

      [source,ruby]
      ----
      class Beer
        attr_reader :style
      end
      ----
      EOS

      beer_text = (pdf.find_text 'Beer')[0]
      (expect beer_text).not_to be_nil
      (expect beer_text[:font_name]).to eql 'mplus1mn-bold'
      if (Gem::Version.new Rouge.version) >= (Gem::Version.new '3.4.0')
        (expect beer_text[:font_color]).to eql '333333'
      else
        (expect beer_text[:font_color]).to eql 'BB0066'
      end
    end

    it 'should allow token to be formatted in bold and italic' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge
      :rouge-style: github

      [source,d]
      ----
      int #line 6 "pkg/mod.d"
      x; // this is now line 6 of file pkg/mod.d
      ----
      EOS

      line_text = pdf.find_unique_text %r/^#line 6 /
      (expect line_text).not_to be_empty
      (expect line_text[:font_name]).to eql 'mplus1mn-bold_italic'
    end

    it 'should allow token to add underline style to token', visual: true do
      input = <<~'EOS'
      :source-highlighter: rouge

      [source,ruby]
      ----
      class Beer
        attr_reader :style

        def drink
          puts 'aaaaaaaaah'
        end
      end
      ----
      EOS

      # NOTE: convert to load Rouge
      to_pdf input

      rouge_style = Class.new Rouge::Theme.find 'molokai' do
        style Rouge::Token::Tokens::Name::Class, fg: :green, bold: true, underline: true
        style Rouge::Token::Tokens::Name::Function, fg: :green, underline: true
      end

      to_file = to_pdf_file input, 'source-rouge-underline-style.pdf', attribute_overrides: { 'rouge-style' => rouge_style }

      (expect to_file).to visually_match 'source-rouge-underline-style.pdf' if (Gem::Version.new Rouge.version) >= (Gem::Version.new '2.1.0')
    end

    it 'should allow token to extend to width of block', visual: true do
      input = <<~'EOS'
      :source-highlighter: rouge
      :rouge-style: github

      [source,ruby]
      ----
      puts 'string'
      ----
      EOS

      # NOTE: convert to load Rouge
      to_pdf input

      rouge_style = Class.new Rouge::Theme.find 'github' do
        style Rouge::Token::Tokens::Literal::String::Single, fg: '#333333', bg: '#ff4dcd', extend: true, inline_block: true
      end

      pdf = to_pdf input, attribute_overrides: { 'rouge-style' => rouge_style }, analyze: :rect
      rects = pdf.rectangles
      (expect rects).to have_size 1
      (expect rects[0][:width]).to be > 44
      (expect rects[0][:height]).to be > 11
    end

    it 'should not crash if theme does not define style for Text token' do
      input = <<~'EOS'
      :source-highlighter: rouge

      [source,ruby]
      ----
      puts "Hello, World!"
      ----
      EOS

      # NOTE: convert to load Rouge
      to_pdf input

      rouge_style = Class.new Rouge::CSSTheme do
        name 'foobar'
        style Rouge::Token::Tokens::Literal::String, italic: true
      end

      pdf = to_pdf input, attribute_overrides: { 'rouge-style' => rouge_style }, analyze: true
      hello_world_text = pdf.find_unique_text '"Hello, World!"'
      (expect hello_world_text[:font_name]).to eql 'mplus1mn-italic'
    end

    it 'should expand color value for token' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge
      :rouge-style: colorful

      [source,ruby]
      ----
      class Type; end
      ----
      EOS

      pdf.text.each do |text|
        (expect text[:font_color].length).to be 6
        (expect text[:font_color].upcase).to eql text[:font_color]
      end

      classname_text = pdf.find_unique_text 'Type'
      (expect ((Rouge::Theme.find 'colorful').new.style_for Rouge::Token::Tokens::Name::Class)[:fg]).to eql '#B06'
      (expect classname_text[:font_color]).to eql 'BB0066'
    end

    it 'should draw background color around token', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-bg.pdf'
      :source-highlighter: rouge
      :rouge-style: pastie

      [source,ruby]
      ----
      type, name = ARGV
      case type
      when :hello
        puts %(Hello, #{name}!)
      when :goodbye
        puts 'See ya, ' + name + '!'
      end
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-bg.pdf' if (Gem::Version.new Rouge.version) >= (Gem::Version.new '2.1.0')
    end

    it 'should draw background color across whole line for line-oriented tokens', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-bg-line.pdf'
      :source-highlighter: rouge

      [source,diff]
      ----
      --- /tmp/list1.txt
      +++ /tmp/list2.txt
      @@ -1,4 +1,4 @@
       apples
      -oranges
       kiwis
       carrots
      +grapefruits
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-bg-line.pdf' if (Gem::Version.new Rouge.version) >= (Gem::Version.new '2.1.0')
    end

    it 'should not draw background color across whole line for line-oriented tokens if disabled in theme' do
      input = <<~'EOS'
      :source-highlighter: rouge

      [source,diff]
      ----
      -oranges
      +grapefruits
      ----
      EOS

      # NOTE: convert to load Rouge
      to_pdf input

      rouge_style = Class.new Rouge::Theme.find 'asciidoctor_pdf_default' do
        style Rouge::Token::Tokens::Generic::Deleted, fg: '#000000', bg: '#ffdddd', extend: false, inline_block: false
        style Rouge::Token::Tokens::Generic::Inserted, fg: '#000000', bg: '#ddffdd', extend: false, inline_block: false
      end

      pdf = to_pdf input, attribute_overrides: { 'rouge-style' => rouge_style }, analyze: :rect
      rects = pdf.rectangles
      (expect rects).to have_size 2
      (expect rects[0][:width]).to be < 100
      # FIXME: the first token ends in a newline, so it gets coerced to an inline block
      (expect rects[0][:height]).to eql 14.8
      (expect rects[1][:height]).to be < 14.8
    end

    it 'should fall back to default line gap if line gap is not specified in theme', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-bg-line-no-gap.pdf', pdf_theme: { code_line_gap: nil }
      :source-highlighter: rouge

      [source,diff]
      ----
      --- /tmp/list1.txt
      +++ /tmp/list2.txt
      @@ -1,4 +1,4 @@
       apples
      -oranges
       kiwis
       carrots
      +grapefruits
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-bg-line-no-gap.pdf' if (Gem::Version.new Rouge.version) >= (Gem::Version.new '2.1.0')
    end

    it 'should add line numbers to start of line if linenums option is enabled' do
      expected_lines = <<~'EOS'.split ?\n
       1 <?xml version="1.0" encoding="UTF-8"?>
       2 <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
       3   <url>
       4     <loc>https://example.org/home.html</loc>
       5     <lastmod>2019-01-01T00:00:00.000Z</lastmod>
       6   </url>
       7   <url>
       8     <loc>https://example.org/about.html</loc>
       9     <lastmod>2019-01-01T00:00:00.000Z</lastmod>
      10   </url>
      11 </urlset>
      EOS

      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,xml,linenums]
      ----
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url>
          <loc>https://example.org/home.html</loc>
          <lastmod>2019-01-01T00:00:00.000Z</lastmod>
        </url>
        <url>
          <loc>https://example.org/about.html</loc>
          <lastmod>2019-01-01T00:00:00.000Z</lastmod>
        </url>
      </urlset>
      ----
      EOS

      (expect pdf.lines).to eql expected_lines
      linenum_text = (pdf.find_text %r/^11 *$/)[0]
      (expect linenum_text[:font_color]).to eql '888888'
    end

    it 'should continue to add line numbers after page split' do
      source_lines = (1..55).map {|it| %(puts "Please come forward if your number is #{it}.") }

      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: rouge

      [source%linenums,ruby]
      ----
      #{source_lines.join ?\n}
      ----
      EOS

      lines_after_split = pdf.lines pdf.find_text page_number: 2
      (expect lines_after_split).not_to be_empty
      (expect lines_after_split[0]).to eql '51 puts "Please come forward if your number is 51."'
    end

    it 'should honor start value for line numbering' do
      expected_lines = <<~'EOS'.split ?\n
      5 puts 'Hello, World!'
      EOS

      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,xml,linenums,start=5]
      ----
      puts 'Hello, World!'
      ----
      EOS

      (expect pdf.lines).to eql expected_lines
    end

    it 'should coerce start value for line numbering to 1 if less than 1' do
      expected_lines = <<~'EOS'.split ?\n
      1 puts 'Hello, World!'
      EOS

      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,xml,linenums,start=0]
      ----
      puts 'Hello, World!'
      ----
      EOS

      (expect pdf.lines).to eql expected_lines
    end

    it 'should not add line number to first line if source is empty' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source%linenums]
      ----
      ----
      EOS

      (expect pdf.text).to be_empty
    end

    it 'should not emit error if linenums are enabled and language is not set' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        :source-highlighter: rouge

        [source%linenums]
        ----
        fee
        fi
        fo
        fum
        ----
        EOS

        (expect pdf.lines).to eql ['1 fee', '2 fi', '3 fo', '4 fum']
      end).to not_log_message
    end

    it 'should preserve orphan callout on last line' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,yaml]
      ----
      foo: 'bar'
      key: 'value'
      <1>
      ----
      <1> End the file with a trailing newline
      EOS

      conum_texts = pdf.find_text '①'
      (expect conum_texts).to have_size 2
    end

    it 'should use font color from style' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge
      :rouge-style: monokai

      [source,text]
      ----
      foo
      bar
      baz
      ----
      EOS

      pdf.text.each do |text|
        (expect text[:font_color]).to eql 'F8F8F2'
      end
    end

    it 'should highlight lines specified by highlight attribute on block', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-line-highlighting.pdf'
      :source-highlighter: rouge

      [source,c,highlight=4;7-8]
      ----
      /**
       * A program that prints "Hello, World!"
       **/
      #include <stdio.h>

      int main(void) {
        printf("Hello, World!\n");
        return 0;
      }
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-line-highlighting.pdf'
    end

    it 'should highlight lines specified by highlight attribute on block when linenums are enabled', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-line-highlighting-with-linenums.pdf'
      :source-highlighter: rouge

      [source,c,linenums,highlight=4;7-8]
      ----
      /**
       * A program that prints "Hello, World!"
       **/
      #include <stdio.h>

      int main(void) {
        printf("Hello, World!\n");
        return 0;
      }
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-line-highlighting-with-linenums.pdf'
    end

    it 'should interpret highlight lines relative to start value', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-line-highlighting-with-linenums-start.pdf'
      :source-highlighter: rouge

      [source,c,linenums,start=4,highlight=4;7-8]
      ----
      #include <stdio.h>

      int main(void) {
        printf("Hello, World!\n");
        return 0;
      }
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-line-highlighting-with-linenums-start.pdf'
    end

    it 'should preserve indentation when highlighting lines without linenums enabled', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-line-highlighting-indent.pdf'
      :source-highlighter: rouge

      [source,groovy,highlight=4-5]
      ----
      ratpack {
          handlers {
              get {
                  render '''|Hello,
                            |World!'''.stripMargin()
              }
          }
      }
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-line-highlighting-indent.pdf'
    end

    it 'should ignore highlight attribute if empty' do
      pdf = to_pdf <<~'EOS', analyze: :rect
      :source-highlighter: rouge

      [source,ruby,linenums,highlight=]
      ----
      puts "Hello, World!"
      ----
      EOS

      (expect pdf.rectangles).to be_empty
    end

    it 'should preserve indentation of highlighted line' do
      input = <<~'EOS'
      :source-highlighter: rouge

      [source,text,highlight=1]
      ----
        indented line
      ----
      EOS

      pdf = to_pdf input, analyze: true
      (expect pdf.lines).to eql [%(\u00a0 indented line)]
      pdf = to_pdf input, analyze: :rect
      (expect pdf.rectangles).to have_size 1
    end

    it 'should highlight lines using custom color specified in theme', visual: true do
      pdf_theme = { code_highlight_background_color: 'FFFF00' }
      to_file = to_pdf_file <<~'EOS', 'source-rouge-highlight-background-color.pdf', pdf_theme: pdf_theme
      :source-highlighter: rouge

      [source,c,highlight=4]
      ----
      /**
       * A program that prints "Hello, World!"
       **/
      #include <stdio.h>

      int main(void) {
        printf("Hello, World!\n");
        return 0;
      }
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-highlight-background-color.pdf'
    end

    it 'should indent wrapped line if line numbers are enabled' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,text,linenums]
      ----
      Here we go again here we go again here we go again here we go again here we go again Here we go again
      ----
      EOS

      linenum_text = (pdf.find_text '1 ')[0]
      (expect linenum_text[:x]).not_to be_nil
      start_texts = pdf.find_text %r/^Here we go again/
      (expect start_texts).to have_size 2
      (expect start_texts[0][:x]).to eql start_texts[1][:x]
      (expect start_texts[0][:x]).to be > linenum_text[:x]
      indent_texts = pdf.find_text %r/\u00a0/
      (expect indent_texts).to have_size 1
      (expect indent_texts[0][:x]).to eql linenum_text[:x]
      (expect indent_texts[0][:string]).to eql %(\u00a0 )
    end

    it 'should indent wrapped line if line numbers are enabled and block has an AFM font' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge
      :pdf-theme: base

      [,text,linenums]
      ----
      Here we go again here we go again here we go again here we go again here we go again Here we go again
      ----
      EOS

      linenum_text = (pdf.find_text '1 ')[0]
      (expect linenum_text[:x]).not_to be_nil
      start_texts = pdf.find_text %r/Here we go/
      (expect start_texts).to have_size 2
      (expect start_texts[0][:x]).to eql start_texts[1][:x]
      (expect start_texts[0][:x]).to be > linenum_text[:x]
      indent_texts = pdf.find_text %r/\u00a0/
      (expect indent_texts).to have_size 1
      (expect indent_texts[0][:x]).to eql linenum_text[:x]
      (expect indent_texts[0][:string]).to eql %(\u00a0 )
    end

    it 'should highlight and indent wrapped line', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-highlight-wrapped-line.pdf'
      :source-highlighter: rouge

      [source,xml,linenums,highlight=1;3]
      ----
      <project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
        <modelVersion>4.0.0</modelVersion>
      </project>
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-highlight-wrapped-line.pdf'
    end

    it 'should not apply syntax highlighting or borders and backgrounds in scratch document' do
      scratch_pdf = nil
      postprocessor_impl = proc do
        process do |doc, output|
          scratch_pdf = doc.converter.scratch
          output
        end
      end

      opts = { extension_registry: Asciidoctor::Extensions.create { postprocessor(&postprocessor_impl) } }
      main_pdf = to_pdf <<~'EOS', (opts.merge analyze: true)
      :source-highlighter: rouge

      filler

      [%unbreakable]
      --
      [source,ruby]
      ----
      puts "Hello, World!"
      ----
      --
      EOS

      main_pdf_text = main_pdf.text.reject {|it| it[:string] == 'filler' }
      (expect main_pdf_text[0][:string]).to eql 'puts'
      (expect main_pdf_text[0][:font_color]).not_to eql '333333'
      scratch_pdf_output = scratch_pdf.render
      scratch_pdf_text = (EnhancedPDFTextInspector.analyze scratch_pdf_output).text
      (expect scratch_pdf_text[0][:string]).to eql 'puts "Hello, World!"'
      (expect scratch_pdf_text[0][:font_color]).to eql '333333'
      scratch_pdf_lines = (LineInspector.analyze scratch_pdf_output).lines
      (expect scratch_pdf_lines).to be_empty
    end

    it 'should not leak patch for linenums if unbreakable block is split across pages' do
      formatted_text_box_extensions_count = nil
      extensions = proc do
        postprocessor do
          process do |_, output|
            formatted_text_box_extensions_count = Prawn::Text::Formatted::Box.extensions.size
            output
          end
        end
      end
      source_file = fixture_file 'TicTacToeGame.java'
      pdf = to_pdf <<~EOS, extensions: extensions, enable_footer: true, analyze: true
      :source-highlighter: rouge

      before block

      [%linenums%autofit%unbreakable,java]
      ----
      include::#{source_file}[]
      ----
      EOS
      (expect (pdf.find_unique_text 'before block')[:page_number]).to be 1
      (expect (pdf.find_unique_text 'package')[:page_number]).to be 1
      (expect (pdf.find_unique_text 'package')[:font_color]).not_to be '333333'
      (expect (pdf.find_unique_text %r/^\s*70\s*$/)[:page_number]).to be 2
      (expect formatted_text_box_extensions_count).to be 0
    end
  end

  context 'CodeRay' do
    it 'should highlight source using CodeRay if source-highlighter is coderay' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: coderay

      [source,ruby]
      ----
      puts 'Hello, CodeRay!'
      ----
      EOS

      hello_text = (pdf.find_text 'Hello, CodeRay!')[0]
      (expect hello_text).not_to be_nil
      (expect hello_text[:font_color]).to eql 'CC3300'
      (expect hello_text[:font_name]).to eql 'mplus1mn-regular'
    end

    it 'should not crash if token text is nil' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        :source-highlighter: coderay

        [source,sass]
        ----
        $icon-font-path: "node_modules/package-name/icon-fonts/";

        body {
          background: #fafafa;
        }
        ----
        EOS

        closing_bracket_text = pdf.find_unique_text '}'
        (expect closing_bracket_text[:font_color]).to eql 'CC3300'
      end).not_to raise_exception
    end

    it 'should use sub-language if language starts with html+' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: coderay

      [source,html+js]
      ----
      document.addEventListener('load', function () { console.log('page is loaded!') })
      ----
      EOS

      message_text = (pdf.find_text 'page is loaded!')[0]
      (expect message_text).not_to be_nil
      (expect message_text[:font_color]).to eql 'CC3300'
    end

    it 'should fall back to text if language does not have valid characters' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: coderay

      [source,?!?]
      ----
      ,[.,]
      ----
      EOS

      text = (pdf.find_text ',[.,]')[0]
      (expect text[:font_color]).to eql '333333'
    end

    it 'should not crash if source-highlighter attribute is defined outside of document header' do
      (expect do
        to_pdf <<~'EOS'
        = Document Title

        :source-highlighter: coderay

        [source,ruby]
        ----
        puts 'yo, world!'
        ----
        EOS
      end).not_to raise_exception
    end

    it 'should add indentation guards at start of line that begins with space to preserve indentation' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: coderay

      [source,yaml]
      ----
      category:
        hash:
          key: "value"
      ----
      EOS
      (expect pdf.lines).to eql ['category:', %(\u00a0 hash:), %(\u00a0   key: "value")]
    end

    it 'should expand tabs to preserve indentation' do
      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: coderay

      [source,c]
      ----
      int main() {
      \tevent_loop();
      \treturn 0;
      }
      ----
      EOS
      lines = pdf.lines
      (expect lines).to have_size 4
      (expect lines[1]).to eql %(\u00a0   event_loop();)
      (expect lines[2]).to eql %(\u00a0   return 0;)
    end

    it 'should extract conums so they do not interfere with syntax highlighting' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: coderay

      [source,xml]
      ----
      <tag <1>
        attr="value">
        content
      </tag>
      ----
      EOS

      attr_name_text = (pdf.find_text 'attr')[0]
      (expect attr_name_text).not_to be_nil
      (expect attr_name_text[:font_color]).to eql '4F9FCF'
      (expect (pdf.find_text '①')[0]).not_to be_nil
    end
  end

  context 'Pygments', if: (gem_available? 'pygments.rb'), &(proc do
    it 'should highlight source using Pygments if source-highlighter is pygments' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source,ruby]
      ----
      puts "Hello, Pygments!"
      ----
      EOS

      hello_text = (pdf.find_text '"Hello, Pygments!"')[0]
      (expect hello_text).not_to be_nil
      (expect hello_text[:font_color]).to eql 'DD2200'
      (expect hello_text[:font_name]).to eql 'mplus1mn-regular'
    end

    it 'should display encoded source without highlighting if lexer fails to return a value' do
      input = <<~'EOS'
      :source-highlighter: pygments

      [source,xml]
      ----
      <payload>&amp;</payload>
      ----
      EOS

      # warm up pygments
      pdf = to_pdf input, analyze: true
      (expect pdf.text).to have_size 3

      xml_lexer = Pygments::Lexer.find_by_alias 'xml'
      # emulate highlight returning nil
      class << xml_lexer
        alias_method :_highlight, :highlight
        def highlight *_args; end
      end

      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source,xml]
      ----
      <payload>&amp;</payload>
      ----
      EOS

      (expect pdf.text).to have_size 1
      source_text = pdf.text[0]
      (expect source_text[:string]).to eql '<payload>&amp;</payload>'
      (expect source_text[:font_color]).to eql '333333'
    ensure
      class << xml_lexer
        undef_method :highlight
        alias_method :highlight, :_highlight
      end
    end

    it 'should not crash when adding indentation guards' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        :source-highlighter: pygments

        [source,yaml]
        ----
        category:
          hash:
            key: "value"
        ----
        EOS
        (expect pdf.find_text %r/: ?/).to have_size 3
        lines = pdf.lines
        (expect lines).to have_size 3
        (expect lines[0]).to eql 'category:'
        (expect lines[1]).to eql %(\u00a0 hash:)
        (expect lines[2]).to eql %(\u00a0   key: "value")
        (expect pdf.find_text '"value"').to have_size 1
      end).not_to raise_exception
    end

    it 'should expand tabs to preserve indentation' do
      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: pygments

      [source,c]
      ----
      int main() {
      \tevent_loop();
      \treturn 0;
      }
      ----
      EOS
      lines = pdf.lines
      (expect lines).to have_size 4
      (expect lines[1]).to eql %(\u00a0   event_loop();)
      (expect lines[2]).to eql %(\u00a0   return 0;)
    end

    it 'should use plain text lexer if language is not recognized' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source,foobar]
      ----
      puts "Hello, World!"
      ----
      EOS

      puts_text = (pdf.find_text 'puts')[0]
      (expect puts_text).to be_nil
      (expect pdf.text).to have_size 1
      (expect pdf.text[0][:font_color]).to eql '333333'
    end

    it 'should enable start_inline option for PHP by default' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source,php]
      ----
      echo "<?php";
      ----
      EOS

      echo_text = (pdf.find_text 'echo')[0]
      (expect echo_text).not_to be_nil
      # NOTE: the echo keyword should be highlighted
      (expect echo_text[:font_color]).to eql '008800'
    end

    it 'should not enable the start_inline option for PHP if the mixed option is set' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source%mixed,php]
      ----
      echo "<?php";
      ----
      EOS

      echo_text = (pdf.find_text 'echo')[0]
      # NOTE: the echo keyword should not be highlighted
      (expect echo_text).to be_nil
    end

    it 'should not crash when aligning line numbers' do
      (expect do
        expected_lines = <<~'EOS'.split ?\n
         1 <?xml version="1.0" encoding="UTF-8"?>
         2 <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
         3   <url>
         4     <loc>https://example.org/home.html</loc>
         5     <lastmod>2019-01-01T00:00:00.000Z</lastmod>
         6   </url>
         7   <url>
         8     <loc>https://example.org/about.html</loc>
         9     <lastmod>2019-01-01T00:00:00.000Z</lastmod>
        10   </url>
        11 </urlset>
        EOS

        pdf = to_pdf <<~'EOS', analyze: true
        :source-highlighter: pygments

        [source,xml,linenums]
        ----
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <url>
            <loc>https://example.org/home.html</loc>
            <lastmod>2019-01-01T00:00:00.000Z</lastmod>
          </url>
          <url>
            <loc>https://example.org/about.html</loc>
            <lastmod>2019-01-01T00:00:00.000Z</lastmod>
          </url>
        </urlset>
        ----
        EOS

        (expect pdf.lines).to eql expected_lines
      end).not_to raise_exception
    end

    it 'should honor start value for line numbering' do
      expected_lines = <<~'EOS'.split ?\n
      5 puts 'Hello, World!'
      EOS

      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source,xml,linenums,start=5]
      ----
      puts 'Hello, World!'
      ----
      EOS

      (expect pdf.lines).to eql expected_lines
    end

    it 'should preserve space before callout on last line' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source,yaml]
      ----
      foo: 'bar'
      key: 'value' #<1>
      ----
      <1> key-value pair
      EOS

      text = pdf.text
      conum_idx = text.index {|it| it[:string] == '①' }
      (expect text[conum_idx - 1][:string]).to eql ' '
      (expect text[conum_idx - 2][:string]).to eql '\'value\''
    end

    it 'should support background color on highlighted tokens', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-pygments-token-background-color.pdf'
      :source-highlighter: pygments
      :pygments-style: murphy

      [source,ruby]
      ----
      # Matches a hex color value like #FF0000
      if /^#[a-fA-F0-9]{6}$/.match? color
        puts 'hex color'
      end
      ----
      EOS

      (expect to_file).to visually_match 'source-pygments-token-background-color.pdf'
    end

    it 'should use background color from style', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-pygments-background-color.pdf', pdf_theme: { code_background_color: 'fafafa' }
      :source-highlighter: pygments
      :pygments-style: monokai

      .Ruby
      [source,ruby]
      ----
      if /^#[a-fA-F0-9]{6}$/.match? color
        puts 'hex color'
      end
      ----

      .JavaScript
      [source,js]
      ----
      'use strict'

      const TAG_ALL_RX = /<[^>]+>/g
      module.exports = (html) => html && html.replace(TAG_ALL_RX, '')
      ----
      EOS

      (expect to_file).to visually_match 'source-pygments-background-color.pdf'
    end

    it 'should use font color from style' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments
      :pygments-style: monokai

      [source,text]
      ----
      foo
      bar
      baz
      ----
      EOS

      pdf.text.each do |text|
        (expect text[:font_color]).to eql 'F8F8F2'
      end
    end

    it 'should ignore highlight attribute if empty' do
      pdf = to_pdf <<~'EOS', analyze: :rect
      :source-highlighter: pygments
      :pygments-style: tango

      [source,ruby,linenums,highlight=]
      ----
      puts "Hello, World!"
      ----
      EOS

      (expect pdf.rectangles).to be_empty
    end

    it 'should fall back to pastie style if style is not recognized' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        :source-highlighter: pygments
        :pygments-style: not-recognized

        [source,ruby]
        ----
        # Matches a hex color value like #FF0000
        if /^#[a-fA-F0-9]{6}$/.match? color
          puts 'hex color'
        end
        ----
        EOS

        comment_text = pdf.find_unique_text %r/^#/
        (expect comment_text[:font_color]).to eql '888888'
        rx_text = pdf.find_unique_text %r/^\/\^/
        (expect rx_text[:font_color]).to eql '008800'
      end).not_to raise_exception
    end

    it 'should highlight selected lines but not the line numbers', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-pygments-line-highlighting.pdf'
      :source-highlighter: pygments

      [source,groovy,linenums,highlight=7-9]
      ----
      package com.example

      import static ratpack.groovy.Groovy.ratpack

      ratpack {
          handlers {
              get {
                  render "Hello, World!"
              }
          }
      }
      ----
      EOS

      (expect to_file).to visually_match 'source-pygments-line-highlighting.pdf'
    end

    it 'should not add line number to first line if source is empty' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source%linenums]
      ----
      ----
      EOS

      (expect pdf.text).to be_empty
    end

    it 'should not emit error if linenums are enabled and language is not set' do
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        :source-highlighter: pygments

        [source%linenums]
        ----
        fee
        fi
        fo
        fum
        ----
        EOS

        (expect pdf.lines).to eql ['1 fee', '2 fi', '3 fo', '4 fum']
      end).to not_log_message
    end

    it 'should indent wrapped line if line numbers are enabled' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: pygments

      [source,text,linenums]
      ----
      Here we go again here we go again here we go again here we go again here we go again Here we go again
      ----
      EOS

      linenum_text = (pdf.find_text '1 ')[0]
      (expect linenum_text[:x]).not_to be_nil
      start_texts = pdf.find_text %r/^Here we go again/
      (expect start_texts).to have_size 2
      (expect start_texts[0][:x]).to eql start_texts[1][:x]
      (expect start_texts[0][:x]).to be > linenum_text[:x]
    end

    it 'should highlight and indent wrapped line', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-pygments-highlight-wrapped-line.pdf'
      :source-highlighter: pygments

      [source,xml,linenums,highlight=1;3]
      ----
      <project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
        <modelVersion>4.0.0</modelVersion>
      </project>
      ----
      EOS

      (expect to_file).to visually_match 'source-pygments-highlight-wrapped-line.pdf'
    end

    it 'should guard inner indents' do
      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: pygments

      [source,text]
      ----
        lead space
      flush
        lead space
      ----
      EOS

      (expect pdf.lines).to eql [%(\u00a0 lead space), 'flush', %(\u00a0 lead space)]
    end

    it 'should ignore fragment if empty' do
      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: pygments

      [source,ruby]
      ----
      <1>
      ----
      EOS

      (expect pdf.lines).to eql ['①']
    end
  end)

  context 'Unsupported' do
    it 'should apply specialcharacters substitution and indentation guards for client-side syntax highlighter' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: highlight.js

      [source,xml]
      ----
      <root>
        <child>content</child>
      </root>
      ----
      EOS

      (expect pdf.lines).to eql ['<root>', %(\u00a0 <child>content</child>), '</root>']
      (expect pdf.text.map {|it| it[:font_color] }.uniq).to eql ['333333']
    end

    it 'should apply specialcharacters substitution and indentation guards if syntax highlighter is unsupported' do
      Class.new Asciidoctor::SyntaxHighlighter::Base do
        register_for :foobar

        def highlight?
          true
        end
      end

      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: foobar

      [source,xml]
      ----
      <root>
        <child>content</child>
      </root>
      ----
      EOS

      (expect pdf.lines).to eql ['<root>', %(\u00a0 <child>content</child>), '</root>']
      (expect pdf.text.map {|it| it[:font_color] }.uniq).to eql ['333333']
    end

    it 'should not apply syntax highlighting if specialchars sub is disabled' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,ruby,subs=-specialchars]
      ----
      puts "Hello, World!"
      ----
      EOS

      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'puts "Hello, World!"'
      (expect text[0][:font_color]).to eql '333333'
    end

    it 'should not apply syntax highlighting in scratch document if specialchars sub is disabled' do
      scratch_pdf = nil
      postprocessor_impl = proc do
        process do |doc, output|
          scratch_pdf = doc.converter.scratch
          output
        end
      end

      opts = { extension_registry: Asciidoctor::Extensions.create { postprocessor(&postprocessor_impl) } }
      pdf = to_pdf <<~'EOS', (opts.merge analyze: true)
      :source-highlighter: rouge

      [%unbreakable]
      --
      [source,ruby,subs=-specialchars]
      ----
      puts "Hello, World!"
      ----
      --
      EOS

      [pdf.text, (EnhancedPDFTextInspector.analyze scratch_pdf.render).text].each do |text|
        (expect text[0][:string]).to eql 'puts "Hello, World!"'
        (expect text[0][:font_color]).to eql '333333'
      end
    end
  end

  context 'Callouts' do
    it 'should allow callout to be escaped' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,ruby]
      ----
      source = %(before
      \<1>
      after)
      ----
      EOS

      (expect pdf.lines).to include '<1>'
      (expect pdf.find_text '①').to be_empty
    end

    it 'should not replace callouts if callouts sub is not present' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,ruby,subs=-callouts]
      ----
      source = %(before
      not a conum <1>
      after)
      ----
      EOS

      (expect pdf.lines).to include 'not a conum <1>'
      (expect pdf.find_text '①').to be_empty
    end

    it 'should inherit font color if not set in theme when source highlighter is enabled' do
      pdf = to_pdf <<~'EOS', pdf_theme: { code_font_color: '111111', conum_font_color: nil }, analyze: true
      :source-highlighter: rouge

      [source,ruby]
      ----
      puts 'Hello, World' <1>
      ----
      <1> Just a programming saying hi.
      EOS

      conum_texts = pdf.find_text %r/①/
      (expect conum_texts).to have_size 2
      (expect conum_texts[0][:font_color]).to eql '111111'
      (expect conum_texts[1][:font_color]).to eql '333333'
    end

    it 'should inherit font color if not set in theme when source highlighter is not enabled' do
      pdf = to_pdf <<~'EOS', pdf_theme: { code_font_color: '111111', conum_font_color: nil }, analyze: true
      [source,ruby]
      ----
      puts 'Hello, World' <1>
      ----
      <1> Just a programming saying hi.
      EOS

      conum_texts = pdf.find_text %r/①/
      (expect conum_texts).to have_size 2
      (expect conum_texts[0][:font_color]).to eql '111111'
      (expect conum_texts[1][:font_color]).to eql '333333'
    end

    it 'should process a sequence of two or more callouts when not separated by spaces' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,java]
      ----
      public interface Person {
        String getName(); // <1><2>
        String getDob();
        int getAge(); // <3><4><5>
      }
      ----
      EOS

      lines = pdf.lines
      (expect lines[1]).to end_with '; ① ②'
      (expect lines[3]).to end_with '; ③ ④ ⑤'
    end

    it 'should process a sequence of two or more callouts when separated by spaces' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,java]
      ----
      public interface Person {
        String getName(); // <1> <2>
        String getDob();
        int getAge(); // <3> <4> <5>
      }
      ----
      EOS

      lines = pdf.lines
      (expect lines[1]).to end_with '; ① ②'
      (expect lines[3]).to end_with '; ③ ④ ⑤'
    end

    it 'should honor font family set on conum category in theme for conum in source block' do
      pdf = to_pdf <<~'EOS', pdf_theme: { code_font_family: 'Courier' }, analyze: true
      :source-highlighter: rouge

      [source,java]
      ----
      public interface Person {
        String getName(); <1>
        String getDob(); <2>
        int getAge(); <3>
      }
      ----
      EOS

      lines = pdf.lines
      (expect lines[1]).to end_with '; ①'
      (expect lines[2]).to end_with '; ②'
      (expect lines[3]).to end_with '; ③'
      conum_text = (pdf.find_text '①')[0]
      (expect conum_text[:font_name]).not_to eql 'Courier'
    end

    it 'should substitute autonumber callouts with circled numbers when using rouge as syntax highlighter' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,java]
      ----
      public interface Person {
        String getName(); // <.>
        String getDob(); // <.>
        int getAge(); // <.>
      }
      ----
      EOS

      lines = pdf.lines
      (expect lines[1]).to end_with '; ①'
      (expect lines[2]).to end_with '; ②'
      (expect lines[3]).to end_with '; ③'
    end

    it 'should process multiple autonumber callouts on a single line when using rouge as syntax highlighter' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,java]
      ----
      public interface Person {
        String getName(); // <.>
        String getDob(); // <.>
        int getAge(); // <.> <.>
      }
      ----
      EOS

      lines = pdf.lines
      (expect lines[1]).to end_with '; ①'
      (expect lines[2]).to end_with '; ②'
      (expect lines[3]).to end_with '; ③ ④'
    end

    it 'should preserve space before callout on final line' do
      ['rouge', (gem_available? 'pygments.rb') ? 'pygments' : nil].compact.each do |highlighter|
        pdf = to_pdf <<~'EOS', attribute_overrides: { 'source-highlighter' => highlighter }, analyze: true
        [source,java]
        ----
        public interface Person {
          String getName();
        }  <1>
        ----
        <1> End class definition
        EOS

        lines = pdf.lines
        (expect lines).to include '}  ①'
      end
    end

    it 'should hide spaces in front of conum from source highlighter' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,apache]
      ----
      <Directory /usr/share/httpd/noindex>
          AllowOverride None <1>
          Require all granted
      </Directory>
      ----
      <1> Cannot be overridden by .htaccess
      EOS

      none_text = (pdf.find_text 'None')[0]
      (expect none_text).not_to be_nil
      (expect none_text[:font_color]).to eql 'AA6600'
    end
  end
end
