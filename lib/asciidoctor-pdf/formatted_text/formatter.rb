module Asciidoctor
module Pdf
module FormattedText
class Formatter
  FormattingSnifferPattern = /[<&]/

  def initialize options = {}
    @parser = MarkupParser.new
    @transform = Transform.new merge_adjacent_text_nodes: true, theme: options[:theme]
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
end
