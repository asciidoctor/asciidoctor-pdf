require 'safe_yaml/load'
require 'ostruct'
require_relative 'core_ext/ostruct'
require_relative 'measurements'

module Asciidoctor
module Pdf
class ThemeLoader
  include ::Asciidoctor::Pdf::Measurements

  DataDir = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', 'data'))
  ThemesDir = ::File.join DataDir, 'themes'
  FontsDir = ::File.join DataDir, 'fonts'
  DefaultThemePath = ::File.expand_path 'default-theme.yml', ThemesDir
  BaseThemePath = ::File.expand_path 'base-theme.yml', ThemesDir

  VariableRx = /\$([a-z0-9_]+)/
  LoneVariableRx = /^\$([a-z0-9_]+)$/
  HexColorEntryRx = /^(?<k>[[:blank:]]*[[:graph:]]+): +(?!null$)(?<q>["']?)#?(?<v>\w{3,6})\k<q> *(?:#.*)?$/
  MeasurementValueRx = /(?<=^| |\()(-?\d+(?:\.\d+)?)(in|mm|cm|p[txc])(?=$| |\))/
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
  module CmykColorValue
    include ColorValue
    def to_s
      %([#{join ', '}])
    end
  end

  def self.resolve_theme_file theme_name = nil, theme_path = nil
    theme_name ||= 'default'
    # if .yml extension is given, assume it's a full file name
    if (theme_name.end_with? '.yml')
      # FIXME restrict to jail!
      # QUESTION why are we not using expand_path in this case?
      theme_path ? (::File.join theme_path, theme_name) : theme_name
    else
      # QUESTION should we append '-theme.yml' or just '.yml'?
      ::File.expand_path %(#{theme_name}-theme.yml), (theme_path || ThemesDir)
    end
  end

  def self.resolve_theme_asset asset_path, theme_path = nil
    ::File.expand_path asset_path, (theme_path || ThemesDir)
  end

  # NOTE base theme is loaded "as is" (no post-processing)
  def self.load_base_theme
    ::OpenStruct.new(::SafeYAML.load_file BaseThemePath)
  end

  def self.load_theme theme_name = nil, theme_path = nil, opts = {}
    if (theme_file = resolve_theme_file theme_name, theme_path) == BaseThemePath ||
        (theme_file != DefaultThemePath && (opts.fetch :apply_base_theme, true))
      theme_data = load_base_theme
    else
      theme_data = nil
    end

    if theme_file == BaseThemePath
      theme_data
    else
      load_file theme_file, theme_data
    end
  end

  def self.load_file filename, theme_data = nil
    raw_data = (::IO.read filename, encoding: ::Encoding::UTF_8).each_line.map {|l| l.sub HexColorEntryRx, '\k<k>: \'\k<v>\'' }.join
    self.new.load((::SafeYAML.load raw_data), theme_data)
  end

  def load hash, theme_data = nil
    theme_data ||= ::OpenStruct.new
    return theme_data unless ::Hash === hash
    hash.inject(theme_data) {|data, (key, val)| process_entry key, val, data }
    # NOTE remap legacy running content keys (e.g., header_recto_content_left => header_recto_left_content)
    %w(header_recto header_verso footer_recto footer_verso).each do |periphery_face|
      %w(left center right).each do |align|
        if (val = theme_data.delete %(#{periphery_face}_content_#{align}))
          theme_data[%(#{periphery_face}_#{align}_content)] = val
        end
      end
    end
    theme_data.base_align ||= 'left'
    # QUESTION should we do any other post-load calculations or defaults?
    theme_data
  end

  private

  def process_entry key, val, data
    if key.start_with? 'font_'
      data[key] = val
    elsif key.start_with? 'admonition_icon_'
      data[key] = (val || {}).map do |(key2, val2)|
        [key2.to_sym, (key2.end_with? '_color') ? to_color(evaluate val2, data) : (evaluate val2, data)]
      end.to_h
    elsif ::Hash === val
      val.each do |key2, val2|
        process_entry %(#{key}_#{key2.tr '-', '_'}), val2, data
      end
    elsif key.end_with? '_color'
      # QUESTION do we need to evaluate_math in this case?
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
        vars[$1]
      else
        expr.gsub(VariableRx) { vars[$1] }
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
      result = expr.gsub(MultiplyDivideOpRx) { $1.to_f.send $2.to_sym, $3.to_f }
      unchanged = (result == expr)
      expr = result
      break if unchanged
    end
    while true
      result = expr.gsub(AddSubtractOpRx) { $1.to_f.send $2.to_sym, $3.to_f }
      unchanged = (result == expr)
      expr = result
      break if unchanged
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
    when ::String
      if value == 'transparent'
        # FIXME should we have a TransparentColorValue class?
        return HexColorValue.new value
      elsif value.size == 6
        return HexColorValue.new value.upcase
      end
    when ::Array
      case value.size
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
          value.extend CmykColorValue
          return value
        end
      # RGB value
      when 3
        return HexColorValue.new value.map {|e| '%02X' % e}.join
      # Nonsense array value; flatten to string
      else
        value = value.join
      end
    else
      # Unknown type; coerce to a string
      value = value.to_s
    end
    value = case value.size
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
