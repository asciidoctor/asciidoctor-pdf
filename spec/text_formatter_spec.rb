require_relative 'spec_helper'

describe Asciidoctor::PDF::FormattedText::Formatter do
  context 'HTML markup' do
    it 'should format strong text' do
      output = subject.format '<strong>strong</strong>'
      (expect output.size).to eql 1
      (expect output[0][:text]).to eql 'strong'
      (expect output[0][:styles]).to eql [:bold].to_set
    end
  end

  context 'character references' do
    it 'should decode decimal character reference' do
      output = subject.format '&#169;'
      (expect output.size).to eql 1
      (expect output[0][:text]).to eql ?\u00a9
    end

    it 'should decode hexadecimal character reference' do
      output = subject.format '&#xa9;'
      (expect output.size).to eql 1
      (expect output[0][:text]).to eql ?\u00a9
    end

    it 'should decode recognized named entities' do
      output = subject.format '&lt; &gt; &amp; &apos; &nbsp; &quot;'
      (expect output.size).to eql 1
      (expect output[0][:text]).to eql %(< > & ' \u00a0 ")
    end

    it 'should ignore unknown named entities' do
      with_memory_logger do |logger|
        output = subject.format '&dagger;'
        (expect logger.messages.size).to eql 1
        (expect logger.messages[0][:severity]).to eql :ERROR
        (expect logger.messages[0][:message]).to include 'failed to parse formatted text'
        (expect output.size).to eql 1
        (expect output[0][:text]).to eql '&dagger;'
      end
    end

    it 'should decode decimal character references in link href' do
      output = subject.format '<a href="https://cast.you?v=999999&#38;list=abcde&#38;index=1">My Playlist</a>'
      (expect output.size).to eql 1
      (expect output[0][:link]).to eql 'https://cast.you?v=999999&list=abcde&index=1'
    end

    it 'should decode hexidecimal character references in link href' do
      output = subject.format '<a href="https://cast.you?v=999999&#x26;list=abcde&#x26;index=1">My Playlist</a>'
      (expect output.size).to eql 1
      (expect output[0][:link]).to eql 'https://cast.you?v=999999&list=abcde&index=1'
    end
  end

  # QUESTION should these go in a separate file?
  context 'integration' do
    it 'should format constrained strong phrase' do
      pdf = to_pdf '*strong*', analyze: :text
      (expect pdf.text[0].values_at :string, :font_name).to eql ['strong', 'NotoSerif-Bold']
    end

    it 'should format unconstrained strong phrase' do
      pdf = to_pdf '**super**nova', analyze: :text
      (expect pdf.text[0].values_at :string, :font_name).to eql ['super', 'NotoSerif-Bold']
      (expect pdf.text[1].values_at :string, :font_name).to eql ['nova', 'NotoSerif']
    end

    it 'should format constrained emphasis phrase' do
      pdf = to_pdf '_emphasis_', analyze: :text
      (expect pdf.text[0].values_at :string, :font_name).to eql ['emphasis', 'NotoSerif-Italic']
    end

    it 'should format unconstrained emphasis phrase' do
      pdf = to_pdf '__un__cool', analyze: :text
      (expect pdf.text[0].values_at :string, :font_name).to eql ['un', 'NotoSerif-Italic']
      (expect pdf.text[1].values_at :string, :font_name).to eql ['cool', 'NotoSerif']
    end

    it 'should format constrained monospace phrase' do
      pdf = to_pdf '`monospace`', analyze: :text
      (expect pdf.text[0].values_at :string, :font_name).to eql ['monospace', 'mplus1mn-regular']
    end

    it 'should format unconstrained monospace phrase' do
      pdf = to_pdf '``install``ed', analyze: :text
      (expect pdf.text[0].values_at :string, :font_name).to eql ['install', 'mplus1mn-regular']
      (expect pdf.text[1].values_at :string, :font_name).to eql ['ed', 'NotoSerif']
    end

    it 'should format superscript phrase' do
      pdf = to_pdf 'x^2^', analyze: :text
      (expect pdf.strings).to eql ['x', '2']
      text = pdf.text
      (expect text[0][:font_size]).to be > text[1][:font_size]
      (expect text[0][:y]).to be < text[1][:y]
    end

    it 'should format subscript phrase' do
      pdf = to_pdf 'O~2~', analyze: :text
      (expect pdf.strings).to eql ['O', '2']
      text = pdf.text
      (expect text[0][:font_size]).to be > text[1][:font_size]
      (expect text[0][:y]).to be > text[1][:y]
    end
  end
end
