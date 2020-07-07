# frozen_string_literal: true

Prawn::Text::Formatted::Arranger.prepend (Module.new do
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
end)
