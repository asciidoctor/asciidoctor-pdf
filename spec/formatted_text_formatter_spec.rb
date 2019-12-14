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

    it 'should warn if text contains invalid markup' do
      (expect do
        input = 'before <foo>bar</foo> after'
        output = subject.format input
        (expect output).to have_size 1
        (expect output[0][:text]).to eql input
      end).to log_message severity: :ERROR, message: /^failed to parse formatted text:/
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

  # QUESTION should these go in a separate file?
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

    it 'should format subscript phrase' do
      pdf = to_pdf 'O~2~', analyze: true
      (expect pdf.strings).to eql %w(O 2)
      text = pdf.text
      (expect text[0][:font_size]).to be > text[1][:font_size]
      (expect text[0][:y]).to be > text[1][:y]
    end

    it 'should add background and border to code as defined in theme', visual: true do
      theme_overrides = {
        literal_background_color: 'f5f5f5',
        literal_border_color: 'dddddd',
        literal_border_width: 0.25,
        literal_border_offset: 1.25,
        literal_border_radius: 3,
      }
      to_file = to_pdf_file 'All your `code` belongs to us.', 'text-formatter-code.pdf', pdf_theme: theme_overrides
      (expect to_file).to visually_match 'text-formatter-code.pdf'
    end

    it 'should add background and border to button as defined in theme', visual: true do
      theme_overrides = {
        button_content: '%s',
        button_background_color: '007BFF',
        button_border_offset: 1.5,
        button_border_radius: 2.5,
        button_font_color: 'ffffff',
      }
      to_file = to_pdf_file 'Click btn:[Save] to save your work.', 'text-formatter-button.pdf', pdf_theme: theme_overrides, attribute_overrides: { 'experimental' => '' }
      (expect to_file).to visually_match 'text-formatter-button.pdf'
    end

    it 'should add background and border to key as defined in theme', visual: true do
      to_file = to_pdf_file 'Press kbd:[Ctrl,c] to kill the server.', 'text-formatter-key.pdf', attribute_overrides: { 'experimental' => '' }
      (expect to_file).to visually_match 'text-formatter-key.pdf'
    end

    it 'should add background to mark as defined in theme', visual: true do
      to_file = to_pdf_file 'normal #highlight# normal', 'text-formatter-mark.pdf'
      (expect to_file).to visually_match 'text-formatter-mark.pdf'
    end

    it 'should use glyph from fallback font if not present in primary font', visual: true do
      to_file = to_pdf_file '*を*', 'text-formatter-fallback-font.pdf', attribute_overrides: { 'pdf-theme' => 'default-with-fallback-font' }
      (expect to_file).to visually_match 'text-formatter-fallback-font.pdf'
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
        pdf = to_pdf <<~EOS, pdf_theme: { heading_text_transform: transform }, analyze: true
        == #{before}
        EOS

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
        pdf = to_pdf <<~EOS, pdf_theme: { heading_text_transform: transform }, analyze: true
        == #{before}
        EOS

        lines = pdf.lines
        (expect lines).to have_size 1
        (expect lines[0]).to eql after
        formatted_word = (pdf.find_text %r/again/i)[0]
        (expect formatted_word[:font_name]).to eql 'NotoSerif-Bold'
      end
    end

    it 'should not lowercase tags when applying lowercase text transform' do
      pdf = to_pdf <<~'EOS', pdf_theme: { sidebar_text_transform: 'lowercase' }
      ****
      image:TuxTheLinuxPenguin.png[width=20] <= How this fella came to be the Linux mascot.
      ****
      EOS

      (expect get_images pdf).to have_size 1
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
      pdf_theme = build_pdf_theme({ base_font_size: 12 }, (fixture_file 'extends-nil-theme.yml'))
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size].to_f.round 2).to eql 14.0
      (expect text[1][:font_size]).to be 12
      (expect text[2][:font_size].to_f.round 2).to eql 10.0
    end

    it 'should allow theme to control formatting apply to phrase by role' do
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
      (expect min_text[:font_size]).to eql 18.0
      (expect normal_text[:font_size]).to be 24
      (expect max_text[:font_size]).to eql 21.0
    end

    it 'should allow custom role to override styles of link' do
      pdf_theme = {
        heading_font_color: '000000',
        link_font_color: '0000AA',
        role_hlink_font_color: '00AA00',
      }
      attribute_overrides = asciidoctor_1_5_7_or_better? ? {} : { 'linkattrs' => '' }
      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, attribute_overrides: attribute_overrides, analyze: true
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

    it 'should allow theme to override background and border for custom role', visual: true do
      pdf_theme = {
        role_variable_font_family: 'Courier',
        role_variable_font_size: 10,
        role_variable_font_color: 'FFFFFF',
        role_variable_background_color: 'CF2974',
        role_variable_border_color: 'ED398A',
        role_variable_border_offset: 1.25,
        role_variable_border_radius: 2,
        role_variable_border_width: 1,
      }
      to_file = to_pdf_file '[.variable]#counter#', 'text-formatter-inline-role-bg.pdf', pdf_theme: pdf_theme
      (expect to_file).to visually_match 'text-formatter-inline-role-bg.pdf'
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
