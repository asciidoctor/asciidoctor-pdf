# frozen_string_literal: true

module Prawn::Text::NoopLstripBang
  def lstrip!; end
end

Prawn::Text::Formatted::Arranger.prepend (Module.new do
  def initialize *_args
    super
    @dummy_text = ?\u0000
    @normalize_line_height = false
    @sub_and_sup_relative_size = 0.583
  end

  def format_array= array
    @normalize_line_height = !array.empty? && (array[0].delete :normalize_line_height)
    super
  end

  def finalize_line
    @consumed.unshift text: Prawn::Text::ZWSP if @normalize_line_height
    super
  end

  def next_string
    (string = super) == @dummy_text ? (string.extend Prawn::Text::NoopLstripBang) : string
  end

  def preview_joined_string
    if (next_unconsumed = @unconsumed[0] || {})[:wj] && !(@consumed[-1] || [])[:wj]
      idx = 0
      str = '' if (str = next_unconsumed[:text]) == @dummy_text
      while (next_unconsumed = @unconsumed[idx += 1] || {})[:wj] && (next_string = next_unconsumed[:text])
        str += next_string unless next_string == @dummy_text
      end
      str unless str == ''
    end
  end

  def apply_font_size size, styles
    if (subscript? styles) || (superscript? styles)
      size ||= @document.font_size
      if String === size
        units = (size.end_with? 'em', '%') ? ((size.end_with? '%') ? '%' : 'em') : ''
        size = %(#{size.to_f * @sub_and_sup_relative_size}#{units})
      else
        size *= @sub_and_sup_relative_size
      end
      @document.font_size(size) { yield }
    elsif size
      @document.font_size(size) { yield }
    else
      yield
    end
  end
end)
