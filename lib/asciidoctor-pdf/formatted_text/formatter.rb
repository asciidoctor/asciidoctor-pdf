module Asciidoctor
module PDF
module FormattedText
class Formatter
  if defined? ::Asciidoctor::Logging
    include ::Asciidoctor::Logging
  else
    include ::Asciidoctor::LoggingShim
  end

  FormattingSnifferPattern = /[<&]/
  WHITESPACE = " \t\n"

  def initialize options = {}
    @parser = MarkupParser.new
    @transform = Transform.new merge_adjacent_text_nodes: true, theme: options[:theme]
  end

  def format string, *args
    options = args[0] || {}
    string = string.tr_s(WHITESPACE, ' ') if options[:normalize]
    return [text: string] unless FormattingSnifferPattern.match? string
    if (parsed = @parser.parse(string))
      @transform.apply(parsed.content)
    else
      logger.error %(failed to parse formatted text: #{string})
      [text: string]
    end
  end

  # The original purpose of this method is to split paragraphs, but our formatter only works on paragraphs that have
  # been presplit. Therefore, we just need to wrap the fragments in a single-element array (representing a single
  # paragraph) and return them.
  def array_paragraphs fragments
    [fragments]
  end
end
end
end
end
