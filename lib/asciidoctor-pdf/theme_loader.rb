require 'safe_yaml/load'
require 'ostruct'
require_relative 'core_ext/ostruct'

module Asciidoctor
module Pdf
class ThemeLoader
  DataDir = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', '..', 'data'))
  ThemesDir = ::File.join DataDir, 'themes'
  FontsDir = ::File.join DataDir, 'fonts'
  DefaultThemePath = ::File.expand_path 'default-theme.yml', ThemesDir
  BaseThemePath = ::File.expand_path 'base-theme.yml', ThemesDir

  VariableRx = /\$([a-z0-9_]+)/
  LoneVariableRx = /^\$([a-z0-9_]+)$/
  HexColorValueRx = /[_-]color: (?<quote>"|'|)#?(?<value>[A-Za-z0-9]{3,6})\k<quote>$/
  MeasurementValueRx = /(?<=^| |\()(\d+(?:\.\d+)?)(in|mm|cm|pt)(?=$| |\))/
  MultiplyDivideOpRx = /(-?\d+(?:\.\d+)?) *([*\/]) *(-?\d+(?:\.\d+)?)/
  AddSubtractOpRx = /(-?\d+(?:\.\d+)?) *([+\-]) *(-?\d+(?:\.\d+)?)/
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
      # QUESTION should we do any post-load calculations or defaults?
      load_file theme_file, theme_data
    end
  end

  def self.load_file filename, theme_data = nil
    raw_data = (::IO.read filename).each_line.map {|l| l.sub HexColorValueRx, '_color: \'\k<value>\'' }.join
    self.new.load((::SafeYAML.load raw_data), theme_data)
  end

  def load hash, theme_data = nil
    theme_data ||= ::OpenStruct.new
    hash.inject(theme_data) {|data, (key, val)| process_entry key, val, data }
  end

  private

  def process_entry key, val, data
    if key != 'font_catalog' && ::Hash === val
      val.each do |key2, val2|
        process_entry %(#{key}_#{key2.tr '-', '_'}), val2, data
      end
    else
      data[key] = (key.end_with? '_color') ? to_color(evaluate val, data) : (evaluate val, data)
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
    original = expr
    # FIXME quick HACK to turn a single negative number into an expression
    expr = %(1 - #{expr[1..-1]}) if expr.start_with? '-'
    # expand measurement values (e.g., 0.5in)
    expr = expr.gsub(MeasurementValueRx) {
      # TODO extract to_pt method and use it here
      val = $1.to_f
      case $2
      when 'in'
        val = val * 72
      when 'mm'
        val = val * (72 / 25.4)
      when 'cm'
        val = val * (720 / 25.4)
      #when '%'
      #  val = val / 100.0
      # default is pt
      end
      # QUESTION should we round the value?
      val
    }
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
      value = %(#{value})
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
