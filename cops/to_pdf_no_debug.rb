# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      class ToPDFNoDebug < Base
        def_node_matcher :to_pdf_with_debug?, <<~'EOS'
          (send nil? :to_pdf <(dstr ...) (hash ... (pair (sym :debug) (true)))>)
        EOS

        MSG = 'debug flag not permitted'
        RESTRICT_ON_SEND = [:to_pdf]

        def on_send node
          return unless to_pdf_with_debug? node
          add_offense node
        end
      end
    end
  end
end
