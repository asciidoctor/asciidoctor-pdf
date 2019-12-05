# frozen_string_literal: true

module Asciidoctor
  class StubLogger
    class << self
      def info message = nil
        # ignore since this isn't a real logger
      end

      def warn message = nil
        ::Kernel.warn %(asciidoctor: WARNING: #{message || (block_given? ? yield : '???')})
      end

      def error message = nil
        ::Kernel.warn %(asciidoctor: ERROR: #{message || (block_given? ? yield : '???')})
      end
    end
  end

  module LoggingShim
    def logger
      StubLogger
    end
  end
end
