module Asciidoctor
module Pdf
module FormattedText
class Formatter
  FormattingSnifferPattern = /[<&]/
  WHITESPACE = " \t\n"

  def initialize options = {}
    @parser = MarkupParser.new
    @transform = Transform.new merge_adjacent_text_nodes: true, theme: options[:theme]
  end

  def format string, *args
    options = args[0] || {}
    string = string.tr_s(WHITESPACE, ' ') if options[:normalize]
    return [text: string] unless string.match(FormattingSnifferPattern)
    if (parsed = @parser.parse(string))
      @transform.apply(parsed.content)
    else
      warn %(Failed to parse formatted text: #{string})
      [text: string]
    end
  end
end
end
end
end
