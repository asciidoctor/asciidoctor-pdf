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
      units = (size.end_with? 'em') ? 'em' : '' if String === size
      size = units ? %(#{size.to_f * SUB_N_SUP_RELATIVE_SIZE}#{units}) : size * SUB_N_SUP_RELATIVE_SIZE
      @document.font_size(size) { yield }
    elsif size
      @document.font_size(size) { yield }
    else
      yield
    end
  end
end)
