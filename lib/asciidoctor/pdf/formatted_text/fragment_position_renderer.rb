# frozen_string_literal: true

module Asciidoctor::PDF::FormattedText
  class FragmentPositionRenderer
    attr_reader :top, :right, :bottom, :left

    def render_behind fragment
      @top = fragment.top
      @right = (@left = fragment.left) + fragment.width
      @bottom = fragment.bottom
    end
  end
end
