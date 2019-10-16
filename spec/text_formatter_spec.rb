require_relative 'spec_helper'

describe Asciidoctor::PDF::FormattedText::Formatter do
  context 'HTML markup' do
    it 'should format strong text' do
      output = subject.format '<strong>strong</strong>'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql 'strong'
      (expect output[0][:styles]).to eql [:bold].to_set
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
      (expect {
        output = subject.format '&dagger;'
        (expect output).to have_size 1
        (expect output[0][:text]).to eql '&dagger;'
      }).to log_message severity: :ERROR, message: '~failed to parse formatted text'
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
      (expect pdf.text[0].values_at :string, :font_name).to eql ['strong', 'NotoSerif-Bold']
    end

    it 'should format unconstrained strong phrase' do
      pdf = to_pdf '**super**nova', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql ['super', 'NotoSerif-Bold']
      (expect pdf.text[1].values_at :string, :font_name).to eql ['nova', 'NotoSerif']
    end

    it 'should format constrained emphasis phrase' do
      pdf = to_pdf '_emphasis_', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql ['emphasis', 'NotoSerif-Italic']
    end

    it 'should format unconstrained emphasis phrase' do
      pdf = to_pdf '__un__cool', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql ['un', 'NotoSerif-Italic']
      (expect pdf.text[1].values_at :string, :font_name).to eql ['cool', 'NotoSerif']
    end

    it 'should format constrained monospace phrase' do
      pdf = to_pdf '`monospace`', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql ['monospace', 'mplus1mn-regular']
    end

    it 'should format unconstrained monospace phrase' do
      pdf = to_pdf '``install``ed', analyze: true
      (expect pdf.text[0].values_at :string, :font_name).to eql ['install', 'mplus1mn-regular']
      (expect pdf.text[1].values_at :string, :font_name).to eql ['ed', 'NotoSerif']
    end

    it 'should format superscript phrase' do
      pdf = to_pdf 'x^2^', analyze: true
      (expect pdf.strings).to eql ['x', '2']
      text = pdf.text
      (expect text[0][:font_size]).to be > text[1][:font_size]
      (expect text[0][:y]).to be < text[1][:y]
    end

    it 'should format subscript phrase' do
      pdf = to_pdf 'O~2~', analyze: true
      (expect pdf.strings).to eql ['O', '2']
      text = pdf.text
      (expect text[0][:font_size]).to be > text[1][:font_size]
      (expect text[0][:y]).to be > text[1][:y]
    end

    it 'should add background and border to code as defined in theme', integration: true do
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

    it 'should add background and border to button as defined in theme', integration: true do
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

    it 'should add background and border to key as defined in theme', integration: true do
      to_file = to_pdf_file 'Press kbd:[Ctrl,c] to kill the server.', 'text-formatter-key.pdf', attribute_overrides: { 'experimental' => '' }
      (expect to_file).to visually_match 'text-formatter-key.pdf'
    end

    it 'should add background to mark as defined in theme', integration: true do
      to_file = to_pdf_file 'normal #highlight# normal', 'text-formatter-mark.pdf'
      (expect to_file).to visually_match 'text-formatter-mark.pdf'
    end

    it 'should use glyph from fallback font if not present in primary font', integration: true do
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

    it 'should support size roles (big and small) in default theme' do
      pdf_theme = build_pdf_theme
      (expect pdf_theme.role_big_font_size).to eql 13
      (expect pdf_theme.role_small_font_size).to eql 9
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: (pdf_theme = build_pdf_theme), analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size].to_f.round 2).to eql pdf_theme.base_font_size_large.to_f
      (expect text[1][:font_size]).to eql pdf_theme.base_font_size
      (expect text[2][:font_size].to_f.round 2).to eql pdf_theme.base_font_size_small.to_f
    end

    it 'should allow theme to override formatting for big and small roles' do
      pdf_theme = {
        role_big_font_size: 12,
        role_big_font_style: 'bold',
        role_small_font_size: 8,
        role_small_font_style: 'italic',
      }
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size]).to eql 12
      (expect text[0][:font_name]).to eql 'NotoSerif-Bold'
      (expect text[2][:font_size]).to eql 8
      (expect text[2][:font_name]).to eql 'NotoSerif-Italic'
    end

    it 'should support size roles (big and small) using fallback values if not specified in theme' do
      pdf_theme = build_pdf_theme({ base_font_size: 12 }, (fixture_file 'extends-nil-theme.yml'))
      pdf = to_pdf '[.big]#big# and [.small]#small#', pdf_theme: pdf_theme, analyze: true
      text = pdf.text
      (expect text).to have_size 3
      (expect text[0][:font_size].to_f.round 2).to eql 14.0
      (expect text[1][:font_size]).to eql 12
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
      (expect formatted_text[:font_size]).to eql 8
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

    it 'should allow theme to override background and border for custom role', integration: true do
      pdf_theme = {
        role_variable_font_family: 'Courier',
        role_variable_font_size: 10,
        role_variable_font_color: 'FFFFFF',
        role_variable_background_color: 'CF2974',
        role_variable_border_color: 'ED398A',
        role_variable_border_offset: 1.25,
        role_variable_border_radius: 2,
        role_variable_border_width: 1
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
      (expect red_section_text[0][:page_number]).to eql 1
      (expect red_section_text[0][:font_color]).to eql 'FF0000'
      (expect red_section_text[1][:page_number]).to eql 2
      (expect red_section_text[1][:font_color]).to eql 'FF0000'
      (expect blue_section_text).to have_size 2
      (expect blue_section_text[0][:page_number]).to eql 1
      (expect blue_section_text[0][:font_color]).to eql '0000FF'
      (expect blue_section_text[1][:page_number]).to eql 3
      (expect blue_section_text[1][:font_color]).to eql '0000FF'
      (expect default_section_text).to have_size 2
      (expect default_section_text[0][:page_number]).to eql 1
      (expect default_section_text[0][:font_color]).to eql '333333'
      (expect default_section_text[1][:page_number]).to eql 4
      (expect default_section_text[1][:font_color]).to eql '333333'
    end
  end
end
