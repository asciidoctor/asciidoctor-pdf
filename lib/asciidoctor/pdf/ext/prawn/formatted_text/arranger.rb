# frozen_string_literal: true

Prawn::Text::Formatted::Arranger.prepend (Module.new do
  SUB_N_SUP_RELATIVE_SIZE = 0.583

  def initialize *_args
    super
    @normalize_line_height = false
  end

  def format_array= array
    @normalize_line_height = !array.empty? && (array[0].delete :normalize_line_height)
    super
  end

  def finalize_line
    @consumed.unshift text: Prawn::Text::ZWSP if @normalize_line_height
    super
  end

  def apply_font_size size, styles
    if (subscript? styles) || (superscript? styles)
      size ||= @document.font_size
      if String === size
        units = (size.end_with? 'em', '%') ? ((size.end_with? '%') ? '%' : 'em') : ''
        size = %(#{size.to_f * SUB_N_SUP_RELATIVE_SIZE}#{units})
      else
        size *= SUB_N_SUP_RELATIVE_SIZE
      end
      @document.font_size(size) { yield }
    elsif size
      @document.font_size(size) { yield }
    else
      yield
    end
  end
end)
