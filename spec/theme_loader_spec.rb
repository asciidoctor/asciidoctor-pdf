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

    it 'should not fail if theme data is false' do
      theme = subject.new.load false
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.to_h).to be_empty
    end

    it 'should store flattened keys in OpenStruct' do
      theme_data = SafeYAML.load <<~EOS
      page:
        size: A4
      base:
        font:
          family: Times-Roman
        border-width: 0.5
      admonition:
        label:
          font_style: bold
      EOS
      theme = subject.new.load theme_data
      (expect theme).to be_an OpenStruct
      (expect theme).to respond_to :page_size
      (expect theme).to respond_to :base_font_family
      (expect theme).to respond_to :base_border_width
      (expect theme).to respond_to :admonition_label_font_style
    end

    it 'should ensure required keys are set' do
      theme_data = SafeYAML.load <<~EOS
      literal:
        font_family: Courier
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_align).to eql 'left'
      (expect theme.code_font_family).to eql 'Courier'
      (expect theme.conum_font_family).to eql 'Courier'
    end

    it 'should not overwrite required keys with default values if already set' do
      theme_data = SafeYAML.load <<~EOS
      base:
        align: justify
      code:
        font_family: M+ 1mn
      conum:
        font_family: M+ 1mn
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_align).to eql 'justify'
      (expect theme.code_font_family).to eql 'M+ 1mn'
      (expect theme.conum_font_family).to eql 'M+ 1mn'
    end
  end

  context '.load_file' do
    it 'should not fail if theme file is empty' do
      theme = subject.load_file fixture_file 'empty-theme.yml'
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.to_h).to be_empty
    end
  end

  context '.load_theme' do
    it 'should load base theme if theme name is base' do
      theme = subject.load_theme 'base'
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.base_font_family).to eql 'Helvetica'
      (expect theme.heading_font_family).to be_nil
      (expect theme).to eql subject.load_base_theme
    end

    it 'should load default theme if no arguments are given' do
      theme = subject.load_theme
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.heading_font_family).to eql 'Noto Serif'
    end

    it 'should not inherit from base theme when loading default theme' do
      theme = subject.load_theme
      # NOTE table_border_style is only set in the base theme
      (expect theme.table_border_style).to be_nil
    end

    it 'should inherit from base theme when loading custom theme' do
      theme = subject.load_theme fixture_file 'empty-theme.yml'
      (expect theme.table_border_style).to eql 'solid'
    end

    it 'should look for file ending in -theme.yml when resolving custom theme' do
      theme = subject.load_theme 'custom', fixtures_dir
      (expect theme.base_font_family).to eql 'Times-Roman'
    end

    it 'should load specified file ending with .yml if path is not given' do
      theme = subject.load_theme fixture_file 'custom-theme.yml'
      (expect theme.base_font_family).to eql 'Times-Roman'
    end

    it 'should load specified file ending with .yml from specified path' do
      theme = subject.load_theme 'custom-theme.yml', fixtures_dir
      (expect theme.base_font_family).to eql 'Times-Roman'
    end
  end

  context 'interpolation' do
    it 'should resolve variable reference to previously defined key' do
      theme_data = SafeYAML.load <<~EOS
      brand:
        blue: '0000FF'
      base:
        font_color: $brand_blue
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_font_color).to eql '0000FF'
    end

    it 'should interpolate variables in value' do
      theme_data = SafeYAML.load <<~EOS
      brand:
        font_family_name: Noto
        font_family_variant: Serif
      base:
        font_family: $brand_font_family_name $brand_font_family_variant
      heading:
        font_family: $brand_font_family_name Sans
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_font_family).to eql 'Noto Serif'
      (expect theme.heading_font_family).to eql 'Noto Sans'
    end

    it 'should interpolate computed value' do
      theme_data = SafeYAML.load <<~EOS
      base:
        font_size: 10
        line_height_length: 12
        line_height: $base_line_height_length / $base_font_size
        font_size_large: $base_font_size * 1.25
        font_size_min: $base_font_size * 3 / 4
      blockquote:
        border_width: 5
        padding:  [0, $base_line_height_length - 2, $base_line_height_length * -0.75, $base_line_height_length + $blockquote_border_width / 2]
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_line_height).to eql 1.2
      (expect theme.base_font_size_large).to eql 12.5
      (expect theme.base_font_size_min).to eql 7.5
      (expect theme.blockquote_padding).to eql [0, 10, -9, 14.5]
    end

    it 'should apply precision functions to value' do
      theme_data = SafeYAML.load <<~EOS
      base:
        font_size: 10.5
      heading:
        h1_font_size: ceil($base_font_size * 2.6)
        h2_font_size: floor($base_font_size * 2.1)
        h3_font_size: round($base_font_size * 1.5)
      EOS
      theme = subject.new.load theme_data
      (expect theme.heading_h1_font_size).to eql 28
      (expect theme.heading_h2_font_size).to eql 22
      (expect theme.heading_h3_font_size).to eql 16
    end

    it 'should wrap cmyk color values in color type if key ends with _color' do
      theme_data = SafeYAML.load <<~EOS
      page:
        background_color: [0, 0, 0, 0]
      base:
        font_color: [100, 100, 100, 100]
      heading:
        font_color: [0, 0, 0, 0.92]
      link:
        font_color: [67.33%, 31.19%, 0, 20.78%]
      EOS
      theme = subject.new.load theme_data
      (expect theme.page_background_color).to eql 'FFFFFF'
      (expect theme.page_background_color).to be_a subject::HexColorValue
      (expect theme.base_font_color).to eql '000000'
      (expect theme.base_font_color).to be_a subject::HexColorValue
      (expect theme.heading_font_color).to eql [0, 0, 0, 92]
      (expect theme.heading_font_color).to be_a subject::CmykColorValue
      (expect theme.link_font_color).to eql [67.33, 31.19, 0, 20.78]
      (expect theme.link_font_color).to be_a subject::CmykColorValue
    end

    it 'should wrap hex color values in color type if key ends with _color' do
      theme_data = SafeYAML.load <<~EOS
      page:
        background_color: 'ffffff'
      base:
        font_color: '000000'
      heading:
        font_color: 333333
      link:
        font_color: 428bca
      EOS
      theme = subject.new.load theme_data
      (expect theme.page_background_color).to eql 'FFFFFF'
      (expect theme.page_background_color).to be_a subject::HexColorValue
      (expect theme.base_font_color).to eql '000000'
      (expect theme.base_font_color).to be_a subject::HexColorValue
      (expect theme.heading_font_color).to eql '333333'
      (expect theme.heading_font_color).to be_a subject::HexColorValue
      (expect theme.link_font_color).to eql '428BCA'
      (expect theme.link_font_color).to be_a subject::HexColorValue
    end

    it 'should coerce rgb color values to hex and wrap in color type if key ends with _color' do
      theme_data = SafeYAML.load <<~EOS
      page:
        background_color: [255, 255, 255]
      base:
        font_color: [0, 0, 0]
      heading:
        font_color: [51, 51, 51]
      link:
        font_color: [66, 139, 202]
      EOS
      theme = subject.new.load theme_data
      (expect theme.page_background_color).to eql 'FFFFFF'
      (expect theme.page_background_color).to be_a subject::HexColorValue
      (expect theme.base_font_color).to eql '000000'
      (expect theme.base_font_color).to be_a subject::HexColorValue
      (expect theme.heading_font_color).to eql '333333'
      (expect theme.heading_font_color).to be_a subject::HexColorValue
      (expect theme.link_font_color).to eql '428BCA'
      (expect theme.link_font_color).to be_a subject::HexColorValue
    end

    it 'should not wrap value in color type if key does not end with _color' do
      theme_data = SafeYAML.load <<~EOS
      menu:
        caret:
          content: 4a4a4a
      EOS
      theme = subject.new.load theme_data
      (expect theme.menu_caret_content).to eql '4a4a4a'
      (expect theme.menu_caret_content).not_to be_a subject::HexColorValue
    end

    # NOTE this only works when the theme is read from a file
    it 'should allow hex color values to be written with # prefix' do
      theme = subject.load_theme 'hex-color-shorthand', fixtures_dir
      (expect theme.base_font_color).to eql '222222'
    end

    it 'should coerce content key to a string' do
      theme_data = SafeYAML.load <<~EOS
      vars:
        foo: bar
      footer:
        recto:
          left:
            content: $vars_foo
          right:
            content: 10
      EOS
      theme = subject.new.load theme_data
      (expect theme.footer_recto_left_content).to eql 'bar'
      (expect theme.footer_recto_right_content).to be_a ::String
      (expect theme.footer_recto_right_content).to eql '10'
    end
  end
end
