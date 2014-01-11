require 'yaml'
require 'ostruct'

if RUBY_VERSION < '2'
  class OpenStruct
    def [] key
      send key
    end

    def []= key, val
      send %(#{key}=), val
    end
  end
end

module Asciidoctor
class ThemeLoader

  def self.load_file filename
    theme_hash = YAML.load_file filename
    self.new.load theme_hash
  end

  def load hash
    hash.inject(OpenStruct.new) do |s, (k, v)|
      if v.kind_of? Hash
        v.each do |k2, v2|
          s[%(#{k}_#{k2})] = (k2.end_with? '_color') ? evaluate(v2, s).to_s : evaluate(v2, s)
        end
      else
        s[k] = (k.end_with? '_color') ? evaluate(v, s).to_s : evaluate(v, s)
      end
      s
    end
  end

  private

  def evaluate expr, vars
    if expr.kind_of? String
      evaluate_math(expand_vars(expr, vars))
    else
      expr
    end
  end
  
  def expand_vars expr, vars
    if expr.include? '$'
      if (expr.start_with? '$') && (expr.match /^\$([a-z0-9_]+)$/)
        vars[$1]
      else
        expr.gsub(/\$([a-z0-9_]+)/) { vars[$1] }
      end
    else
      expr
    end
  end
  
  def evaluate_math expr
    return expr unless expr.kind_of? String
    original = expr
    while true
      result = expr.gsub(/(-?\d+(?:\.\d+)?) *([*\/]) *(-?\d+(?:\.\d+)?)/) { $1.to_f.send($2.to_sym, $3.to_f) }
      unchanged = (result == expr)
      expr = result
      break if unchanged
    end
    while true
      result = expr.gsub(/(-?\d+(?:\.\d+)?) *([+\-]) *(-?\d+(?:\.\d+)?)/) { $1.to_f.send($2.to_sym, $3.to_f) }
      unchanged = (result == expr)
      expr = result
      break if unchanged
    end
    if (expr.end_with? ')') && (expr.match /^(round|floor|ceil)\(/)
      op = $1
      offset = op.length + 1
      expr = expr[offset...-1].to_f.send(op.to_sym)
    end
    if original == expr
      expr
    else
      if ((int_val = expr.to_i) == (float_val = expr.to_f))
        int_val
      else
        float_val
      end
    end
  end
end
end
