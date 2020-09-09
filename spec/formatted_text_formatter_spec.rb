# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::PDF::FormattedText::Formatter do
  context 'HTML markup' do
    it 'should format strong text' do
      output = subject.format '<strong>strong</strong>'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql 'strong'
      (expect output[0][:styles]).to eql [:bold].to_set
    end

    it 'should ignore font color if not a valid hex value' do
      input = %(<span style="color: red">hot</span>)
      output = subject.format input
      (expect output).to have_size 1
      (expect output[0][:text]).to eql 'hot'
      (expect output[0][:color]).to be_nil
    end

    it 'should allow font color to be set on phrase using hex value' do
      ['#F00', '#FF0000'].each do |color|
        input = %(<span style="color: #{color}">hot</span>)
        output = subject.format input
        (expect output).to have_size 1
        (expect output[0][:text]).to eql 'hot'
        (expect output[0][:color]).to eql 'FF0000'
      end
    end

    it 'should allow font color to be set on nested phrase' do
      input = '<span style="color: #FF0000">hot <span style="color: #0000FF">cold</span> hot</span>'
      output = subject.format input
      (expect output).to have_size 3
      (expect output[1][:text]).to eql 'cold'
      (expect output[1][:color]).to eql '0000FF'
    end

    it 'should ignore background color if not a valid hex value' do
      input = %(<span style="background-color: yellow">highlight</span>)
      output = subject.format input
      (expect output).to have_size 1
      (expect output[0][:text]).to eql 'highlight'
      (expect output[0][:background_color]).to be_nil
    end

    it 'should allow background color to be set on phrase using hex value' do
      ['#FF0', '#FFFF00'].each do |color|
        input = %(<span style="background-color: #{color}">highlight</span>)
        output = subject.format input
        (expect output).to have_size 1
        (expect output[0][:text]).to eql 'highlight'
        (expect output[0][:background_color]).to eql 'FFFF00'
      end
    end

    it 'should allow font weight to be set on nested phrase' do
      input = '<span style="font-weight: bold">new</span> release'
      output = subject.format input
      (expect output).to have_size 2
      (expect output[0][:text]).to eql 'new'
      (expect output[0][:styles].to_a).to eql [:bold]
    end

    it 'should ignore unknown font weight on phrase' do
      input = '<span style="font-weight: lighter">new</span> release'
      output = subject.format input
      (expect output).to have_size 2
      (expect output[0][:text]).to eql 'new'
      (expect output[0][:styles]).to be_nil
    end

    it 'should allow font style to be set on nested phrase' do
      input = 'This is <span style="font-style: italic">so</span> easy'
      output = subject.format input
      (expect output).to have_size 3
      (expect output[1][:text]).to eql 'so'
      (expect output[1][:styles].to_a).to eql [:italic]
    end

    it 'should ignore unknown font style on phrase' do
      input = 'This is <span style="font-style: oblique">so</span> easy'
      output = subject.format input
      (expect output).to have_size 3
      (expect output[1][:text]).to eql 'so'
      (expect output[1][:styles]).to be_nil
    end

    it 'should warn if text contains unrecognized tag' do
      input = 'before <foo>bar</foo> after'
      (expect do
        output = subject.format input
        (expect output).to have_size 1
        (expect output[0][:text]).to eql input
      end).to log_message severity: :ERROR, message: /^failed to parse formatted text: #{Regexp.escape input} \(reason: Expected one of .* after < at byte 9\)/
    end

    it 'should warn if text contains unrecognized entity' do
      input = 'a &daggar; in the back'
      (expect do
        output = subject.format input
        (expect output).to have_size 1
        (expect output[0][:text]).to eql input
      end).to log_message severity: :ERROR, message: /^failed to parse formatted text: #{Regexp.escape input} \(reason: Expected one of .* after & at byte 4\)/
    end

    it 'should allow span tag to control width' do
      output = subject.format '<span style="width: 1in">hi</span>'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql 'hi'
      (expect output[0][:width]).to eql '1in'
      (expect output[0][:align]).to be_nil
    end

    it 'should allow span tag to align text to center within width' do
      output = subject.format '<span style="width: 1in; align: center">hi</span>'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql 'hi'
      (expect output[0][:width]).to eql '1in'
      (expect output[0][:align]).to eql :center
    end

    it 'should allow span tag to align text to right within width' do
      output = subject.format '<span style="width: 1in; align: right">hi</span>'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql 'hi'
      (expect output[0][:width]).to eql '1in'
      (expect output[0][:align]).to eql :right
    end
  end

  context 'character references' do
    it 'should decode decimal character reference' do
      {
        '&#39;' => ?',
        '&#169;' => ?\u00a9,
        '&#128515;' => ([0x1f603].pack 'U1'),
      }.each do |ref, chr|
        output = subject.format ref
        (expect output).to have_size 1
        (expect output[0][:text]).to eql chr
      end
    end

    it 'should decode hexadecimal character reference' do
      {
        '&#x27;' => ?',
        '&#xa9;' => ?\u00a9,
        '&#x1f603;' => ([0x1f603].pack 'U1'),
      }.each do |ref, chr|
        output = subject.format ref
        (expect output).to have_size 1
        (expect output[0][:text]).to eql chr
      end
    end

    it 'should decode recognized named entities' do
      output = subject.format '&lt; &gt; &amp; &apos; &nbsp; &quot;'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql %(< > & ' \u00a0 ")
    end

    it 'should ignore unknown named entities' do
      (expect do
        output = subject.format '&dagger;'
        (expect output).to have_size 1
        (expect output[0][:text]).to eql '&dagger;'
      end).to log_message severity: :ERROR, message: '~failed to parse formatted text'
    end

    it 'should decode decimal character references in link href' do
      output = subject.format '<a href="https://cast.you?v=999999&#38;list=abcde&#38;index=1">My Playlist</a>'
      (expect output).to have_size 1
      (expect output[0][:link]).to eql 'https://cast.you?v=999999&list=abcde&index=1'
    end

    it 'should decode hexidecimal character references in link href' do
      output = subject.format '<a href="https://cast.you?v=999999&#x26;list=abcde&#x26;index=1">My Playlist</a>'
      (expect output).to have_size 1
      (expect output[0][:link]).to eql 'https://cast.you?v=999999&list=abcde&index=1'
    end
  end

  # QUESTION: should these go in a separate file?
  context 'integration' do
    it 'should format constrained strong phrase' do
      pdf = to_pdf '*strong*', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql %w(strong NotoSerif-Bold)
    end

    it 'should format unconstrained strong phrase' do
      pdf = to_pdf '**super**nova', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql %w(super NotoSerif-Bold)
      (expect pdf.text[1].values_at :string, :font_name).to eql %w(nova NotoSerif)
    end

    it 'should format constrained emphasis phrase' do
      pdf = to_pdf '_emphasis_', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql %w(emphasis NotoSerif-Italic)
    end

    it 'should format unconstrained emphasis phrase' do
      pdf = to_pdf '__un__cool', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql %w(un NotoSerif-Italic)
      (expect pdf.text[1].values_at :string, :font_name).to eql %w(cool NotoSerif)
    end

    it 'should format constrained monospace phrase' do
      pdf = to_pdf '`monospace`', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql %w(monospace mplus1mn-regular)
    end

    it 'should format unconstrained monospace phrase' do
      pdf = to_pdf '``install``ed', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql %w(install mplus1mn-regular)
      (expect pdf.text[1].values_at :string, :font_name).to eql %w(ed NotoSerif)
    end

    it 'should ignore empty formatted phrase surrounded by text' do
      pdf = to_pdf 'before *{empty}* after', analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'before after'
    end

    it 'should ignore empty formatted phrase at extrema of line' do
      pdf = to_pdf '*{empty}* between *{empty}*', analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'between'
    end

    it 'should format stem equation as monospace' do
      pdf = to_pdf 'Use stem:[x^2] to square the value.', analyze: true
      equation_text = (pdf.find_text 'x^2')[0]
      (expect equation_text[:font_name]).to eql 'mplus1mn-regular'
    end

    it 'should format superscript phrase' do
      pdf = to_pdf 'x^2^', analyze: true
      (expect pdf.strings).to eql %w(x 2)
      text = pdf.text
      (expect text[0][:font_size]).to be > text[1][:font_size]
      (expect text[0][:y]).to be < text[1][:y]
    end

    it 'should compute font size for superscript phrase correctly when parent element uses em units' do
      pdf = to_pdf '`x^2^` represents exponential growth', pdf_theme: { base_font_size: 14, literal_font_size: '0.8em' }, analyze: true
      expected_font_size = 14 * 0.8 * 0.583
      superscript_text = pdf.find_unique_text '2'
      (expect superscript_text[:font_size]).to eql expected_font_size
    end

    it 'should compute font size for superscript phrase correctly when parent element uses % units' do
      pdf = to_pdf '`x^2^` represents exponential growth', pdf_theme: { base_font_size: 14, literal_font_size: '90%' }, analyze: true
      expected_font_size = 14 * 0.9 * 0.583
      superscript_text = pdf.find_unique_text '2'
      (expect superscript_text[:font_size]).to eql expected_font_size
    end

    it 'should format subscript phrase' do
      pdf = to_pdf 'O~2~', analyze: true
      (expect pdf.strings).to eql %w(O 2)
      text = pdf.text
      (expect text[0][:font_size]).to be > text[1][:font_size]
      (expect text[0][:y]).to be > text[1][:y]
    end

    it 'should compute font size for subscript phrase correctly when parent element uses em units' do
      pdf = to_pdf 'The formula `O~2~` is oxygen', pdf_theme: { base_font_size: 14, literal_font_size: '0.8em' }, analyze: true
      expected_font_size = 14 * 0.8 * 0.583
      subscript_text = pdf.find_unique_text '2'
      (expect subscript_text[:font_size]).to eql expected_font_size
    end

    it 'should compute font size for subscript phrase correctly when parent element uses % units' do
      pdf = to_pdf 'The formula `O~2~` is oxygen', pdf_theme: { base_font_size: 14, literal_font_size: '90%' }, analyze: true
      expected_font_size = 14 * 0.9 * 0.583
      subscript_text = pdf.find_unique_text '2'
      (expect subscript_text[:font_size]).to eql expected_font_size
    end

    it 'should add background and border to code as defined in theme', visual: true do
      theme_overrides = {
        literal_background_color: 'f5f5f5',
        literal_border_color: 'dddddd',
        literal_border_width: 0.25,
        literal_border_offset: 2.5,
      }
      to_file = to_pdf_file 'All your `code` belongs to us.', 'text-formatter-code.pdf', pdf_theme: theme_overrides
      (expect to_file).to visually_match 'text-formatter-code.pdf'
    end

    it 'should add border to phrase even when no background color is set', visual: true do
      theme_overrides = {
        literal_font_color: '444444',
        literal_font_size: '0.75em',
        literal_border_color: 'E83E8C',
        literal_border_width: 0.25,
        literal_border_offset: 2.5,
        literal_border_radius: 3,
      }
      to_file = to_pdf_file 'Type `bundle install` to install dependencies', 'text-formatter-border-only.pdf', pdf_theme: theme_overrides
      (expect to_file).to visually_match 'text-formatter-border-only.pdf'
    end

    it 'should add background and border to button as defined in theme', visual: true do
      theme_overrides = {
        button_content: '%s',
        button_background_color: '007BFF',
        button_border_offset: 3,
        button_border_radius: 2,
        button_font_color: 'ffffff',
      }
      to_file = to_pdf_file 'Click btn:[Save] to save your work.', 'text-formatter-button.pdf', pdf_theme: theme_overrides, attribute_overrides: { 'experimental' => '' }
      (expect to_file).to visually_match 'text-formatter-button.pdf'
    end

    it 'should use label as default button content', visual: true do
      theme_overrides = {
        button_content: nil,
        button_background_color: '007BFF',
        button_border_offset: 3,
        button_border_radius: 2,
        button_font_color: 'ffffff',
      }
      to_file = to_pdf_file 'Click btn:[Save] to save your work.', 'text-formatter-button-default.pdf', pdf_theme: theme_overrides, attribute_overrides: { 'experimental' => '' }
      (expect to_file).to visually_match 'text-formatter-button.pdf'
    end

    it 'should replace %s with button label in button content defined in theme' do
      theme_overrides = {
        button_content: '[%s]',
        button_font_color: '333333',
      }
      pdf = to_pdf 'Click btn:[Save] to save your work.', analyze: true, pdf_theme: theme_overrides, attribute_overrides: { 'experimental' => '' }
      (expect pdf.lines).to eql ['Click [Save] to save your work.']
    end

    it 'should add background and border to key as defined in theme', visual: true do
      to_file = to_pdf_file <<~'EOS', 'text-formatter-key.pdf', attribute_overrides: { 'experimental' => '' }
      Press kbd:[q] to exit.

      Press kbd:[Ctrl,c] to kill the process.
      EOS
      (expect to_file).to visually_match 'text-formatter-key.pdf'
    end

    it 'should use + as key separator if not specified in theme' do
      pdf = to_pdf <<~'EOS', analyze: true, pdf_theme: { key_separator: nil }, attribute_overrides: { 'experimental' => '' }
      Press kbd:[Ctrl,c] to kill the process.
      EOS
      (expect pdf.lines).to eql ['Press Ctrl + c to kill the process.']
    end

    it 'should convert menu macro' do
      pdf = to_pdf <<~'EOS', analyze: true, attribute_overrides: { 'experimental' => '' }
      Select menu:File[Quit] to exit.
      EOS
      menu_texts = pdf.find_text font_name: 'NotoSerif-Bold'
      (expect menu_texts).to have_size 3
      (expect menu_texts[0][:string]).to eql 'File '
      (expect menu_texts[0][:font_color]).to eql '333333'
      (expect menu_texts[1][:string]).to eql ?\u203a
      (expect menu_texts[1][:font_color]).to eql 'B12146'
      (expect menu_texts[2][:string]).to eql ' Quit'
      (expect menu_texts[2][:font_color]).to eql '333333'
      (expect pdf.lines).to eql [%(Select File \u203a Quit to exit.)]
    end

    it 'should support menu macro with only the root level' do
      pdf = to_pdf <<~'EOS', analyze: true, attribute_overrides: { 'experimental' => '' }
      The menu:File[] menu is where all the useful stuff is.
      EOS
      menu_texts = pdf.find_text font_name: 'NotoSerif-Bold'
      (expect menu_texts).to have_size 1
      (expect menu_texts[0][:string]).to eql 'File'
      (expect menu_texts[0][:font_color]).to eql '333333'
      (expect pdf.lines).to eql ['The File menu is where all the useful stuff is.']
    end

    it 'should support menu macro with multiple levels' do
      pdf = to_pdf <<~'EOS', analyze: true, attribute_overrides: { 'experimental' => '' }
      Select menu:File[New,Class] to create a new Java class.
      EOS
      menu_texts = pdf.find_text font_name: 'NotoSerif-Bold'
      (expect menu_texts).to have_size 5
      (expect menu_texts[0][:string]).to eql 'File '
      (expect menu_texts[0][:font_color]).to eql '333333'
      (expect menu_texts[1][:string]).to eql ?\u203a
      (expect menu_texts[1][:font_color]).to eql 'B12146'
      (expect menu_texts[2][:string]).to eql ' New '
      (expect menu_texts[2][:font_color]).to eql '333333'
      (expect menu_texts[3][:string]).to eql ?\u203a
      (expect menu_texts[3][:font_color]).to eql 'B12146'
      (expect menu_texts[4][:string]).to eql ' Class'
      (expect menu_texts[4][:font_color]).to eql '333333'
      (expect pdf.lines).to eql [%(Select File \u203a New \u203a Class to create a new Java class.)]
    end

    it 'should use default caret content if not specified by theme' do
      pdf = to_pdf <<~'EOS', analyze: true, pdf_theme: { menu_caret_content: nil }, attribute_overrides: { 'experimental' => '' }
      Select menu:File[Quit] to exit.
      EOS
      menu_texts = pdf.find_text font_name: 'NotoSerif-Bold'
      (expect menu_texts).to have_size 1
      (expect menu_texts[0][:string]).to eql %(File \u203a Quit)
      (expect menu_texts[0][:font_color]).to eql '333333'
      (expect pdf.lines).to eql [%(Select File \u203a Quit to exit.)]
    end

    it 'should add background to mark as defined in theme', visual: true do
      to_file = to_pdf_file 'normal #highlight# normal', 'text-formatter-mark.pdf'
      (expect to_file).to visually_match 'text-formatter-mark.pdf'
    end

    it 'should use glyph from fallback font if not present in primary font', visual: true do
      to_file = to_pdf_file '*を*', 'text-formatter-fallback-font.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-fallback-font' }
      (expect to_file).to visually_match 'text-formatter-fallback-font.pdf'
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

    it 'should be able to reference section title containing icon' do
      pdf = to_pdf <<~'EOS', analyze: true
      :icons: font

      [#reference]
      == icon:cogs[] Heading

      See <<reference>>.
      EOS

      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0]).to eql %(\uf085 Heading)
      (expect lines[1]).to eql %(See \uf085 Heading.)
    end

    it 'should apply text transform to text without markup' do
      [
        ['uppercase', 'here we go again', 'HERE WE GO AGAIN'],
        ['lowercase', 'Here We Go Again', 'here we go again'],
        ['capitalize', 'Here we go again', 'Here We Go Again'],
      ].each do |(transform, before, after)|
        pdf = to_pdf %(== #{before}), pdf_theme: { heading_text_transform: transform }, analyze: true
        lines = pdf.lines
        (expect lines).to have_size 1
        (expect lines[0]).to eql after
        formatted_word = (pdf.find_text %r/again/i)[0]
        (expect formatted_word[:font_name]).to eql 'NotoSerif-Bold'
      end
    end

    it 'should apply text transform to text with markup' do
      [
        ['uppercase', 'here we go *again*', 'HERE WE GO AGAIN'],
        ['lowercase', 'Here We Go *Again*', 'here we go again'],
        ['capitalize', 'Here we go *again*', 'Here We Go Again'],
      ].each do |(transform, before, after)|
        pdf = to_pdf %(== #{before}), pdf_theme: { heading_text_transform: transform }, analyze: true
        lines = pdf.lines
        (expect lines).to have_size 1
        (expect lines[0]).to eql after
        formatted_word = (pdf.find_text %r/again/i)[0]
        (expect formatted_word[:font_name]).to eql 'NotoSerif-Bold'
      end
    end

    it 'should apply capitalization to contiguous characters' do
      pdf = to_pdf %(== foo-bar baz), pdf_theme: { heading_text_transform: 'capitalize' }, analyze: true
      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql 'Foo-bar Baz'
      (expect pdf.text[0][:font_name]).to eql 'NotoSerif-Bold'
    end

    it 'should not lowercase tags when applying lowercase text transform' do
      pdf = to_pdf <<~'EOS', pdf_theme: { sidebar_text_transform: 'lowercase' }
      ****
      image:TuxTheLinuxPenguin.png[width=20] <= How this fella came to be the Linux mascot.
      ****
      EOS

      (expect get_images pdf).to have_size 1
    end

    it 'should apply width and alignment specified by span tag', visual: true do
      %w(center right).each do |align|
        to_file = to_pdf_file <<~EOS, %(text-formatter-align-#{align}-within-width.pdf)
        |+++<span style="width: 1in; align: #{align}; background-color: #ffff00">hi</span>+++|
        EOS
        (expect to_file).to visually_match %(text-formatter-align-#{align}-within-width.pdf)
      end
    end

    it 'should not warn if text contains invalid markup in scratch document' do
      # NOTE: this assertion will fail if the message is logged multiple times
      (expect do
        pdf = to_pdf <<~'EOS', analyze: true
        [%unbreakable]
        --
        before +++<foo>bar</foo>+++ after
        --
        EOS

        (expect pdf.lines).to eql ['before <foo>bar</foo> after']
      end).to log_message severity: :ERROR, message: /^failed to parse formatted text:/
    end
  end

  context 'Roles' do
    it 'should support built-in underline role for text span' do
      input = '[.underline]#2001: A Space Odyssey#'
      pdf = to_pdf input, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      underline = lines[0]
      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      underlined_text = text[0]
      (expect underline[:from][:x]).to eql underlined_text[:x]
      (expect underline[:from][:y]).to be < underlined_text[:y]
      (expect underlined_text[:y] - underline[:from][:y]).to eql 1.25
      (expect underlined_text[:font_color]).to eql underline[:color]
      (expect underline[:to][:x] - underline[:from][:x]).to be > 100
    end

    it 'should support built-in line-through role for text span' do
      input = '[.line-through]#delete me#'
      pdf = to_pdf input, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      underline = lines[0]
      pdf = to_pdf input, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      underlined_text = text[0]
      (expect underline[:from][:x]).to eql underlined_text[:x]
      (expect underline[:from][:y]).to be > underlined_text[:y]
      (expect underlined_text[:y] - underline[:from][:y]).to be < 0
      (expect underlined_text[:font_color]).to eql underline[:color]
      (expect underline[:to][:x] - underline[:from][:x]).to be > 45
    end

    it 'should allow theme to override formatting for text decoration roles' do
      pdf_theme = {
        'role_line-through_text_decoration': 'none',
        'role_line-through_font_color': 'AA0000',
        'role_underline_text_decoration': 'none',
        'role_underline_font_color': '0000AA',
      }
      input = '[.underline]#underline# and [.line-through]#line-through#'
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      (expect pdf.lines).to be_empty
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      line_through_text = (pdf.find_text 'line-through')[0]
      (expect line_through_text[:font_color]).to eql 'AA0000'
      underline_text = (pdf.find_text 'underline')[0]
      (expect underline_text[:font_color]).to eql '0000AA'
    end

    it 'should allow theme to set text decoration color and width' do
      pdf_theme = {
        'role_line-through_text_decoration_color': 'AA0000',
        'role_line-through_text_decoration_width': 2,
        'role_underline_text_decoration_color': '0000AA',
        'role_underline_text_decoration_width': 0.5,
      }
      input = <<~'EOS'
      [.underline]#underline#

      [.line-through]#line-through#
      EOS
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0][:color]).to eql '0000AA'
      (expect lines[0][:width]).to eql 0.5
      (expect lines[1][:color]).to eql 'AA0000'
      (expect lines[1][:width]).to be 2
    end

    it 'should allow theme to set base text decoration width' do
      pdf_theme = {
        base_text_decoration_width: 0.5,
        role_underline_text_decoration_color: '0000AA',
      }
      input = '[.underline]#underline#'
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0][:color]).to eql '0000AA'
      (expect lines[0][:width]).to eql 0.5
    end

    it 'should support size roles (big and small) in default theme' do
      pdf_theme = build_pdf_theme
      (expect pdf_theme.role_big_font_size).to be 13
      (expect pdf_theme.role_small_font_size).to be 9
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: (pdf_theme = build_pdf_theme), analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size].to_f.round 2).to eql pdf_theme.base_font_size_large.to_f
      (expect text[1][:font_size]).to eql pdf_theme.base_font_size
      (expect text[2][:font_size].to_f.round 2).to eql pdf_theme.base_font_size_small.to_f
    end

    it 'should allow theme to override formatting for font size roles' do
      pdf_theme = {
        role_big_font_size: 12,
        role_big_font_style: 'bold',
        role_small_font_size: 8,
        role_small_font_style: 'italic',
      }
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size]).to be 12
      (expect text[0][:font_name]).to eql 'NotoSerif-Bold'
      (expect text[2][:font_size]).to be 8
      (expect text[2][:font_name]).to eql 'NotoSerif-Italic'
    end

    it 'should support font size roles (big and small) using fallback values if not specified in theme' do
      pdf_theme = build_pdf_theme({ base_font_size: 12 }, (fixture_file 'extends-no-theme.yml'))
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size].to_f.round 2).to eql 14.0
      (expect text[1][:font_size]).to be 12
      (expect text[2][:font_size].to_f.round 2).to eql 10.0
    end

    it 'should base font size roles on large and small theme keys if not specified in theme' do
      pdf_theme = build_pdf_theme({ base_font_size: 12, base_font_size_large: 18, base_font_size_small: 9 }, (fixture_file 'extends-no-theme.yml'))
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size].to_f.round 2).to eql 18.0
      (expect text[1][:font_size]).to be 12
      (expect text[2][:font_size].to_f.round 2).to eql 9.0
    end

    it 'should allow theme to control formatting applied to phrase by role' do
      pdf_theme = {
        role_red_font_color: 'ff0000',
        role_red_font_style: 'bold',
        role_blue_font_color: '0000ff',
        role_blue_font_style: 'bold_italic',
      }
      pdf = to_pdf 'Roses are [.red]_red_, violets are [.blue]#blue#.', pdf_theme: pdf_theme, analyze: true

      red_text = (pdf.find_text 'red')[0]
      blue_text = (pdf.find_text 'blue')[0]
      (expect red_text[:font_color]).to eql 'FF0000'
      (expect red_text[:font_name]).to eql 'NotoSerif-BoldItalic'
      (expect blue_text[:font_color]).to eql '0000FF'
      (expect blue_text[:font_name]).to eql 'NotoSerif-BoldItalic'
    end

    it 'should allow custom role to specify underline text decoration' do
      pdf_theme = { role_movie_text_decoration: 'underline' }
      input = '[.movie]_2001: A Space Odyssey_'
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      underline = lines[0]
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      underlined_text = text[0]
      (expect underlined_text[:font_name]).to eql 'NotoSerif-Italic'
      (expect underline[:from][:x]).to eql underlined_text[:x]
      (expect underline[:from][:y]).to be < underlined_text[:y]
      (expect underlined_text[:y] - underline[:from][:y]).to eql 1.25
      (expect underlined_text[:font_color]).to eql underline[:color]
      (expect underline[:to][:x] - underline[:from][:x]).to be > 100
    end

    it 'should allow custom role to specify line-through text decoration' do
      pdf_theme = { role_delete_text_decoration: 'line-through' }
      input = '[.delete]*delete me*'
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      underline = lines[0]
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      underlined_text = text[0]
      (expect underlined_text[:font_name]).to eql 'NotoSerif-Bold'
      (expect underline[:from][:x]).to eql underlined_text[:x]
      (expect underline[:from][:y]).to be > underlined_text[:y]
      (expect underlined_text[:y] - underline[:from][:y]).to be < 0
      (expect underlined_text[:font_color]).to eql underline[:color]
      (expect underline[:to][:x] - underline[:from][:x]).to be > 45
    end

    it 'should allow theme to set text decoration color and width for custom role' do
      pdf_theme = {
        'role_delete_text_decoration': 'line-through',
        'role_delete_text_decoration_color': 'AA0000',
        'role_delete_text_decoration_width': 2,
        'role_important_text_decoration': 'underline',
        'role_important_text_decoration_color': '0000AA',
        'role_important_text_decoration_width': 0.5,
      }
      input = <<~'EOS'
      [.important]#important#

      [.delete]#delete#
      EOS
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 2
      (expect lines[0][:color]).to eql '0000AA'
      (expect lines[0][:width]).to eql 0.5
      (expect lines[1][:color]).to eql 'AA0000'
      (expect lines[1][:width]).to be 2
    end

    it 'should allow custom role to specify font style and text decoration' do
      pdf_theme = { role_heavy_text_decoration: 'underline', role_heavy_font_style: 'bold' }
      input = '[.heavy]#kick#, bass, and trance'
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: :line
      lines = pdf.lines
      (expect lines).to have_size 1
      underline = lines[0]
      pdf = to_pdf input, pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 2
      underlined_text = text[0]
      (expect underlined_text[:font_name]).to eql 'NotoSerif-Bold'
      (expect underline[:from][:x]).to eql underlined_text[:x]
    end

    it 'should allow custom role to apply text transform' do
      pdf_theme = {
        role_lower_text_transform: 'lowercase',
        role_upper_text_transform: 'uppercase',
        role_capital_text_transform: 'capitalize',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      [.lower]#WHISPER# [.upper]#shout# [.capital]#here me roar#
      EOS

      lines = pdf.lines
      (expect lines).to have_size 1
      (expect lines[0]).to eql 'whisper SHOUT Here Me Roar'
    end

    it 'should allow custom role to specify relative font size' do
      pdf_theme = {
        heading_h2_font_size: 24,
        literal_font_size: '0.75em',
        role_mono_font_size: '0.875em',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      == `MIN` and [.mono]`MAX`
      EOS

      min_text = (pdf.find_text 'MIN')[0]
      normal_text = (pdf.find_text ' and ')[0]
      max_text = (pdf.find_text 'MAX')[0]
      (expect min_text[:font_size].to_f).to eql 18.0
      (expect normal_text[:font_size]).to be 24
      (expect max_text[:font_size].to_f).to eql 21.0
    end

    it 'should add background to link as defined in theme', visual: true do
      pdf_theme = {
        link_background_color: 'EFEFEF',
        link_border_offset: 1,
      }
      to_file = to_pdf_file 'Check out https://asciidoctor.org[Asciidoctor].', 'text-formatter-link-background.pdf', pdf_theme: pdf_theme
      (expect to_file).to visually_match 'text-formatter-link-background.pdf'
    end

    it 'should allow custom role to override styles of link' do
      pdf_theme = {
        heading_font_color: '000000',
        link_font_color: '0000AA',
        role_hlink_font_color: '00AA00',
      }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, analyze: true
      == https://asciidoctor.org[Asciidoctor,role=hlink]
      EOS

      link_text = (pdf.find_text 'Asciidoctor')[0]
      (expect link_text[:font_color]).to eql '00AA00'
    end

    it 'should allow custom role to contain hyphens' do
      pdf_theme = {
        'role_flaming-red_font_color' => 'ff0000',
        'role_so-very-blue_font_color' => '0000ff',
      }
      pdf = to_pdf 'Roses are [.flaming-red]_red_, violets are [.so-very-blue]#blue#.', pdf_theme: pdf_theme, analyze: true

      red_text = (pdf.find_text 'red')[0]
      blue_text = (pdf.find_text 'blue')[0]
      (expect red_text[:font_color]).to eql 'FF0000'
      (expect blue_text[:font_color]).to eql '0000FF'
    end

    it 'should append font style configured for role to current style' do
      pdf_theme = {
        role_quick_font_style: 'italic',
      }
      pdf = to_pdf '*That was [.quick]#quick#.*', pdf_theme: pdf_theme, analyze: true

      glorious_text = (pdf.find_text 'quick')[0]
      (expect glorious_text[:font_name]).to eql 'NotoSerif-BoldItalic'
    end

    it 'should allow role to reset font style to normal' do
      pdf_theme = {
        role_normal_font_style: 'normal',
      }
      pdf = to_pdf '*Make it [.normal]#plain#.*', pdf_theme: pdf_theme, analyze: true

      glorious_text = (pdf.find_text 'plain')[0]
      (expect glorious_text[:font_name]).to eql 'NotoSerif'
    end

    it 'should allow role to set font style to italic inside bold text' do
      pdf_theme = {
        role_term_font_style: 'normal_italic',
      }
      pdf = to_pdf '*We call that [.term]#intersectional#.*', pdf_theme: pdf_theme, analyze: true

      glorious_text = (pdf.find_text 'intersectional')[0]
      (expect glorious_text[:font_name]).to eql 'NotoSerif-Italic'
    end

    it 'should support theming multiple roles on a single phrase' do
      pdf_theme = {
        role_bold_font_style: 'bold',
        role_italic_font_style: 'italic',
        role_blue_font_color: '0000ff',
        role_mono_font_family: 'Courier',
        role_tiny_font_size: 8,
      }
      pdf = to_pdf '[.bold.italic.blue.mono.tiny]#text#', pdf_theme: pdf_theme, analyze: true

      formatted_text = (pdf.find_text 'text')[0]
      (expect formatted_text[:font_name]).to eql 'Courier-BoldOblique'
      (expect formatted_text[:font_color]).to eql '0000FF'
      (expect formatted_text[:font_size]).to be 8
    end

    it 'should allow styles from role to override default styles for element' do
      pdf_theme = {
        role_blue_font_color: '0000ff',
      }
      pdf = to_pdf '[.blue]`text`', pdf_theme: pdf_theme, analyze: true

      formatted_text = (pdf.find_text 'text')[0]
      (expect formatted_text[:font_name]).to eql 'mplus1mn-regular'
      (expect formatted_text[:font_color]).to eql '0000FF'
    end

    it 'should allow role to set font style back to normal' do
      pdf_theme = {
        role_normal_font_style: 'normal',
      }
      pdf = to_pdf '[.normal]_text_', pdf_theme: pdf_theme, analyze: true

      formatted_text = (pdf.find_text 'text')[0]
      (expect formatted_text[:font_name]).to eql 'NotoSerif'
    end

    it 'should allow theme to set background and border for custom role', visual: true do
      pdf_theme = {
        role_variable_font_family: 'Courier',
        role_variable_font_size: '1.15em',
        role_variable_font_color: 'FFFFFF',
        role_variable_background_color: 'CF2974',
        role_variable_border_color: '222222',
        role_variable_border_offset: 2,
        role_variable_border_radius: 2,
        role_variable_border_width: 1,
      }
      to_file = to_pdf_file 'reads value from the [.variable]#counter# variable', 'text-formatter-inline-role-bg.pdf', pdf_theme: pdf_theme
      (expect to_file).to visually_match 'text-formatter-inline-role-bg.pdf'
    end

    it 'should allow theme to set only border for custom role', visual: true do
      pdf_theme = {
        role_cmd_font_family: 'Courier',
        role_cmd_font_size: '1.15em',
        role_cmd_border_color: '222222',
        role_cmd_border_offset: 2,
        role_cmd_border_width: 0.5,
      }
      to_file = to_pdf_file 'use the [.cmd]#man# command to get help', 'text-formatter-inline-role-border.pdf', pdf_theme: pdf_theme
      (expect to_file).to visually_match 'text-formatter-inline-role-border.pdf'
    end

    it 'should support role that sets font color in section title and toc' do
      pdf_theme = {
        role_red_font_color: 'FF0000',
        role_blue_font_color: '0000FF',
      }
      pdf = to_pdf <<~'EOS', analyze: true, pdf_theme: pdf_theme
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == [.red]#Red Chapter#

      == [.blue]#Blue Chapter#

      == Default Chapter
      EOS

      red_section_text = pdf.find_text 'Red Chapter'
      blue_section_text = pdf.find_text 'Blue Chapter'
      default_section_text = pdf.find_text 'Default Chapter'
      (expect red_section_text).to have_size 2
      (expect red_section_text[0][:page_number]).to be 1
      (expect red_section_text[0][:font_color]).to eql 'FF0000'
      (expect red_section_text[1][:page_number]).to be 2
      (expect red_section_text[1][:font_color]).to eql 'FF0000'
      (expect blue_section_text).to have_size 2
      (expect blue_section_text[0][:page_number]).to be 1
      (expect blue_section_text[0][:font_color]).to eql '0000FF'
      (expect blue_section_text[1][:page_number]).to be 3
      (expect blue_section_text[1][:font_color]).to eql '0000FF'
      (expect default_section_text).to have_size 2
      (expect default_section_text[0][:page_number]).to be 1
      (expect default_section_text[0][:font_color]).to eql '333333'
      (expect default_section_text[1][:page_number]).to be 4
      (expect default_section_text[1][:font_color]).to eql '333333'
    end
  end
end
