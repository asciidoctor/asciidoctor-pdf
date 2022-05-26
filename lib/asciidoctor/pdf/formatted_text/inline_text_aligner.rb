# frozen_string_literal: true

module Asciidoctor::PDF::FormattedText
  module InlineTextAligner
    module_function

    def render_behind fragment
      document = fragment.document
      text = fragment.text
      x = fragment.left
      y = fragment.baseline
      align = (format_state = fragment.format_state)[:align]
      if align == :center || align == :right
        gap_width = (format_state.key? :width) ?
          fragment.width - (document.width_of text) :
          (format_state[:border_offset] || 0) * 2
        x += gap_width * (align == :center ? 0.5 : 1) if gap_width > 0
      end
      document.word_spacing fragment.word_spacing do
        document.draw_text! text, at: [x, y], kerning: document.default_kerning?
      end
      fragment.conceal
    end
  end
end
