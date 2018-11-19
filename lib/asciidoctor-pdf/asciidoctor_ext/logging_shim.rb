module Asciidoctor
  class StubLogger
    class << self
      def warn message
        super %(asciidoctor: WARNING: #{message})
      end
    end
  end

  module LoggingShim
    def logger
      StubLogger
    end
  end
end
