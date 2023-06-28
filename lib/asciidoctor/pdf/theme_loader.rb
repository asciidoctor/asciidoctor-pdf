# frozen_string_literal: true

require 'ostruct'
require_relative 'measurements'

module Asciidoctor
  module PDF
    class ThemeLoader
      include ::Asciidoctor::PDF::Measurements
      include ::Asciidoctor::Logging

      DataDir = ::File.absolute_path %(#{__dir__}/../../../data)
      ThemesDir = ::File.join DataDir, 'themes'
      FontsDir = ::File.join DataDir, 'fonts'
      BaseThemePath = ::File.join ThemesDir, 'base-theme.yml'
      BundledThemeNames = (::Dir.children ThemesDir).map {|it| it.slice 0, it.length - 10 }
      DeprecatedCategoryKeys = { 'blockquote' => 'quote', 'key' => 'kbd', 'literal' => 'codespan', 'outline_list' => 'list' }
      DeprecatedKeys = { 'table_caption_side' => 'table_caption_end' }.tap {|accum| %w(base heading heading_h1 heading_h2 heading_h3 heading_h4 heading_h5 heading_h6 title_page abstract abstract_title admonition_label sidebar_title toc_title).each {|prefix| accum[%(#{prefix}_align)] = %(#{prefix}_text_align) } }
      PaddingBottomHackKeys = %w(example_padding quote_padding sidebar_padding verse_padding)

      VariableRx = /\$([a-z0-9_-]+)/
      LoneVariableRx = /^\$([a-z0-9_-]+)$/
      HexColorEntryRx = /^(?<k> *\p{Graph}+): +(?!null$)(?<q>["']?)(?<h>#)?(?<v>\h\h\h\h{0,3})\k<q> *(?:#.*)?$/
      MultiplyDivideOpRx = %r((-?\d+(?:\.\d+)?) +([*/^]) +(-?\d+(?:\.\d+)?))
      AddSubtractOpRx = /(-?\d+(?:\.\d+)?) +([+-]) +(-?\d+(?:\.\d+)?)/
      PrecisionFuncRx = /^(round|floor|ceil)\(/
      RoleAlignKeyRx = /(?:_text)?_align$/

      module ColorValue; end

      # A marker module for a normalized CMYK array
      # Prevents normalizing CMYK value more than once
      module CMYKColorValue
        include ColorValue
        def to_s
          %([#{join ', '}])
        end
      end

      class HexColorValue < String
        include ColorValue
      end

      class TransparentColorValue < String
        include ColorValue
      end

      def self.resolve_theme_file theme_name = nil, theme_dir = nil
        # NOTE: if .yml extension is given, assume it's a path (don't append -theme.yml)
        if theme_name&.end_with? '.yml'
          # FIXME: restrict to jail!
          if theme_dir
            theme_path = ::File.absolute_path theme_name, (theme_dir = ::File.expand_path theme_dir)
          else
            theme_path = ::File.expand_path theme_name
            theme_dir = ::File.dirname theme_path
          end
        else
          theme_dir = theme_dir ? (::File.expand_path theme_dir) : ThemesDir
          theme_path = ::File.absolute_path ::File.join theme_dir, %(#{theme_name || 'default'}-theme.yml)
        end
        [theme_path, theme_dir]
      end

      def self.resolve_theme_asset asset_path, theme_dir = nil
        ::File.absolute_path asset_path, (theme_dir || ThemesDir)
      end

      # NOTE: base theme is loaded "as is" (no post-processing)
      def self.load_base_theme
        ::File.open BaseThemePath, mode: 'r:UTF-8' do |io|
          (::OpenStruct.new ::YAML.safe_load io, filename: BaseThemePath).tap {|theme| theme.__dir__ = ThemesDir }
        end
      end

      def self.load_theme theme_name = nil, theme_dir = nil
        theme_path, theme_dir = resolve_theme_file theme_name, theme_dir
        if theme_path == BaseThemePath
          load_base_theme
        else
          theme_data = load_file theme_path, (::OpenStruct.new base_font_size: 12), theme_dir
          unless (::File.dirname theme_path) == ThemesDir
            theme_data.base_text_align ||= 'left'
            theme_data.base_line_height ||= 1
            theme_data.base_font_color ||= '000000'
            theme_data.code_font_family ||= (theme_data.codespan_font_family || 'Courier')
            theme_data.conum_font_family ||= (theme_data.codespan_font_family || 'Courier')
            if (heading_font_family = theme_data.heading_font_family)
              theme_data.abstract_title_font_family ||= heading_font_family
              theme_data.sidebar_title_font_family ||= heading_font_family
            end
          end
          theme_data.delete_field :__loaded__
          theme_data.__dir__ = theme_dir
          theme_data
        end
      end

      def self.load_file filename, theme_data = nil, theme_dir = nil
        data = ::File.read filename, mode: 'r:UTF-8', newline: :universal
        data = data.each_line.map do |line|
          line.sub(HexColorEntryRx) { %(#{(m = $~)[:k]}: #{m[:h] || (m[:k].end_with? 'color') ? "'#{m[:v]}'" : m[:v]}) }
        end.join unless (::File.dirname filename) == ThemesDir
        yaml_data = ::YAML.safe_load data, aliases: true, filename: filename
        (loaded = (theme_data ||= ::OpenStruct.new).__loaded__ ||= ::Set.new).add filename
        if ::Hash === yaml_data && (extends = yaml_data.delete 'extends')
          (Array extends).each do |extend_path|
            extend_path = extend_path.slice 0, extend_path.length - 11 if (force = extend_path.end_with? ' !important')
            if extend_path == 'base'
              theme_data = ::OpenStruct.new theme_data.to_h.merge load_base_theme.to_h if (loaded.add? 'base') || force
              next
            elsif BundledThemeNames.include? extend_path
              extend_path, extend_theme_dir = resolve_theme_file extend_path, ThemesDir
            elsif extend_path.start_with? './'
              extend_path, extend_theme_dir = resolve_theme_file extend_path, (::File.dirname filename)
            else
              extend_path, extend_theme_dir = resolve_theme_file extend_path, theme_dir
            end
            theme_data = load_file extend_path, theme_data, extend_theme_dir if (loaded.add? extend_path) || force
          end
        end
        new.load yaml_data, theme_data
      end

      def load hash, theme_data = nil
        ::Hash === hash ? hash.reduce(theme_data || ::OpenStruct.new) {|data, (key, val)| process_entry key, val, data, true } : (theme_data || ::OpenStruct.new)
      end

      private

      def process_entry key, val, data, normalize_key = false
        key = key.tr '-', '_' if normalize_key && (key.include? '-')
        if key == 'font'
          val.each do |subkey, subval|
            process_entry %(#{key}_#{subkey}), subval, data if subkey == 'catalog' || subkey == 'fallbacks'
          end if ::Hash === val
        elsif key == 'font_catalog'
          data[key] = ::Hash === val ? (val.reduce (val.delete 'merge') ? data[key] || {} : {} do |accum, (name, styles)| # rubocop:disable Style/EachWithObject
            styles = { '*' => styles } if ::String === styles
            accum[name] = styles.reduce({}) do |subaccum, (style, path)| # rubocop:disable Style/EachWithObject
              if (path.start_with? 'GEM_FONTS_DIR') && (sep = path[13])
                path = %(#{FontsDir}#{sep}#{path.slice 14, path.length})
              end
              expanded_path = expand_vars path, data
              case style
              when '*'
                %w(normal bold italic bold_italic).map {|it| subaccum[it] = expanded_path }
              when 'regular'
                subaccum['normal'] = expanded_path
              else
                subaccum[style] = expanded_path
              end
              subaccum
            end if ::Hash === styles
            accum
          end) : nil
        elsif key == 'font_fallbacks'
          data[key] = ::Array === val ? val.map {|name| expand_vars name.to_s, data } : []
        elsif key.start_with? 'admonition_icon_'
          data[key] = {}.tap do |accum|
            val.each do |key2, val2|
              key2 = key2.tr '-', '_' if key2.include? '-'
              accum[key2.to_sym] = (key2.end_with? '_color') ? (to_color evaluate val2, data, math: false) : (evaluate val2, data)
            end
          end if val
        elsif ::Hash === val
          if (rekey = DeprecatedCategoryKeys[key])
            logger.warn %(the #{key.tr '_', '-'} theme category is deprecated; use the #{rekey.tr '_', '-'} category instead)
            key = rekey
          end
          val.each do |subkey, subval|
            process_entry %(#{key}_#{key == 'role' || !(subkey.include? '-') ? subkey : (subkey.tr '-', '_')}), subval, data
          end
        elsif (rekey = DeprecatedKeys[key]) ||
            ((key.start_with? 'role_') && (key.end_with? '_align') && (rekey = key.sub RoleAlignKeyRx, '_text_align'))
          data[rekey] = evaluate val, data, math: false
        elsif PaddingBottomHackKeys.include? key
          val = evaluate val, data
          # normalize padding hacks for themes designed before the converter had smart margins
          val[2] = val[0] if ::Array === val && val[0].to_f >= 0 && val[2].to_f <= 0
          data[key] = val
        elsif key.end_with? '_color'
          # assume table_grid_color is a single color unless the value is a 2-element array for backwards compatibility
          if key == 'table_border_color' ? ::Array === val : (key == 'table_grid_color' && ::Array === val && val.size == 2)
            data[key] = val.map {|it| to_color evaluate it, data, math: false }
          else
            data[key] = to_color evaluate val, data, math: false
          end
        elsif key.end_with? '_content'
          data[key] = (expand_vars val.to_s, data).to_s
        else
          data[key] = evaluate val, data
        end
        data
      end

      def evaluate expr, vars, math: true
        case expr
        when ::String
          math ? (evaluate_math expand_vars expr, vars) : (expand_vars expr, vars)
        when ::Array
          expr.map {|e| evaluate e, vars, math: math }
        else
          expr
        end
      end

      # NOTE: we assume expr is a String
      def expand_vars expr, vars
        return expr unless (idx = expr.index '$')
        if idx == 0
          return resolve_var vars, expr, $1 if expr =~ LoneVariableRx
        elsif idx == 1 && expr.chr == '-' && (negated_expr = expr.slice 1, expr.length) =~ LoneVariableRx
          return Numeric === (val = resolve_var vars, negated_expr, $1) ? -val : '-' + val
        end
        expr.gsub(VariableRx) { resolve_var vars, $&, $1 }
      end

      def resolve_var vars, ref, var
        var = var.tr '-', '_' if var.include? '-'
        if (vars.respond_to? var) ||
            DeprecatedCategoryKeys.any? {|old, new| (var.start_with? old + '_') && (vars.respond_to? (replace = new + (var.slice old.length, var.length))) && (var = replace) } ||
            ((replace = DeprecatedKeys[var]) && (vars.respond_to? replace) && (var = replace))
          vars[var]
        else
          logger.warn %(unknown variable reference in PDF theme: #{ref})
          ref
        end
      end

      def evaluate_math expr
        return expr if !(::String === expr) || ColorValue === expr
        # resolve measurement values (e.g., 0.5in => 36)
        # NOTE: leave % as a string; handled by converter for now
        original, expr = expr, (resolve_measurement_values expr)
        while true
          if (expr.count '*/^') > 0
            result = expr.gsub(MultiplyDivideOpRx) { $1.to_f.send ($2 == '^' ? '**' : $2).to_sym, $3.to_f }
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
          offset = (op = $1).length + 1
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
                e *= 100.0 unless e > 1
              else
                e = (e.to_s.chomp '%').to_f
              end
              e == (int_e = e.to_i) ? int_e : e
            end
            case value
            when [0, 0, 0, 0]
              return HexColorValue.new 'FFFFFF'
            when [100, 100, 100, 100]
              return HexColorValue.new '000000'
            else
              return value.extend CMYKColorValue
            end
          # RGB value
          when 3
            return HexColorValue.new value.map {|e| sprintf '%02X', e }.join
          # Nonsense array value; flatten to string
          else
            value = value.join
          end
        when ::String
          if value == 'transparent'
            return TransparentColorValue.new value
          elsif value.length == 6
            return HexColorValue.new value.upcase
          end
        when ::NilClass
          return
        else
          # Unknown type (usually Integer); coerce to String
          if (value = value.to_s).length == 6
            return HexColorValue.new value.upcase
          end
        end
        case value.length
        when 6
          resolved_value = value
        when 3
          # expand hex shorthand (e.g., f00 -> ff0000)
          resolved_value = value.each_char.map {|c| c * 2 }.join
        else
          # truncate or pad with leading zeros (e.g., ff -> 0000ff)
          resolved_value = (value.slice 0, 6).rjust 6, '0'
        end
        HexColorValue.new resolved_value.upcase
      end
    end
  end
end
