# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Source' do
  context 'Rouge' do
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
      # NOTE the echo keyword should be highlighted
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
      # NOTE the echo keyword should not be highlighted
      (expect echo_text).to be_nil
    end

    it 'should preserve cgi-style options when setting start_inline option for PHP' do
      pdf = to_pdf <<~'EOS', analyze: true
      :source-highlighter: rouge

      [source,php?funcnamehighlighting=0]
      ----
      cal_days_in_month(CAL_GREGORIAN, 6, 2019)
      ----
      EOS

      if Rouge.version >= '2.1.0'
        funcname_text = (pdf.find_text 'cal_days_in_month')[0]
        (expect funcname_text).not_to be_nil
        (expect funcname_text[:font_color]).to eql '333333'

        year_text = (pdf.find_text '2019')[0]
        (expect year_text).not_to be_nil
        (expect year_text[:font_color]).to eql '0000DD'
      else
        text = pdf.text
        (expect text).to have_size 1
        (expect text[0][:string]).to eql 'cal_days_in_month(CAL_GREGORIAN, 6, 2019)'
        (expect text[0][:font_color]).to eql '333333'
      end
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

    it 'should use rouge style specified by rouge-style attribute', visual: true do
      to_file = to_pdf_file <<~'EOS', 'source-rouge-style.pdf'
      :source-highlighter: rouge
      :rouge-style: molokai

      [source,js]
      ----
      'use strict'

      const TAG_ALL_RX = /<[^>]+>/g
      module.exports = (html) => html && html.replace(TAG_ALL_RX, '')
      ----
      EOS

      (expect to_file).to visually_match 'source-rouge-style.pdf'
    end

    it 'should not crash if source-highlighter attribute is defined outside of document header' do
      (expect do
        to_pdf <<~'EOS'
        = Document Title

        :source-highlighter: rouge

        [source,ruby]
        ----
        puts 'yo, world!'
        ----
        EOS
      end).not_to raise_exception
    end

    it 'should apply bw style' do
      pdf = to_pdf <<~EOS, analyze: true
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

    it 'should add line numbers to start of line if linenums option is enabled' do
      expected_lines = <<~EOS.split ?\n
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

      pdf = to_pdf <<~EOS, analyze: true
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

    it 'should honor start value for line numbering' do
      expected_lines = <<~EOS.split ?\n
      5 puts 'Hello, World!'
      EOS

      pdf = to_pdf <<~EOS, analyze: true
      :source-highlighter: rouge

      [source,xml,linenums,start=5]
      ----
      puts 'Hello, World!'
      ----
      EOS

      (expect pdf.lines).to eql expected_lines
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
  end

  context 'Pygments' do
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

    it 'should not crash when adding indentation guards' do
      (expect do
        pdf = to_pdf <<~EOS, analyze: true
        :source-highlighter: pygments

        [source,yaml]
        ---
        category:
          hash:
            key: "value"
        ---
        EOS
        (expect pdf.find_text 'category:').to have_size 1
        (expect pdf.find_text %(\u00a0 hash:)).to have_size 1
        (expect pdf.find_text %(\u00a0   key: )).to have_size 1
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

    it 'should not crash when aligning line numbers' do
      (expect do
        expected_lines = <<~EOS.split ?\n
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

        pdf = to_pdf <<~EOS, analyze: true
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
      to_file = to_pdf_file <<~EOS, 'source-pygments-token-background-color.pdf'
      :source-highlighter: pygments
      :pygments-style: colorful

      [source,ruby]
      ----
      if /^#[a-fA-F0-9]{6}$/.match? color
        puts 'hex color'
      end
      ----
      EOS

      (expect to_file).to visually_match 'source-pygments-token-background-color.pdf'
    end

    it 'should use background color from style', visual: true do
      to_file = to_pdf_file <<~EOS, 'source-pygments-background-color.pdf', pdf_theme: { code_background_color: 'fafafa' }
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

    it 'should highlight selected lines but not the line numbers', visual: true do
      to_file = to_pdf_file <<~EOS, 'source-pygments-line-highlighting.pdf'
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
  end if ENV.key? 'PYGMENTS_VERSION'

  context 'Callouts' do
    it 'should substitute autonumber callouts with circled numbers when using rouge as syntax highlighter' do
      pdf = to_pdf <<~EOS, analyze: true
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
      pdf = to_pdf <<~EOS, analyze: true
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
  end
end
