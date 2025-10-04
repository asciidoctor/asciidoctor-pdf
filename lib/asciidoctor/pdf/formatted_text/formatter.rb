# frozen_string_literal: true

module Asciidoctor
  module PDF
    module FormattedText
      class Formatter
        include ::Asciidoctor::Logging

        attr_accessor :scratch

        FormattingSnifferPattern = /[<&]/
        WHITESPACE = %( \t\n)
        SHY = ::Prawn::Text::SHY

        def initialize options = {}
          @parser = MarkupParser.new
          @transform = Transform.new merge_adjacent_text_nodes: true, theme: options[:theme]
          @scratch = false
        end

        def format string, *args
          options = args[0] || {}
          string = string.tr_s WHITESPACE, ' ' if options[:normalize]
          inherited = options[:inherited]
          if FormattingSnifferPattern.match? string
            if (parsed = @parser.parse string)
              return @transform.apply parsed.content, [], inherited
            end
            reason = @parser.failure_reason.sub %r/ at line \d+, column \d+ \(byte (\d+)\)(.*)/, '\2 at byte \1'
            logger.error %(failed to parse formatted text: #{string.tr SHY, ''} (reason: #{reason.tr SHY, ''})) unless @scratch
          end
          [inherited ? (inherited.merge text: string) : { text: string }]
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
