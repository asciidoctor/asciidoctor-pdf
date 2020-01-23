# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Font' do
  context 'bundled with default themes' do
    it 'should not apply fallback font when using default theme', visual: true do
      input_file = Pathname.new fixture_file 'i18n-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-i18n-default.pdf'
      (expect to_file).to visually_match 'font-i18n-default.pdf'
    end

    it 'should apply fallback font when using default theme with fallback font', visual: true do
      input_file = Pathname.new fixture_file 'i18n-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-i18n-default-with-fallback.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-fallback-font' }
      (expect to_file).to visually_match 'font-i18n-default-with-fallback.pdf'
    end

    it 'should include expected glyphs in bundled default font', visual: true do
      input_file = Pathname.new fixture_file 'glyph-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-glyph-default.pdf'
      (expect to_file).to visually_match 'font-glyph-default.pdf'
    end

    it 'should include expected glyphs in bundled default font with fallback font', visual: true do
      input_file = Pathname.new fixture_file 'glyph-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-glyph-default-with-fallback.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-fallback-font' }
      (expect to_file).to visually_match 'font-glyph-default-with-fallback.pdf'
    end

    it 'should include expected glyphs in fallback font', visual: true do
      input_file = Pathname.new fixture_file 'glyph-font-test.adoc'
      to_file = to_pdf_file input_file, 'font-glyph-fallback-only.pdf', pdf_theme: { extends: 'default-with-fallback-font', base_font_family: 'M+ 1p Fallback' }, attribute_overrides: { 'pdf-theme' => 'default-with-fallback-font' }
      (expect to_file).to visually_match 'font-glyph-fallback-only.pdf'
    end

    it 'should include box drawing glyphs in bundled monospace font', visual: true do
      input_file = Pathname.new fixture_file 'box-drawing.adoc'
      to_file = to_pdf_file input_file, 'font-box-drawing.pdf'
      (expect to_file).to visually_match 'font-box-drawing.pdf'
    end
  end

  context 'built-in (AFM)' do
    it 'should warn if document contains glyph not supported by AFM font' do
      (expect do
        pdf = to_pdf 'α to ω', analyze: true, attribute_overrides: { 'pdf-theme' => 'base' }
        not_glyph = ?\u00ac
        text = pdf.text
        (expect text).to have_size 1
        (expect text[0][:string]).to eql %(#{not_glyph} to #{not_glyph})
      end).to log_message severity: :WARN, message: %(The following text could not be fully converted to the Windows-1252 character set:\n| α to ω)
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
        (expect pdf.lines).to eql [%(\u2022disc), '-circle', %(\u00b7square), 'nospace', 'button:[Save]']
      end).to not_log_message
    end
  end

  context 'custom' do
    it 'should resolve fonts in specified fonts dir' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-fontsdir' => Asciidoctor::Pdf::ThemeLoader::FontsDir }
      fonts = pdf.objects.values.select {|it| ::Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should look for font file in all specified font dirs' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-fontsdir' => ([fixtures_dir, Asciidoctor::Pdf::ThemeLoader::FontsDir].join ';') }
      fonts = pdf.objects.values.select {|it| ::Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should look for font file in gem fonts dir if path entry is empty' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-fontsdir' => ([fixtures_dir, ''].join ';') }
      fonts = pdf.objects.values.select {|it| ::Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should look for font file in gem fonts dir if path entry is GEM_FONTS_DIR' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-fontsdir' => ([fixtures_dir, 'GEM_FONTS_DIR'].join ';') }
      fonts = pdf.objects.values.select {|it| ::Hash === it && it[:Type] == :Font }
      (expect fonts).to have_size 1
      (expect fonts[0][:BaseFont]).to end_with '+NotoSerif'
    end

    it 'should expand GEM_FONTS_DIR in theme file' do
      pdf = to_pdf 'content', attribute_overrides: { 'pdf-theme' => (fixture_file 'bundled-fonts-theme.yml'), 'pdf-fontsdir' => fixtures_dir }
      fonts = pdf.objects.values.select {|it| ::Hash === it && it[:Type] == :Font }
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
      pdf_theme = {
        font_catalog: {
          'NoSuchFont' => {
            'normal' => 'no-such-font.ttf',
          },
        },
      }
      expect { to_pdf 'content', attribute_overrides: { 'pdf-fontsdir' => 'here,there' }, pdf_theme: pdf_theme }.to raise_exception Errno::ENOENT, /no-such-font\.ttf not found in here or there$/
    end

    it 'should throw error if font with absolute path cannot be found in custom font dirs' do
      pdf_theme = {
        font_catalog: {
          'NoSuchFont' => {
            'normal' => (font_path = fixture_file 'no-such-font.ttf'),
          },
        },
      }
      expect { to_pdf 'content', pdf_theme: pdf_theme }.to raise_exception Errno::ENOENT, /#{Regexp.escape font_path} not found$/
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
        'caption' => %(.AV T. ij WA *guideline*'\n--\ncontent\n--),
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
      :pdf-theme: default-with-fallback-font

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
    it 'should resolve font size of inline element specified in rem' do
      pdf_theme = {
        base_font_size: 12,
        link_font_size: '0.75rem',
      }
      pdf = to_pdf 'https://asciidoctor.org[Asciidoctor]', pdf_theme: pdf_theme, analyze: true
      linked_text = (pdf.find_text 'Asciidoctor')[0]
      (expect linked_text[:font_size]).to eql 9.0
    end
  end
end
