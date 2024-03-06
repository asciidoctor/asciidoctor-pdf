# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Font' do
  context 'bundled with default themes' do
    it 'should not apply fallback font when using default theme', visual: true do
      input_file = Pathname.new fixture_file 'i18n-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-i18n-default.pdf'
      (expect to_file).to visually_match 'font-i18n-default.pdf'
    end

    # intentionally use the deprecated alias for this test
    it 'should apply fallback font when using default theme with fallback font', visual: true do
      input_file = Pathname.new fixture_file 'i18n-font-test.adoc'
      (expect do
        to_file = to_pdf_file input_file, 'font-i18n-default-with-fallback.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-fallback-font' }
        (expect to_file).to visually_match 'font-i18n-default-with-fallback.pdf'
      end).to log_message using_log_level: :INFO
    end

    it 'should include expected glyphs in bundled default font', visual: true do
      input_file = Pathname.new fixture_file 'glyph-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-glyph-default.pdf'
      (expect to_file).to visually_match 'font-glyph-default.pdf'
    end

    it 'should include expected glyphs in bundled default font with fallback font', visual: true do
      input_file = Pathname.new fixture_file 'glyph-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-glyph-default-with-fallback.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-font-fallbacks' }
      (expect to_file).to visually_match 'font-glyph-default-with-fallback.pdf'
    end

    it 'should include expected glyphs in fallback font', visual: true do
      input_file = Pathname.new fixture_file 'glyph-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-glyph-fallback-only.pdf', pdf_theme: { extends: 'default-with-font-fallbacks', base_font_family: 'M+ 1p Fallback' }, attribute_overrides: { 'pdf-theme' => 'default-with-font-fallbacks' }
      (expect to_file).to visually_match 'font-glyph-fallback-only.pdf'
    end

    it 'should resolve glyph in fallback font when styles are inherited', visual: true do
      input = <<~'EOS'
      |===
      |&#x2611; For | &#x2610; Against

      |Tastes great
      |High in sugar
      |===
      EOS

      to_file = to_pdf_file input, 'fallback-font-inherited-styles.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-font-fallbacks' }
      (expect to_file).to visually_match 'fallback-font-inherited-styles.pdf'
    end

    it 'should use notdef from original font of glyph not found in any fallback font', visual: true do
      input = ?\u0278 * 10
      to_file = to_pdf_file input, 'font-notdef-glyph.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-font-fallbacks' }
      (expect to_file).to visually_match 'font-notdef-glyph.pdf'
    end

    it 'should use glyph from fallback font if not present in primary font', visual: true do
      to_file = to_pdf_file '*を*', 'font-fallback-font.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-font-fallbacks' }
      (expect to_file).to visually_match 'font-fallback-font.pdf'
    end

    it 'should use black glyph from fallback font if not present in primary font and theme is default-for-print-with-fallback-font', visual: true do
      to_file = to_pdf_file '*を*', 'font-fallback-font-for-print.pdf', attribute_overrides: { 'pdf-theme' => 'default-for-print-with-fallback-font' }
      (expect to_file).to visually_match 'font-fallback-font-for-print.pdf'
    end

    it 'should look for glyph in font for the specified font style when fallback font is enabled' do
      pdf_theme = {
        extends: 'default',
        font_catalog: {
          'Noto Serif' => {
            'normal' => 'notoemoji-subset.ttf',
            'bold' => 'notoserif-bold-subset.ttf',
          },
          'M+ 1p Fallback' => {
            'normal' => 'mplus1p-regular-fallback.ttf',
            'bold' => 'mplus1p-regular-fallback.ttf',
          },
        },
        font_fallbacks: ['M+ 1p Fallback'],
      }
      pdf = to_pdf %(**\u03a9**), analyze: true, pdf_theme: pdf_theme
      text = (pdf.find_text ?\u03a9)[0]
      (expect text).not_to be_nil
      (expect text[:font_name]).to eql 'NotoSerif-Bold'
    end

    it 'should include box drawing glyphs in bundled monospace font', visual: true do
      input_file = Pathname.new fixture_file 'box-drawing.adoc'
      to_file = to_pdf_file input_file, 'font-box-drawing.pdf'
      (expect to_file).to visually_match 'font-box-drawing.pdf'
    end

    it 'should render emoji when using default theme with fallback font', visual: true do
      to_file = to_pdf_file <<~'EOS', 'font-emoji.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-font-fallbacks' }
      Don't 😢 over spilled 🍺.

      Asciidoctor is 👍.
      EOS

      (expect to_file).to visually_match 'font-emoji.pdf'
    end

    it 'should use sans base font when using sans theme with fallback font', visual: true do
      to_file = to_pdf_file <<~'EOS', 'font-sans-emoji.pdf', attribute_overrides: { 'pdf-theme' => 'default-sans-with-font-fallbacks' }
      == Lessons

      Don't 😢 over spilled 🍺.

      Asciidoctor is 👍.
      EOS

      (expect to_file).to visually_match 'font-sans-emoji.pdf'
    end

    it 'should log warning once per character not found in any font when fallback font is used and verbose mode is enabled' do
      (expect do
        input_lines = [%(Bitcoin (\u20bf) is a cryptocurrency.), %(The currency is represented using the symbol \u20bf.)]
        input = input_lines.join %(\n\n)
        pdf = to_pdf input, attribute_overrides: { 'pdf-theme' => 'default-with-font-fallbacks' }, analyze: true
        (expect pdf.lines).to eql input_lines
      end).to log_message severity: :WARN, message: %(Could not locate the character `\u20bf' (\\u20bf) in the following fonts: Noto Serif, M+ 1p Fallback, Noto Emoji), using_log_level: :INFO
    end
  end

  context 'built-in (AFM)' do
    it 'should warn if document contains glyph not supported by AFM font' do
      [true, false].each do |in_block|
        (expect do
          input = 'α to ω'
          input = %(====\n#{input}\n====) if in_block
          pdf = to_pdf input, analyze: true, attribute_overrides: { 'pdf-theme' => 'base' }
          not_glyph = ?\u00ac
          text = pdf.text
          (expect text).to have_size 1
          (expect text[0][:string]).to eql %(#{not_glyph} to #{not_glyph})
        end).to log_message severity: :WARN, message: %(The following text could not be fully converted to the Windows-1252 character set:\n| α to ω), using_log_level: :INFO
      end
    end

    it 'should replace essential characters with suitable replacements to avoid warnings' do
      (expect do
        pdf = to_pdf <<~'EOS', pdf_theme: { base_font_family: 'Helvetica' }, analyze: true
        :experimental:

        * disc
         ** circle
           *** square

        no{zwsp}space

        button:[Save]
        EOS
        (expect pdf.find_text font_name: 'Helvetica').to have_size pdf.text.size
        (expect pdf.lines).to eql [%(\u2022 disc), '- circle', %(\u00b7 square), 'nospace', 'button:[Save]']
      end).to not_log_message
    end
  end

  context 'OTF' do
    it 'should allow theme to specify an OTF font', unless: (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.7.0'), visual: true, &(proc do
      to_file = to_pdf_file <<~'EOS', 'font-otf.pdf', enable_footer: true, attribute_overrides: { 'pdf-theme' => (fixture_file 'otf-theme.yml'), 'pdf-fontsdir' => fixtures_dir }
      == OTF

      You're looking at an OTF font!
      EOS
      (expect to_file).to visually_match 'font-otf.pdf'
    end)
  end

  context 'custom' do
    it 'should resolve fonts in specified fonts dir' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-theme' => (fixture_file 'bundled-fonts-theme.yml'), 'pdf-fontsdir' => Asciidoctor::PDF::ThemeLoader::FontsDir }
      fonts = pdf.objects.values.select {|it| Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should look for font file in all specified font dirs' do
      %w(; ,).each do |separator|
        pdf = to_pdf 'content', attribute_overrides: { 'pdf-theme' => (fixture_file 'bundled-fonts-theme.yml'), 'pdf-fontsdir' => ([fixtures_dir, Asciidoctor::PDF::ThemeLoader::FontsDir].join separator) }
        fonts = pdf.objects.values.select {|it| Hash === it && it[:Type] == :Font }
        (expect fonts).to have_size 1
        (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
      end
    end

    it 'should look for font file in gem fonts dir if path entry is empty' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-theme' => (fixture_file 'bundled-fonts-theme.yml'), 'pdf-fontsdir' => ([fixtures_dir, ''].join ';') }
      fonts = pdf.objects.values.select {|it| Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should look for font file in gem fonts dir if path entry includes GEM_FONTS_DIR' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-theme' => (fixture_file 'bundled-fonts-theme.yml'), 'pdf-fontsdir' => ([fixtures_dir, 'GEM_FONTS_DIR'].join ';') }
      fonts = pdf.objects.values.select {|it| Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should allow built-in theme to be extended when using custom fonts dir' do
      pdf = to_pdf %(content\n\n content), attribute_overrides: { 'pdf-theme' => (fixture_file 'custom-fonts-theme.yml'), 'pdf-fontsdir' => fixtures_dir }
      fonts = pdf.objects.values.select {|it| Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 2
      (expect fonts[0][:BaseFont]).to end_with '+mplus-1p-regular'
      (expect fonts[1][:BaseFont]).to end_with '+mplus1mn-regular'
    end

    it 'should expand GEM_FONTS_DIR in theme file' do
      pdf = to_pdf 'content'
      fonts = pdf.objects.values.select {|it| Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should expand GEM_FONTS_DIR in theme file when custom fonts dir is specified' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-fontsdir' => fixtures_dir }
      fonts = pdf.objects.values.select {|it| Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should throw error if font with relative path cannot be found in GEM_FONTS_DIR' do
      pdf_theme = {
        font_catalog: {
          'NoSuchFont' => {
            'normal' => 'no-such-font.ttf',
          },
        },
      }
      expect { to_pdf 'content', pdf_theme: pdf_theme }.to raise_exception Errno::ENOENT, /no-such-font\.ttf not found in GEM_FONTS_DIR$/
    end

    it 'should throw error if font with relative path cannot be found in custom font dirs' do
      %w(, ;).each do |separator|
        pdf_theme = {
          font_catalog: {
            'NoSuchFont' => {
              'normal' => 'no-such-font.ttf',
            },
          },
        }
        expect { to_pdf 'content', attribute_overrides: { 'pdf-fontsdir' => (%w(here there).join separator) }, pdf_theme: pdf_theme }.to raise_exception Errno::ENOENT, /no-such-font\.ttf not found in here or there$/
      end
    end

    it 'should throw error if font with absolute path cannot be found in custom font dirs' do
      pdf_theme = {
        font_catalog: {
          'NoSuchFont' => {
            'normal' => (font_path = fixture_file 'no-such-font.ttf'),
          },
        },
      }
      expect { to_pdf 'content', pdf_theme: pdf_theme, 'pdf-fontsdir' => 'there' }.to raise_exception Errno::ENOENT, /#{Regexp.escape font_path} not found$/
    end

    it 'should throw error that reports font name and style when font is not registered' do
      (expect do
        to_pdf <<~'EOS', pdf_theme: { base_font_family: 'Lato' }
        == Section Title

        paragraph
        EOS
      end).to raise_exception Prawn::Errors::UnknownFont, 'Lato (normal) is not a known font.'
    end

    it 'should throw error that reports font name and style when style is not found for registered font' do
      pdf_theme = {
        font_catalog: {
          'Quicksand' => {
            'normal' => (fixture_file 'Quicksand-Regular.otf'),
          },
        },
        base_font_family: 'Quicksand',
      }
      (expect do
        to_pdf <<~'EOS', pdf_theme: pdf_theme
        == Section Title

        paragraph
        EOS
      end).to raise_exception Prawn::Errors::UnknownFont, 'Quicksand (bold) is not a known font.'
    end
  end

  context 'Kerning' do
    it 'should enable kerning when using default theme', visual: true do
      to_file = to_pdf_file <<~'EOS', 'font-kerning-default.pdf'
      [%hardbreaks]
      AVA
      Aya
      WAWA
      WeWork
      DYI
      EOS

      (expect to_file).to visually_match 'font-kerning-default.pdf'
    end

    it 'should enable kerning when using base theme', visual: true do
      to_file = to_pdf_file <<~'EOS', 'font-kerning-base.pdf', attribute_overrides: { 'pdf-theme' => 'base' }
      [%hardbreaks]
      AVA
      Aya
      WAWA
      WeWork
      DYI
      EOS

      (expect to_file).to visually_match 'font-kerning-base.pdf'
    end

    it 'should allow theme to disable kerning globally', visual: true do
      to_file = to_pdf_file <<~'EOS', 'font-kerning-disabled.pdf', pdf_theme: { base_font_kerning: 'none' }
      [%hardbreaks]
      AVA
      Aya
      WAWA
      WeWork
      DYI
      EOS

      (expect to_file).to visually_match 'font-kerning-disabled.pdf'
    end

    it 'should allow theme to disable kerning per category' do
      {
        'example' => %([example]\nAV T. ij WA *guideline*),
        'sidebar' => %([sidebar]\nAV T. ij WA *guideline*),
        'heading' => '== AV T. ij WA *guideline*',
        'table' => %(|===\n| AV T. ij WA *guideline*\n|===),
        'table_head' => %([%header]\n|===\n| AV T. ij WA *guideline*\n|===),
        'caption' => %(.AV T. ij WA *guideline*'\n|===\n|content\n|===),
      }.each do |category, input|
        pdf = to_pdf input, analyze: true
        guideline_column_with_kerning = (pdf.find_text 'guideline')[0][:x]

        pdf = to_pdf input, pdf_theme: { %(#{category}_font_kerning) => 'none' }, analyze: true
        guideline_column_without_kerning = (pdf.find_text 'guideline')[0][:x]

        (expect guideline_column_without_kerning).to be > guideline_column_with_kerning
      end
    end
  end

  context 'Line breaks' do
    it 'should break line on any CJK character if value of scripts attribute is cjk' do
      pdf = to_pdf <<~'EOS', analyze: true
      :scripts: cjk
      :pdf-theme: default-with-font-fallbacks

      AsciiDoc 是一个人类可读的文件格式，语义上等同于 DocBook 的 XML，但使用纯文本标记了约定。可以使用任何文本编辑器创建文件把 AsciiDoc 和阅读“原样”，或呈现为HTML 或由 DocBook 的工具链支持的任何其他格式，如 PDF，TeX 的，Unix 的手册页，电子书，幻灯片演示等。

      AsciiDoc は、意味的には DocBook XML のに相当するが、プレーン·テキスト·マークアップの規則を使用して、人間が読めるドキュメントフォーマット、である。 AsciiDoc は文書は、任意のテキストエディタを使用して作成され、「そのまま"または、HTML や DocBook のツールチェーンでサポートされている他のフォーマット、すなわち PDF、TeX の、Unix の man ページ、電子書籍、スライドプレゼンテーションなどにレンダリングすることができます。
      EOS

      lines = pdf.lines
      (expect lines).to have_size 8
      (expect lines[0]).to end_with '任何'
      (expect lines[1]).to start_with '文本'
      (expect lines[3]).to end_with '使用'
      (expect lines[4]).to start_with 'して'
    end

    # intentionally use the deprecated alias for this test
    it 'should not break line immediately before an ideographic full stop' do
      pdf = to_pdf <<~'EOS', analyze: true
      :scripts: cjk
      :pdf-theme: default-with-fallback-font

      Asciidoctor PDF 是一个 Asciidoctor 转换器，可将 AsciiDoc 文档转换为PDF文档。填料填料。转换器不会创建临时格式。
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[1]).to start_with '式。'
    end

    it 'should not break line where no-break hyphen is adjacent to formatted text' do
      pdf = to_pdf <<~'EOS', analyze: true
      foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar **foo**&#8209;bar&#8209;**foo**
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[1]).to eql %(foo\u2011bar\u2011foo)
    end

    # NOTE: this test demonstrates a bug in Prawn
    it 'should break line if no-break hyphen is isolated into its own fragment' do
      pdf = to_pdf <<~'EOS', analyze: true
      foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar **foo**&#8209;**bar**&#8209;**foo**
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[1]).to eql %(\u2011bar\u2011foo)
    end
  end

  context 'Separators' do
    it 'should not break line at location of no-break space' do
      input = (%w(a b c d).reduce([]) {|accum, it| accum << (it * 20) }.join ' ') + ?\u00a0 + ('e' * 20)
      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 2
      (expect text[0][:string]).to end_with 'c'
      (expect text[1][:string]).to start_with 'd'
      (expect text[1][:y]).to be < text[0][:y]
    end

    it 'should not break line at location of non-breaking hyphen' do
      input = (%w(a b c d).reduce([]) {|accum, it| accum << (it * 20) }.join ' ') + ?\u2011 + ('e' * 20)
      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 2
      (expect text[0][:string]).to end_with 'c'
      (expect text[1][:string]).to start_with 'd'
      (expect text[1][:y]).to be < text[0][:y]
    end

    it 'should use zero-width space a line break opportunity' do
      input = (%w(a b c d e f).reduce([]) {|accum, it| accum << (it * 5) + ?\u200b + (it * 10) }.join ' ')
      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 2
      (expect text[0][:string]).to eql 'aaaaaaaaaaaaaaa bbbbbbbbbbbbbbb ccccccccccccccc ddddddddddddddd eeeeeeeeeeeeeee fffff'
      (expect text[1][:string]).to eql 'ffffffffff'
      (expect text[1][:y]).to be < text[0][:y]
    end
  end

  context 'font sizes' do
    it 'should resolve font size of inline element specified in em units' do
      pdf_theme = {
        base_font_size: 12,
        sidebar_font_size: 10,
        link_font_size: '0.75em',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      ****
      Check out https://asciidoctor.org[Asciidoctor]'
      ****
      EOS
      normal_text = pdf.find_unique_text 'Check out '
      (expect normal_text[:font_size].to_f).to eql 10.0
      linked_text = pdf.find_unique_text 'Asciidoctor'
      (expect linked_text[:font_size].to_f).to eql 7.5
    end

    it 'should use font size as is if value is less than 1' do
      pdf_theme = {
        base_font_size: 12,
        sidebar_font_size: 10,
        link_font_size: 0.75,
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      ****
      Check out https://asciidoctor.org[Asciidoctor]'
      ****
      EOS
      normal_text = pdf.find_unique_text 'Check out '
      (expect normal_text[:font_size].to_f).to eql 10.0
      linked_text = pdf.find_unique_text 'Asciidoctor'
      (expect linked_text[:font_size].to_f).to eql 0.75
    end

    it 'should resolve font size of inline element specified in rem units' do
      pdf_theme = {
        base_font_size: 12,
        sidebar_font_size: 10,
        link_font_size: '0.75rem',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      ****
      https://asciidoctor.org[Asciidoctor]
      ****
      EOS
      linked_text = pdf.find_unique_text 'Asciidoctor'
      (expect linked_text[:font_size].to_f).to eql 9.0
    end

    it 'should resolve font size of inline element specified in percentage' do
      pdf_theme = {
        base_font_size: 12,
        link_font_size: '75%',
      }
      pdf = to_pdf 'https://asciidoctor.org[Asciidoctor]', pdf_theme: pdf_theme, analyze: true
      linked_text = pdf.find_unique_text 'Asciidoctor'
      (expect linked_text[:font_size].to_f).to eql 9.0
    end

    it 'should resolve font size of inline element specified in points as a String' do
      pdf_theme = {
        base_font_size: 12,
        link_font_size: '9',
      }
      pdf = to_pdf 'https://asciidoctor.org[Asciidoctor]', pdf_theme: pdf_theme, analyze: true
      linked_text = pdf.find_unique_text 'Asciidoctor'
      (expect linked_text[:font_size].to_f).to eql 9.0
    end
  end
end
