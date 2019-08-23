require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Source' do
  context 'Rouge' do
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

    it 'should use rouge style specified by rouge-style attribute', integration: true do
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
  end

  context 'Callouts' do
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
  end
end
