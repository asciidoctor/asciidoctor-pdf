# frozen_string_literal: true

module Asciidoctor
  module PDF
    class SectionInfoByPage
      def initialize title_method
        @table = {}
        @title_method = title_method
      end

      def []= pgnum, val
        if ::Asciidoctor::Section === val
          @table[pgnum] = { title: (val.send @title_method[0], **@title_method[1]), numeral: val.numeral }
        else
          @table[pgnum] = { title: val }
        end
      end

      def [] pgnum
        @table[pgnum]
      end
    end
  end
end
