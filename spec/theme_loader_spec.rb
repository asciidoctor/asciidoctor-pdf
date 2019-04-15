require_relative 'spec_helper'

describe Asciidoctor::Pdf::ThemeLoader do
  subject { described_class }

  context '#load' do
    it 'should not fail if theme data is empty' do
      theme = subject.new.load ''
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.to_h).to be_empty
    end
  end

  context '.load_file' do
    it 'should not fail if theme file is empty' do
      theme = subject.load_file fixture_file 'empty.yml'
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.to_h).to be_empty
    end
  end

  context 'interpolation' do
    it 'should interpolate key with variable value' do
      theme_data = SafeYAML.load <<~"EOS"
      brand:
        blue: '0000FF'
      base:
        font_color: $brand_blue
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_font_color).to eql '0000FF'
    end
  end
end
