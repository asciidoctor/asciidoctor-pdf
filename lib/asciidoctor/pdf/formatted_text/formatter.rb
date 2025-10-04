# frozen_string_literal: true

module Asciidoctor
  module PDF
    module FormattedText
      class Formatter
        include ::Asciidoctor::Logging

        attr_accessor :scratch

        FormattingSnifferPattern = /[<&]/
        WHITESPACE = %( \t\n)
        NORMALIZE_TO_SPACE = %(\t\n)
        SHY = ::Prawn::Text::SHY

        def initialize options = {}
          @parser = MarkupParser.new
          @transform = Transform.new merge_adjacent_text_nodes: true, theme: options[:theme]
          @scratch = false
        end

        def format string, *args
          options = args[0] || {}
          inherited = options[:inherited]
          if FormattingSnifferPattern.match? string
            string = string.tr NORMALIZE_TO_SPACE, ' ' if (normalize_space = options[:normalize])
            if (parsed = @parser.parse string)
              return @transform.apply parsed.content, [], inherited, normalize_space: normalize_space
            end
            reason = @parser.failure_reason.sub %r/ at line \d+, column \d+ \(byte (\d+)\)(.*)/, '\2 at byte \1'
            logger.error %(failed to parse formatted text: #{string.tr SHY, ''} (reason: #{reason.tr SHY, ''})) unless @scratch
          elsif options[:normalize]
            string = string.tr_s WHITESPACE, ' '
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
