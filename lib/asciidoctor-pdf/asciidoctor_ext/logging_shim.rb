module Asciidoctor
  class StubLogger
    class << self
      def warn message
        ::Kernel.warn %(asciidoctor: WARNING: #{message})
      end

      def error message
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
