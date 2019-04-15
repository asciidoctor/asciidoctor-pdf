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
    it 'should format decimal character reference' do
      output = subject.format '&#169;'
      (expect output.size).to eql 1
      (expect output[0][:text]).to eql ?\u00a9
    end

    it 'should format hexadecimal character reference' do
      output = subject.format '&#xa9;'
      (expect output.size).to eql 1
      (expect output[0][:text]).to eql ?\u00a9
    end

    it 'should format recognized named entities' do
      output = subject.format '&lt; &gt; &amp; &apos; &quot;'
      (expect output.size).to eql 1
      (expect output[0][:text]).to eql %(< > & ' ")
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
  end
end
