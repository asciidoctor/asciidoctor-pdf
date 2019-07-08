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
      output = subject.format '&#169;'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql ?\u00a9
    end

    it 'should decode hexadecimal character reference' do
      output = subject.format '&#xa9;'
      (expect output).to have_size 1
      (expect output[0][:text]).to eql ?\u00a9
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

    it 'should add background and border to monospaced text defined in theme', integration: true do
      theme_overrides = {
        literal_background_color: 'f5f5f5',
        literal_border_color: 'dddddd',
        literal_border_width: 0.25,
        literal_border_offset: 1.25,
        literal_border_radius: 3,
      }
      to_file = to_pdf_file 'All your `code` belongs to us.', 'text-formatter-code.pdf', pdf_theme: theme_overrides, analyze: true
      (expect to_file).to visually_match 'text-formatter-code.pdf'
    end
  end
end
