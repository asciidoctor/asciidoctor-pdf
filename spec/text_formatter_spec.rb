require_relative 'spec_helper'

describe Asciidoctor::Pdf::FormattedText::Formatter do
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
end
