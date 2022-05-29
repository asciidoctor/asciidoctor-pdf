# frozen_string_literal: true

Prawn::SVG::Calculators::DocumentSizing.prepend (Module.new do
  def initialize *_args
    super
    @document_width = @document_width.to_f * 0.75 if @document_width&.end_with? 'px'
    @document_height = @document_height.to_f * 0.75 if @document_height&.end_with? 'px'
  end
end)
