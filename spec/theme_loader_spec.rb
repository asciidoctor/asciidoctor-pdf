# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::PDF::ThemeLoader do
  subject { described_class }

  describe '#load' do
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
      theme_data = SafeYAML.load <<~'EOS'
      page:
        size: A4
      base:
        font:
          family: Times-Roman
        border_width: 0.5
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

    it 'should not flatten admonition icon keys' do
      theme_data = SafeYAML.load <<~'EOS'
      admonition:
        icon:
          tip:
            name: far-lightbulb
            stroke_color: ffff00
            size: 24
          note:
            name: far-sticky-note
            stroke_color: 0000ff
            size: 24
      EOS
      theme = subject.new.load theme_data
      (expect theme).to be_an OpenStruct
      (expect theme.admonition_icon_tip).to be_a ::Hash
      (expect theme.admonition_icon_tip).to eql name: 'far-lightbulb', stroke_color: 'FFFF00', size: 24
      (expect theme.admonition_icon_note).to be_a ::Hash
      (expect theme.admonition_icon_note).to eql name: 'far-sticky-note', stroke_color: '0000FF', size: 24
    end

    it 'should replace hyphens in key names with underscores' do
      theme_data = SafeYAML.load <<~'EOS'
      page-size: A4
      base:
        font-family: Times-Roman
      abstract:
        title-font-size: 20
      admonition:
        icon:
          tip:
            stroke-color: FFFF00
      EOS
      theme = subject.new.load theme_data
      (expect theme).to be_an OpenStruct
      (expect theme).to respond_to :page_size
      (expect theme).to respond_to :base_font_family
      (expect theme).to respond_to :abstract_title_font_size
      (expect theme).to respond_to :admonition_icon_tip
      (expect theme.admonition_icon_tip).to be_a ::Hash
      (expect theme.admonition_icon_tip).to have_key :stroke_color
    end

    it 'should not replace hyphens with underscores in role names' do
      theme_data = SafeYAML.load <<~'EOS'
      role:
        flaming-red:
          font-color: ff0000
        so-very-blue:
          font:
            color: 0000ff
      EOS
      theme = subject.new.load theme_data
      (expect theme).to be_an OpenStruct
      (expect theme).to respond_to 'role_flaming-red_font_color'
      (expect theme['role_flaming-red_font_color']).to eql 'FF0000'
      (expect theme).to respond_to 'role_so-very-blue_font_color'
      (expect theme['role_so-very-blue_font_color']).to eql '0000FF'
    end

    it 'should allow role to contain uppercase characters' do
      theme_data = SafeYAML.load <<~'EOS'
      role:
        BOLD:
          font-style: bold
      EOS
      theme = subject.new.load theme_data
      (expect theme).to be_an OpenStruct
      (expect theme).to respond_to 'role_BOLD_font_style'
      (expect theme['role_BOLD_font_style']).to eql 'bold'
    end

    it 'should coerce value of keys that end in content to a string' do
      theme_data = SafeYAML.load <<~'EOS'
      menu:
        caret_content:
        - '>'
      ulist:
        marker:
          disc:
            content: 0
      footer:
        recto:
          left:
            content: true
          right:
            content: 2 * 2
      EOS
      theme = subject.new.load theme_data
      (expect theme).to be_an OpenStruct
      (expect theme.menu_caret_content).to eql '[">"]'
      (expect theme.ulist_marker_disc_content).to eql '0'
      (expect theme.footer_recto_left_content).to eql 'true'
      (expect theme.footer_recto_right_content).to eql '2 * 2'
    end

    it 'should expand variables in value of keys that end in _content' do
      theme_data = SafeYAML.load <<~'EOS'
      page:
        size: A4
      base:
        font_size: 12
      footer:
        verso:
          left:
            content: 2 * $base_font_size
          right:
            content: $page_size
      EOS
      theme = subject.new.load theme_data
      (expect theme).to be_an OpenStruct
      (expect theme.footer_verso_left_content).to eql '2 * 12'
      (expect theme.footer_verso_right_content).to eql 'A4'
    end

    it 'should allow font to be declared once for all styles using string value' do
      theme_data = SafeYAML.load <<~'EOS'
      font:
        catalog:
          Serif: /path/to/serif-font.ttf
      EOS
      theme = subject.new.load theme_data
      (expect theme.font_catalog).to be_a Hash
      (expect theme.font_catalog['Serif']).to be_a Hash
      (expect theme.font_catalog['Serif']).to have_size 4
      (expect theme.font_catalog['Serif']['normal']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['bold']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['italic']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['bold_italic']).to eql '/path/to/serif-font.ttf'
    end

    it 'should allow font to be declared once for all styles using * style' do
      theme_data = SafeYAML.load <<~'EOS'
      font:
        catalog:
          Serif:
            '*': /path/to/serif-font.ttf
      EOS
      theme = subject.new.load theme_data
      (expect theme.font_catalog).to be_a Hash
      (expect theme.font_catalog['Serif']).to be_a Hash
      (expect theme.font_catalog['Serif']).to have_size 4
      (expect theme.font_catalog['Serif']['normal']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['bold']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['italic']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['bold_italic']).to eql '/path/to/serif-font.ttf'
    end

    it 'should allow single style to be customized for font defined using * key' do
      theme_data = SafeYAML.load <<~'EOS'
      font:
        catalog:
          Serif:
            '*': /path/to/serif-font.ttf
            bold: /path/to/bold-serif-font.ttf
      EOS
      theme = subject.new.load theme_data
      (expect theme.font_catalog).to be_a Hash
      (expect theme.font_catalog['Serif']).to be_a Hash
      (expect theme.font_catalog['Serif']).to have_size 4
      (expect theme.font_catalog['Serif']['normal']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['bold']).to eql '/path/to/bold-serif-font.ttf'
      (expect theme.font_catalog['Serif']['italic']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_catalog['Serif']['bold_italic']).to eql '/path/to/serif-font.ttf'
    end

    it 'should allow regular to be used as alias for normal style when defining fonts' do
      theme_data = SafeYAML.load <<~'EOS'
      font:
        catalog:
          Serif:
            regular: /path/to/serif-regular.ttf
      EOS
      theme = subject.new.load theme_data
      (expect theme.font_catalog).to be_a Hash
      (expect theme.font_catalog['Serif']).to be_a Hash
      (expect theme.font_catalog['Serif']['normal']).to eql '/path/to/serif-regular.ttf'
    end

    it 'should allow font catalog and font fallbacks to be defined as flat keys' do
      theme_data = SafeYAML.load <<~'EOS'
      font_catalog:
        Serif:
          normal: /path/to/serif-font.ttf
        Fallback:
          normal: /path/to/fallback-font.ttf
      font_fallbacks:
      - Fallback
      EOS
      theme = subject.new.load theme_data
      (expect theme.font_catalog).to be_a Hash
      (expect theme.font_catalog['Serif']).to be_a Hash
      (expect theme.font_catalog['Serif']['normal']).to eql '/path/to/serif-font.ttf'
      (expect theme.font_fallbacks).to be_a Array
      (expect theme.font_fallbacks).to eql ['Fallback']
    end
  end

  describe '.load_file' do
    it 'should not fail if theme file is empty' do
      theme = subject.load_file fixture_file 'empty-theme.yml'
      (expect theme).to be_an OpenStruct
      (expect theme).to eql OpenStruct.new
    end

    it 'should throw error that includes filename and reason if theme is indented using tabs' do
      expect { subject.load_file fixture_file 'tab-indentation-theme.yml' }.to raise_exception RuntimeError, /tab-indentation-theme\.yml\): found character .*that cannot start any token/
    end

    it 'should load and extend themes specified by extends array' do
      input_file = fixture_file 'extended-custom-theme.yml'
      theme = subject.load_file input_file, nil, fixtures_dir
      (expect theme.base_align).to eql 'justify'
      (expect theme.base_font_family).to eql 'Times-Roman'
      (expect theme.base_font_color).to eql 'FF0000'
    end

    it 'should extend built-in default theme if value of extends entry is default' do
      input_file = fixture_file 'extended-red-theme.yml'
      theme = subject.load_file input_file, nil, fixtures_dir
      (expect theme.base_font_family).to eql 'Noto Serif'
      (expect theme.base_font_color).to eql '0000FF'
    end

    it 'should allow font catalog to be merged with font catalog from theme being extended' do
      input_file = fixture_file 'extra-fonts-theme.yml'
      theme = subject.load_file input_file, nil, fixtures_dir
      (expect theme.font_catalog).to be_a Hash
      (expect theme.font_catalog).to have_size 3
      (expect theme.font_catalog).to have_key 'Noto Serif'
      (expect theme.font_catalog).to have_key 'M+ 1mn'
      (expect theme.font_catalog['Noto Serif']).to have_size 4
      (expect theme.font_catalog['M+ 1mn']).to have_size 1
      (expect theme.font_catalog['M+ 1mn']['normal']).to eql '/path/to/mplus1mn-regular.ttf'
      (expect theme.font_catalog).to have_key 'VLGothic'
      (expect theme.font_catalog['VLGothic']).to have_size 4
      (expect theme.font_catalog['VLGothic'].values.uniq).to have_size 1
      (expect theme.font_catalog['VLGothic']['normal']).to eql '/path/to/vlgothic-regular.ttf'
      (expect theme.font_fallbacks).to be_a Array
      (expect theme.font_fallbacks).to eql ['VLGothic']
    end
  end

  describe '.load_theme' do
    it 'should load base theme if theme name is base' do
      theme = subject.load_theme 'base'
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.base_font_family).to eql 'Helvetica'
      (expect theme.literal_font_family).to eql 'Courier'
      (expect theme).to eql subject.load_base_theme
    end

    it 'should load default theme if no arguments are given' do
      theme = subject.load_theme
      (expect theme).not_to be_nil
      (expect theme).to be_an OpenStruct
      (expect theme.base_font_family).to eql 'Noto Serif'
      (expect theme.link_font_color).to eql '428BCA'
    end

    it 'should not inherit from base theme when loading default theme' do
      theme = subject.load_theme
      # NOTE: table_border_style is only set in the base theme
      (expect theme.table_border_style).to be_nil
    end

    it 'should not inherit from base theme when loading custom theme' do
      theme = subject.load_theme fixture_file 'empty-theme.yml'
      (expect theme.table_border_style).to be_nil
    end

    it 'should not inherit from base theme if custom theme extends nothing' do
      theme = subject.load_theme fixture_file 'extends-nil-empty-theme.yml'
      (expect theme.table_border_style).to be_nil
    end

    it 'should not inherit from base theme if custom theme extends default' do
      theme = subject.load_theme 'extended-default-theme.yml', fixtures_dir
      (expect theme.table_border_style).to be_nil
    end

    it 'should not inherit from base theme if custom theme extends nil' do
      theme = subject.load_theme 'extended-extends-nil-theme.yml', fixtures_dir
      (expect theme.base_font_family).to eql 'Times-Roman'
      (expect theme.heading_font_family).to eql 'Times-Roman'
      (expect theme.base_font_size).to be_nil
    end

    it 'should inherit from base theme if custom theme extends base' do
      base_theme = subject.load_base_theme
      theme = subject.load_theme fixture_file 'extended-base-theme.yml'
      (expect theme.base_font_family).not_to eql base_theme.base_font_family
      (expect theme.base_font_color).not_to eql base_theme.base_font_color
      (expect theme.base_font_size).to eql base_theme.base_font_size
    end

    it 'should look for file ending in -theme.yml when resolving custom theme' do
      theme = subject.load_theme 'custom', fixtures_dir
      (expect theme.base_font_family).to eql 'Times-Roman'
      (expect theme.__dir__).to eql fixtures_dir
    end

    it 'should set __dir__ to dirname of theme file if theme path not set' do
      theme = subject.load_theme fixture_file 'custom-theme.yml'
      (expect theme.base_font_family).to eql 'Times-Roman'
      (expect theme.__dir__).to eql fixtures_dir
    end

    it 'should load specified file ending with .yml if path is not given' do
      theme = subject.load_theme fixture_file 'custom-theme.yml'
      (expect theme.base_font_family).to eql 'Times-Roman'
    end

    it 'should load specified file ending with .yml from specified path' do
      theme = subject.load_theme 'custom-theme.yml', fixtures_dir
      (expect theme.base_font_family).to eql 'Times-Roman'
    end

    it 'should load extended themes relative to theme file when theme_path is not specified' do
      theme = subject.load_theme fixture_file 'extended-custom-theme.yml'
      (expect theme.__dir__).to eql fixtures_dir
      (expect theme.base_align).to eql 'justify'
      (expect theme.base_font_family).to eql 'Times-Roman'
      (expect theme.base_font_color).to eql 'FF0000'
    end

    it 'should ensure required keys are set in non-built-in theme' do
      theme = subject.load_theme 'extends-nil-empty-theme.yml', fixtures_dir
      (expect theme.__dir__).to eql fixtures_dir
      (expect theme.base_align).to eql 'left'
      (expect theme.base_line_height).to be 1
      (expect theme.base_font_color).to eql '000000'
      (expect theme.code_font_family).to eql 'Courier'
      (expect theme.conum_font_family).to eql 'Courier'
      (expect theme.to_h.keys).to have_size 6
    end

    it 'should link sidebar and abstract title font family to heading font family if only latter is set' do
      theme = subject.load_theme 'heading-font-family-theme.yml', fixtures_dir
      (expect theme.__dir__).to eql fixtures_dir
      (expect theme.heading_font_family).to eql 'M+ 1mn'
      (expect theme.abstract_title_font_family).to eql 'M+ 1mn'
      (expect theme.sidebar_title_font_family).to eql 'M+ 1mn'
    end

    it 'should not overwrite required keys with default values if already set' do
      theme = subject.load_theme 'extended-default-theme.yml', fixtures_dir
      (expect theme.base_align).to eql 'justify'
      (expect theme.code_font_family).to eql 'M+ 1mn'
      (expect theme.conum_font_family).to eql 'M+ 1mn'
    end
  end

  describe '.resolve_theme_file' do
    it 'should resolve built-in default theme by default' do
      expected_dir = subject::ThemesDir
      expected_path = File.join expected_dir, 'default-theme.yml'
      theme_path, theme_dir = subject.resolve_theme_file
      (expect theme_path).to eql expected_path
      (expect theme_dir).to eql expected_dir
    end

    it 'should expand reference to home directory in theme dir when resolving theme file from name' do
      expected_path = File.join home_dir, '.local/share/asciidoctor-pdf/custom-theme.yml'
      expected_dir = File.dirname expected_path
      theme_path, theme_dir = subject.resolve_theme_file 'custom', '~/.local/share/asciidoctor-pdf'
      (expect theme_path).to eql expected_path
      (expect theme_dir).to eql expected_dir
    end

    it 'should expand reference to home directory in theme dir when resolving theme file from filename' do
      expected_path = File.join home_dir, '.local/share/asciidoctor-pdf/custom-theme.yml'
      expected_dir = File.dirname expected_path
      theme_path, theme_dir = subject.resolve_theme_file 'custom-theme.yml', '~/.local/share/asciidoctor-pdf'
      (expect theme_path).to eql expected_path
      (expect theme_dir).to eql expected_dir
    end

    it 'should expand reference to home directory in theme file when resolving theme file' do
      expected_path = File.join home_dir, '.local/share/asciidoctor-pdf/custom-theme.yml'
      expected_dir = File.dirname expected_path
      theme_path, theme_dir = subject.resolve_theme_file '~/.local/share/asciidoctor-pdf/custom-theme.yml'
      (expect theme_path).to eql expected_path
      (expect theme_dir).to eql expected_dir
    end
  end

  describe '.resolve_theme_asset' do
    it 'should resolve theme asset relative to built-in themes dir by default' do
      (expect subject.resolve_theme_asset 'base-theme.yml').to eql (File.join subject::ThemesDir, 'base-theme.yml')
    end
  end

  context 'data types' do
    it 'should resolve null color value as nil' do
      theme_data = SafeYAML.load <<~'EOS'
      page:
        background_color: null
      EOS
      theme = subject.new.load theme_data
      (expect theme.page_background_color).to be_nil
    end

    it 'should resolve transparent color value' do
      theme_data = SafeYAML.load <<~'EOS'
      sidebar:
        background_color: transparent
      EOS
      theme = subject.new.load theme_data
      (expect theme.sidebar_background_color).to eql 'transparent'
      (expect theme.sidebar_background_color).to be_a subject::TransparentColorValue
    end

    it 'should expand color value to 6 hexadecimal digits' do
      {
        '0' => '000000',
        '9' => '000009',
        '000000' => '000000',
        '222' => '222222',
        '123' => '112233',
        '000011' => '000009',
        '2222' => '002222',
        '11223344' => '112233',
      }.each do |input, resolved|
        theme_data = SafeYAML.load <<~EOS
        page:
          background_color: #{input}
        EOS
        theme = subject.new.load theme_data
        (expect theme.page_background_color).to eql resolved
      end
    end

    it 'should wrap cmyk color values in color type if key ends with _color' do
      theme_data = SafeYAML.load <<~'EOS'
      page:
        background_color: [0, 0, 0, 0]
      base:
        font_color: [100, 100, 100, 100]
      heading:
        font-color: [0, 0, 0, 0.92]
      link:
        font-color: [67.33%, 31.19%, 0, 20.78%]
      literal:
        font-color: [0%, 0%, 0%, 0.87]
      EOS
      theme = subject.new.load theme_data
      (expect theme.page_background_color).to eql 'FFFFFF'
      (expect theme.page_background_color).to be_a subject::HexColorValue
      (expect theme.base_font_color).to eql '000000'
      (expect theme.base_font_color).to be_a subject::HexColorValue
      (expect theme.heading_font_color).to eql [0, 0, 0, 92]
      (expect theme.heading_font_color).to be_a subject::CMYKColorValue
      (expect theme.link_font_color).to eql [67.33, 31.19, 0, 20.78]
      (expect theme.link_font_color).to be_a subject::CMYKColorValue
      (expect theme.literal_font_color).to eql [0, 0, 0, 87]
      (expect theme.literal_font_color).to be_a subject::CMYKColorValue
    end

    it 'should wrap hex color values in color type if key ends with _color' do
      theme_data = SafeYAML.load <<~'EOS'
      page:
        background_color: 'ffffff'
      base:
        font_color: '000000'
      heading:
        font-color: 333333
      link:
        font-color: 428bca
      literal:
        font-color: 222
      EOS
      theme = subject.new.load theme_data
      (expect theme.page_background_color).to eql 'FFFFFF'
      (expect theme.page_background_color).to be_a subject::HexColorValue
      (expect theme.base_font_color).to eql '000000'
      (expect theme.base_font_color).to be_a subject::HexColorValue
      # NOTE: this assertion tests that the value can be an integer, not a string
      (expect theme.heading_font_color).to eql '333333'
      (expect theme.heading_font_color).to be_a subject::HexColorValue
      (expect theme.link_font_color).to eql '428BCA'
      (expect theme.link_font_color).to be_a subject::HexColorValue
      (expect theme.literal_font_color).to eql '222222'
      (expect theme.literal_font_color).to be_a subject::HexColorValue
    end

    it 'should coerce rgb color values to hex and wrap in color type if key ends with _color' do
      theme_data = SafeYAML.load <<~'EOS'
      page:
        background_color: [255, 255, 255]
      base:
        font_color: [0, 0, 0]
      heading:
        font-color: [51, 51, 51]
      link:
        font-color: [66, 139, 202]
      literal:
        font-color: ['34', '34', '34']
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
      (expect theme.literal_font_color).to eql '222222'
      (expect theme.literal_font_color).to be_a subject::HexColorValue
    end

    it 'should flatten array color value of unsupported length to string if key ends with _color' do
      theme_data = SafeYAML.load <<~'EOS'
      page:
        background_color: ['fff', 'fff']
      base:
        font_color: [0, 0, 0, 0, 0, 0]
      EOS
      theme = subject.new.load theme_data
      (expect theme.page_background_color).to eql 'FFFFFF'
      (expect theme.page_background_color).to be_a subject::HexColorValue
      (expect theme.base_font_color).to eql '000000'
      (expect theme.base_font_color).to be_a subject::HexColorValue
    end

    it 'should not wrap value in color type if key does not end with _color' do
      theme_data = SafeYAML.load <<~'EOS'
      menu:
        caret:
          content: 4a4a4a
      EOS
      theme = subject.new.load theme_data
      (expect theme.menu_caret_content).to eql '4a4a4a'
      (expect theme.menu_caret_content).not_to be_a subject::HexColorValue
    end

    # NOTE: this only works when the theme is read from a file
    it 'should allow hex color values to be prefixed with # for any key' do
      theme = subject.load_theme 'hex-color-shorthand', fixtures_dir
      (expect theme.base_font_color).to eql '222222'
      (expect theme.base_border_color).to eql 'DDDDDD'
      (expect theme.page_background_color).to eql 'FEFEFE'
      (expect theme.link_font_color).to eql '428BCA'
      (expect theme.literal_font_color).to eql 'AA0000'
      (expect theme.footer_font_color).to eql '000099'
      (expect theme.footer_background_color).to be_nil
    end

    # NOTE: this is only relevant when the theme is read from a file
    it 'should not coerce color-like values to string if key does not end with color' do
      theme = subject.load_theme 'color-like-value', fixtures_dir
      (expect theme.footer_height).to be 100
    end

    it 'should coerce content key to a string' do
      theme_data = SafeYAML.load <<~'EOS'
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
      (expect theme.footer_recto_right_content).to be_a String
      (expect theme.footer_recto_right_content).to eql '10'
    end

    it 'should not modify value without units' do
      [36, 36.0, 48.24, (20 / 17.0)].each do |val|
        theme_data = SafeYAML.load <<~EOS
        footer:
          padding: #{val}
        EOS
        theme = subject.new.load theme_data
        (expect theme.footer_padding).to eql val
      end
    end

    it 'should resolve value with units to PDF point value' do
      ['0.5in', '36pt', '48px', '12.7mm', '1.27cm'].each do |val|
        theme_data = SafeYAML.load <<~EOS
        footer:
          padding: #{val}
        EOS
        theme = subject.new.load theme_data
        (expect theme.footer_padding.to_f.round 2).to eql 36.0
      end
    end
  end

  context 'interpolation' do
    it 'should resolve variable reference with underscores to previously defined key' do
      theme_data = SafeYAML.load <<~'EOS'
      brand:
        blue: '0000FF'
      base:
        font_color: $brand_blue
      heading:
        font_color: $base_font_color
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_font_color).to eql '0000FF'
      (expect theme.heading_font_color).to eql theme.base_font_color
    end

    it 'should resolve variable reference with hyphens to previously defined key' do
      theme_data = SafeYAML.load <<~'EOS'
      brand:
        blue: '0000FF'
      base:
        font_color: $brand-blue
      heading:
        font_color: $base-font-color
      EOS
      theme = subject.new.load theme_data
      (expect theme.base_font_color).to eql '0000FF'
      (expect theme.heading_font_color).to eql theme.base_font_color
    end

    it 'should warn if variable reference cannot be resolved' do
      (expect do
        theme_data = SafeYAML.load <<~'EOS'
        brand:
          blue: '0000FF'
        base:
          font_color: $brand-red
        EOS
        theme = subject.new.load theme_data
        (expect theme.base_font_color).to eql '$BRAND'
      end).to log_message severity: :WARN, message: %(unknown variable reference in PDF theme: $brand-red)
    end

    it 'should interpolate variables in value' do
      theme_data = SafeYAML.load <<~'EOS'
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

    it 'should warn if variable reference cannot be resolved when interpolating value' do
      (expect do
        theme_data = SafeYAML.load <<~'EOS'
        brand:
          font_family_name: Noto
        base:
          font_family: $brand-font-family-name $brand-font-family-variant
        EOS
        theme = subject.new.load theme_data
        (expect theme.base_font_family).to eql 'Noto $brand-font-family-variant'
      end).to log_message severity: :WARN, message: %(unknown variable reference in PDF theme: $brand-font-family-variant)
    end

    it 'should interpolate computed value' do
      theme_data = SafeYAML.load <<~'EOS'
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

    it 'should allow numeric value with units to be negative' do
      theme_data = SafeYAML.load <<~'EOS'
      footer:
        padding: [0, -0.67in, 0, -0.67in]
      EOS
      theme = subject.new.load theme_data
      (expect theme.footer_padding).to eql [0, -48.24, 0, -48.24]
    end

    it 'should not compute value if operator is not surrounded by spaces on either side' do
      theme_data = SafeYAML.load <<~'EOS'
      brand:
        ten: 10
        a_string: ten*10
        another_string: ten-10
      EOS

      theme = subject.new.load theme_data
      (expect theme.brand_ten).to be 10
      (expect theme.brand_a_string).to eql 'ten*10'
      (expect theme.brand_another_string).to eql 'ten-10'
    end

    it 'should apply precision functions to value' do
      theme_data = SafeYAML.load <<~'EOS'
      base:
        font_size: 10.5
      heading:
        h1_font_size: ceil($base_font_size * 2.6)
        h2_font_size: floor($base_font_size * 2.1)
        h3_font_size: round($base_font_size * 1.5)
      EOS
      theme = subject.new.load theme_data
      (expect theme.heading_h1_font_size).to be 28
      (expect theme.heading_h2_font_size).to be 22
      (expect theme.heading_h3_font_size).to be 16
    end

    it 'should resolve variable references in font catalog' do
      theme_data = SafeYAML.load <<~'EOS'
      vars:
        serif-font: /path/to/serif-font.ttf
      font:
        catalog:
          Serif:
            normal: $vars-serif-font
      EOS
      theme = subject.new.load theme_data
      (expect theme.font_catalog).to be_a Hash
      (expect theme.font_catalog['Serif']).to be_a Hash
      (expect theme.font_catalog['Serif']['normal']).to eql '/path/to/serif-font.ttf'
    end
  end
end
