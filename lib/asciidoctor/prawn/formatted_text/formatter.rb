require 'treetop'
require 'set'
require_relative 'parser'
require_relative 'transform'

module Asciidoctor
module Prawn
class FormattedTextFormatter
  FormattingSnifferPattern = /[<&]/

  def initialize options = {}
    @parser = FormattedTextParser.new
    @transform = FormattedTextTransform.new merge_adjacent_text_nodes: true, theme: options[:theme]
  end

  def format string, *args
    options = args.first || {}
    string = string.tr_s("\n", ' ') if options[:normalize]
    return [text: string] unless string.match(FormattingSnifferPattern)
    if (parsed = @parser.parse(string)) == nil
      warn %(Failed to parse formatted text: #{string})
      [text: string]
    else
      @transform.apply(parsed.content)
    end
  end
end
end
end
