module Asciidoctor
  class StubLogger
    class << self
      def info message = nil
        # ignore since this isn't a real logger
      end

      def warn message = nil
        message = block_given? ? yield : message unless message
        ::Kernel.warn %(asciidoctor: WARNING: #{message})
      end

      def error message = nil
        message = block_given? ? yield : message unless message
        ::Kernel.warn %(asciidoctor: ERROR: #{message})
      end
    end
  end

  module LoggingShim
    def logger
      StubLogger
    end
  end
end
