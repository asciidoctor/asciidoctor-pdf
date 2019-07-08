require 'safe_yaml/load'
require 'ostruct'
require_relative 'core_ext/ostruct'
require_relative 'measurements'

module Asciidoctor
module PDF
class ThemeLoader
  include ::Asciidoctor::PDF::Measurements
  if defined? ::Asciidoctor::Logging
    include ::Asciidoctor::Logging
  else
    include ::Asciidoctor::LoggingShim
  end

  DataDir = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', 'data'))
  ThemesDir = ::File.join DataDir, 'themes'
  FontsDir = ::File.join DataDir, 'fonts'
  DefaultThemePath = ::File.expand_path 'default-theme.yml', ThemesDir
  BaseThemePath = ::File.expand_path 'base-theme.yml', ThemesDir

  VariableRx = /\$([a-z0-9_-]+)/
  LoneVariableRx = /^\$([a-z0-9_-]+)$/
  HexColorEntryRx = /^(?<k> *\p{Graph}+): +(?!null$)(?<q>["']?)(?<h>#)?(?<v>[a-f0-9]{3,6})\k<q> *(?:#.*)?$/
  MultiplyDivideOpRx = /(-?\d+(?:\.\d+)?) +([*\/]) +(-?\d+(?:\.\d+)?)/
  AddSubtractOpRx = /(-?\d+(?:\.\d+)?) +([+\-]) +(-?\d+(?:\.\d+)?)/
  PrecisionFuncRx = /^(round|floor|ceil)\(/

  # TODO implement white? & black? methods
  module ColorValue; end

  class HexColorValue < String
    include ColorValue
  end

  # A marker module for a normalized CMYK array
  # Prevents normalizing CMYK value more than once
  module CMYKColorValue
    include ColorValue
    def to_s
      %([#{join ', '}])
    end
  end

  def self.resolve_theme_file theme_name = nil, theme_path = nil
    # if .yml extension is given, assume it's a path (don't append -theme.yml)
    if ((theme_name ||= 'default').end_with? '.yml')
      # FIXME restrict to jail!
      theme_file = ::File.expand_path theme_name, theme_path
      theme_path ||= ::File.dirname theme_file
    else
      theme_file = ::File.expand_path %(#{theme_name}-theme.yml), (theme_path || (theme_path = ThemesDir))
    end
    [theme_file, theme_path]
  end

  def self.resolve_theme_asset asset_path, theme_path
    ::File.expand_path asset_path, (theme_path || ThemesDir)
  end

  # NOTE base theme is loaded "as is" (no post-processing)
  def self.load_base_theme
    (::OpenStruct.new ::SafeYAML.load_file BaseThemePath).tap {|theme| theme.__dir__ = ThemesDir }
  end

  def self.load_theme theme_name = nil, theme_path = nil
    theme_file, theme_path = resolve_theme_file theme_name, theme_path
    if theme_file == BaseThemePath
      load_base_theme
    else
      theme_data = load_file theme_file, nil, theme_path
      unless theme_file == DefaultThemePath
        # QUESTION should we enforce any other fallback values?
        theme_data.base_align ||= 'left'
        theme_data.code_font_family ||= (theme_data.literal_font_family || 'Courier')
        theme_data.conum_font_family ||= (theme_data.literal_font_family || 'Courier')
      end
      theme_data.__dir__ = theme_path
      theme_data
    end
  end

  def self.load_file filename, theme_data = nil, theme_path = nil
    data = ::File.read filename, encoding: ::Encoding::UTF_8
    data = data.each_line.map {|l|
      l.sub(HexColorEntryRx) { %(#{(m = $~)[:k]}: #{m[:h] || (m[:k].end_with? 'color') ? "'#{m[:v]}'" : m[:v]}) }
    }.join unless filename == DefaultThemePath
    yaml_data = ::SafeYAML.load data
    if ::Hash === yaml_data && (yaml_data.key? 'extends')
      if (extends = yaml_data.delete 'extends')
        [*extends].each do |extend_file|
          if extend_file == 'base'
            theme_data = theme_data ? (::OpenStruct.new theme_data.to_h.merge load_base_theme.to_h) : load_base_theme
            next
          elsif extend_file == 'default' || extend_file == 'default-with-fallback-font'
            extend_file, extend_theme_path = resolve_theme_file extend_file
          elsif extend_file.start_with? './'
            extend_file, extend_theme_path = resolve_theme_file extend_file, (::File.dirname filename)
          else
            extend_file, extend_theme_path = resolve_theme_file extend_file, theme_path
          end
          theme_data = load_file extend_file, theme_data, extend_theme_path
        end
      end
    else
      theme_data ||= (filename == DefaultThemePath ? nil : load_base_theme)
    end
    self.new.load yaml_data, theme_data, theme_path
  end

  def load hash, theme_data = nil, theme_path = nil
    ::Hash === hash ? hash.reduce(theme_data || ::OpenStruct.new) {|data, (key, val)| process_entry key, val, data } : (theme_data || ::OpenStruct.new)
  end

  private

  def process_entry key, val, data
    key = key.tr '-', '_' if key.include? '-'
    if key == 'font_catalog' || key == 'font_fallbacks'
      data[key] = val
    elsif key.start_with? 'admonition_icon_'
      data[key] = (val || {}).map do |(key2, val2)|
        [key2.to_sym, (key2.end_with? '_color') ? to_color(evaluate val2, data) : (evaluate val2, data)]
      end.to_h
    elsif ::Hash === val
      val.each {|subkey, subval| process_entry %(#{key}_#{subkey}), subval, data }
    elsif key.end_with? '_color'
      # QUESTION do we really need to evaluate_math in this case?
      data[key] = to_color(evaluate val, data)
    elsif %(#{key.chomp '_'}_).include? '_content_'
      data[key] = (expand_vars val.to_s, data).to_s
    else
      data[key] = evaluate val, data
    end
    data
  end

  def evaluate expr, vars
    case expr
    when ::String
      evaluate_math(expand_vars expr, vars)
    when ::Array
      expr.map {|e| evaluate e, vars }
    else
      expr
    end
  end

  # NOTE we assume expr is a String
  def expand_vars expr, vars
    if (idx = (expr.index '$'))
      if idx == 0 && expr =~ LoneVariableRx
        if (key = $1).include? '-'
          key = key.tr '-', '_'
        end
        if vars.respond_to? key
          vars[key]
        else
          logger.warn %(unknown variable reference in PDF theme: $#{$1})
          expr
        end
      else
        expr.gsub(VariableRx) do
          if (key = $1).include? '-'
            key = key.tr '-', '_'
          end
          if vars.respond_to? key
            vars[key]
          else
            logger.warn %(unknown variable reference in PDF theme: $#{$1})
            $&
          end
        end
      end
    else
      expr
    end
  end

  def evaluate_math expr
    return expr if !(::String === expr) || ColorValue === expr
    # resolve measurement values (e.g., 0.5in => 36)
    # QUESTION should we round the value? perhaps leave that to the precision functions
    # NOTE leave % as a string; handled by converter for now
    expr = resolve_measurement_values(original = expr)
    while true
      if (expr.count '*/') > 0
        result = expr.gsub(MultiplyDivideOpRx) { $1.to_f.send $2.to_sym, $3.to_f }
        unchanged = (result == expr)
        expr = result
        break if unchanged
      else
        break
      end
    end
    while true
      if (expr.count '+-') > 0
        result = expr.gsub(AddSubtractOpRx) { $1.to_f.send $2.to_sym, $3.to_f }
        unchanged = (result == expr)
        expr = result
        break if unchanged
      else
        break
      end
    end
    if (expr.end_with? ')') && expr =~ PrecisionFuncRx
      op = $1
      offset = op.length + 1
      expr = expr[offset...-1].to_f.send op.to_sym
    end
    if expr == original
      original
    else
      (int_val = expr.to_i) == (flt_val = expr.to_f) ? int_val : flt_val
    end
  end

  def to_color value
    case value
    when ColorValue
      # already converted
      return value
    when ::Array
      case value.length
      # CMYK value
      when 4
        value = value.map do |e|
          if ::Numeric === e
            e = e * 100.0 unless e > 1
          else
            e = e.to_s.chomp('%').to_f
          end
          e == (int_e = e.to_i) ? int_e : e
        end
        case value
        when [0, 0, 0, 0]
          return HexColorValue.new 'FFFFFF'
        when [100, 100, 100, 100]
          return HexColorValue.new '000000'
        else
          value.extend CMYKColorValue
          return value
        end
      # RGB value
      when 3
        return HexColorValue.new value.map {|e| '%02X' % e }.join
      # Nonsense array value; flatten to string
      else
        value = value.join
      end
    when ::String
      if value == 'transparent'
        # FIXME should we have a TransparentColorValue class?
        return HexColorValue.new value
      elsif value.length == 6
        return HexColorValue.new value.upcase
      end
    when ::NilClass
      return nil
    else
      # Unknown type (usually Integer); coerce to String
      if (value = value.to_s).length == 6
        return HexColorValue.new value.upcase
      end
    end
    value = case value.length
    when 6
      value
    when 3
      # expand hex shorthand (e.g., f00 -> ff0000)
      value.each_char.map {|c| c * 2 }.join
    else
      # truncate or pad with leading zeros (e.g., ff -> 0000ff)
      value[0..5].rjust 6, '0'
    end
    HexColorValue.new value.upcase
  end
end
end
end
