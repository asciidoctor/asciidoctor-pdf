# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Link' do
  context 'URL' do
    it 'should convert a raw URL to a link' do
      input = 'The home page for Asciidoctor is located at https://asciidoctor.org.'
      pdf = to_pdf input
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://asciidoctor.org'

      pdf = to_pdf input, analyze: true
      link_text = (pdf.find_text 'https://asciidoctor.org')[0]
      (expect link_text).not_to be_nil
      (expect link_text[:font_color]).to eql '428BCA'
      (expect link_annotation).to annotate link_text
    end

    it 'should decode character references in the href' do
      input = 'https://github.com/asciidoctor/asciidoctor-pdf/milestones?direction=asc&sort=<>&state=open'
      pdf = to_pdf input
      text = (pdf.page 1).text
      (expect text).to eql input
      link = (get_annotations pdf, 1)[0]
      (expect link[:A][:URI]).to eql input
    end

    it 'should only show address of link with text when media=print and hide-uri-scheme is set' do
      input = 'Just ask https://chatgpt.com[ChatGPT].'
      pdf = to_pdf input, attribute_overrides: { 'media' => 'print', 'hide-uri-scheme' => '' }
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'https://chatgpt.com'

      pdf = to_pdf input, attribute_overrides: { 'media' => 'print', 'hide-uri-scheme' => '' }, analyze: true
      (expect pdf.lines[0]).to eql 'Just ask ChatGPT [chatgpt.com].'
    end

    it 'should convert link surrounded in double smart quotes' do
      pdf = to_pdf '"`https://asciidoctor.org[Asciidoctor]`"'
      text = (pdf.page 1).text
      (expect text).to eql %(\u201cAsciidoctor\u201d)
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link = annotations[0]
      (expect link[:A][:URI]).to eql 'https://asciidoctor.org'
    end

    it 'should convert link surrounded in single smart quotes' do
      pdf = to_pdf %('`https://asciidoctor.org[Asciidoctor]`')
      text = (pdf.page 1).text
      (expect text).to eql %(\u2018Asciidoctor\u2019)
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link = annotations[0]
      (expect link[:A][:URI]).to eql 'https://asciidoctor.org'
    end

    it 'should not encode hash that precedes the fragment in a URL' do
      url_with_hash = 'https://github.com/asciidoctor/asciidoctor-pdf/blob/main/docs/theming-guide.adoc#fonts'
      pdf = to_pdf %(Learn how to configure #{url_with_hash}[].)
      text = (pdf.page 1).text
      (expect text).to eql %(Learn how to configure #{url_with_hash.sub 'theming-guide', "theming-\nguide"}.)
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 2
      (expect annotations[0][:A][:URI]).to eql url_with_hash
      (expect annotations[1][:A][:URI]).to eql url_with_hash
    end

    it 'should split bare URL on breakable characters' do
      [
        'the URL on this line will get split on the ? char https://github.com/asciidoctor/asciidoctor/issues?|q=milestone%3Av2.0.x',
        'the URL on this line will get split on the / char instead https://github.com/asciidoctor/asciidoctor/|issues?q=milestone%3Av2.0.x',
        'the URL on this line will get split on the # char https://github.com/asciidoctor/asciidoctor/issues#|milestone%3Av2.0.x',
      ].each do |text|
        before, after = text.split '|', 2
        pdf = to_pdf %(#{before}#{after}), analyze: true
        lines = pdf.lines
        (expect lines).to have_size 2
        (expect lines[0]).to end_with before
        (expect lines[1]).to start_with after
      end
    end

    it 'should not break on last character of bare URL' do
      pdf = to_pdf <<~'END', analyze: true
      https://this.is.a.very.long.url.that.is.going.to.be.split.at.a.breakable.location.com/verylongpathname?a[]
      END
      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0]).to end_with '/'
      (expect lines[1]).to eql 'verylongpathname?a'
    end

    it 'should not attempt to break URL when URL is a bare scheme' do
      pdf = to_pdf 'link:https://[]', analyze: true
      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql 'https://'
    end

    it 'should not split bare URL when using an AFM font' do
      pdf = to_pdf <<~'END', pdf_theme: { base_font_family: 'Helvetica' }, analyze: true
      this line contains a URL that falls at the end of the line and yet cannot be split https://goo.gl/search/asciidoctor
      END
      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[1]).to eql 'https://goo.gl/search/asciidoctor'
    end

    it 'should not split bare URL after scheme' do
      pdf = to_pdf <<~'END', analyze: true
      this line contains a URL that falls at the end of the line that is not split after the scheme https://goo.gl/search/asciidoctor
      END
      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[1]).to eql 'https://goo.gl/search/asciidoctor'
    end

    it 'should not split bare URL with nobreak role' do
      pdf = to_pdf <<~'END', analyze: true
      this line contains a URL that falls at the end of the line that is not split https://goo.gl/search/asciidoctor[role=nobreak]
      END
      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[1]).to eql 'https://goo.gl/search/asciidoctor'
    end

    it 'should reveal URL of link when media=print or media=prepress' do
      %w(print prepress).each do |media|
        pdf = to_pdf <<~'END', attribute_overrides: { 'media' => media }, analyze: true
        https://asciidoctor.org[Asciidoctor] is a text processor.
        END

        (expect pdf.lines).to eql ['Asciidoctor [https://asciidoctor.org] is a text processor.']
      end
    end

    it 'should reveal URL of link when show-link-uri is set' do
      pdf = to_pdf <<~'END', analyze: true
      :show-link-uri:

      https://asciidoctor.org[Asciidoctor] is a text processor.
      END

      (expect pdf.lines).to eql ['Asciidoctor [https://asciidoctor.org] is a text processor.']
    end

    it 'should not reveal URL of link when show-link-uri is unset in document even when media is print or prepress' do
      %w(print prepress).each do |media|
        pdf = to_pdf <<~'END', attribute_overrides: { 'media' => media }, analyze: true
        :!show-link-uri:

        https://asciidoctor.org[Asciidoctor] is a text processor.
        END

        (expect pdf.lines).to eql ['Asciidoctor is a text processor.']
      end
    end

    it 'should not reveal URL of link when show-link-uri is unset from API even media is print or prepress' do
      %w(print prepress).each do |media|
        pdf = to_pdf <<~'END', attribute_overrides: { 'media' => media, 'show-link-uri' => nil }, analyze: true
        https://asciidoctor.org[Asciidoctor] is a text processor.
        END

        (expect pdf.lines).to eql ['Asciidoctor is a text processor.']
      end
    end

    it 'should split revealed URL on breakable characters when media=print, media=prepress, or show-link-uri is set' do
      inputs = [
        'the URL on this line will get split on the ? char https://github.com/asciidoctor/asciidoctor/issues?|q=milestone%3Av2.0.x[link]',
        'the URL on this line will get split on the / char instead https://github.com/asciidoctor/asciidoctor/|issues?q=milestone%3Av2.0.x[link]',
        'the URL on this line will get split on the # char https://github.com/asciidoctor/asciidoctor/issues#|milestone%3Av2.0.x[link]',
      ]
      [{ 'media' => 'print' }, { 'media' => 'prepress' }, { 'show-link-uri' => '' }].each do |attribute_overrides|
        inputs.each do |text|
          before, after = text.split '|', 2
          expected_before = before.sub 'https://', 'link [ https://'
          expected_after = after.sub '[link]', ']'
          pdf = to_pdf %(#{before}#{after}), attribute_overrides: attribute_overrides, analyze: true
          lines = pdf.lines
          (expect lines).to have_size 2
          (expect lines[0]).to end_with expected_before
          (expect lines[1]).to start_with expected_after
        end
      end
    end
  end

  context 'Email' do
    it 'should convert bare email address to link' do
      input = 'Send a message to doc.writer@example.org.'
      pdf = to_pdf input
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'mailto:doc.writer@example.org'
      pdf = to_pdf input, analyze: true
      link_text = pdf.find_unique_text 'doc.writer@example.org'
      (expect link_text).not_to be_nil
      (expect link_text[:font_color]).to eql '428BCA'
      (expect link_annotation).to annotate link_text
    end

    it 'should create email address link' do
      input = 'Send a message to mailto:doc.writer@example.org[Doc Writer].'
      pdf = to_pdf input
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'mailto:doc.writer@example.org'
      (expect (pdf.page 1).text).to include 'Doc Writer'
      pdf = to_pdf input, analyze: true
      link_text = pdf.find_unique_text 'Doc Writer'
      (expect link_text).not_to be_nil
      (expect link_text[:font_color]).to eql '428BCA'
      (expect link_annotation).to annotate link_text
    end

    it 'should show mailto address of bare email when media=prepress' do
      input = 'Send message to doc.writer@example.org.'
      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress' }
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'mailto:doc.writer@example.org'

      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress' }, analyze: true
      (expect pdf.lines[0]).to eql 'Send message to doc.writer@example.org.'
    end

    it 'should show mailto address of email link when media=prepress' do
      input = 'Send message to mailto:doc.writer@example.org[Doc Writer].'
      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress' }
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'mailto:doc.writer@example.org'

      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress' }, analyze: true
      (expect pdf.lines[0]).to eql 'Send message to Doc Writer [mailto:doc.writer@example.org].'
    end

    it 'should not show mailto address of bare email when media=prepress and hide-uri-scheme is set' do
      input = 'Send message to doc.writer@example.org.'
      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress', 'hide-uri-scheme' => '' }
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'mailto:doc.writer@example.org'

      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress', 'hide-uri-scheme' => '' }, analyze: true
      (expect pdf.lines[0]).to eql 'Send message to doc.writer@example.org.'
    end

    it 'should not use mailto prefix on email address of email link when media=prepress and hide-uri-scheme is set' do
      input = 'Send message to mailto:doc.writer@example.org[Doc Writer].'
      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress', 'hide-uri-scheme' => '' }
      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to be :Link
      (expect link_annotation[:A][:URI]).to eql 'mailto:doc.writer@example.org'

      pdf = to_pdf input, attribute_overrides: { 'media' => 'prepress', 'hide-uri-scheme' => '' }, analyze: true
      (expect pdf.lines[0]).to eql 'Send message to Doc Writer [doc.writer@example.org].'
    end
  end

  context 'Unknown' do
    it 'should show warning if anchor type is unknown' do
      linkme_inline_macro_impl = proc do
        named 'linkme'
        process do |parent, target|
          create_anchor parent, target, type: :unknown
        end
      end
      opts = { extension_registry: Asciidoctor::Extensions.create { inline_macro(&linkme_inline_macro_impl) } }
      (expect do
        pdf = to_pdf 'before linkme:foobar[] after', (opts.merge analyze: true)
        (expect pdf.lines).to eql ['before after']
      end).to log_message severity: :WARN, message: 'unknown anchor type: :unknown'
    end
  end

  context 'Theming' do
    it 'should apply text decoration to link defined by theme' do
      pdf_theme = {
        link_font_style: 'italic',
        link_text_decoration: 'underline',
      }
      input = 'The home page for Asciidoctor is located at https://asciidoctor.org.'
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      underline = lines[0]
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      link_text = (pdf.find_text 'https://asciidoctor.org')[0]
      (expect link_text[:font_name]).to eql 'NotoSerif-Italic'
      (expect link_text[:font_color]).to eql underline[:color]
      (expect underline[:width]).to be_nil
    end

    it 'should allow theme to set width and color of text decoration' do
      [:base_text_decoration_width, :link_text_decoration_width].each do |key|
        pdf_theme = {
          link_text_decoration: 'underline',
          link_text_decoration_color: '0000FF',
        }
        pdf_theme[key] = 0.5
        pdf = to_pdf 'The home page for Asciidoctor is located at https://asciidoctor.org.', pdf_theme: pdf_theme, analyze: :line
        lines = pdf.lines
        (expect lines).to have_size 1
        underline = lines[0]
        (expect underline[:color]).to eql '0000FF'
        (expect underline[:width]).to eql 0.5
      end
    end
  end
end
