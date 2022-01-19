# frozen_string_literal: true

module Prawn::Text::NoopLstripBang
  def lstrip!; end
end

Prawn::Text::Formatted::Arranger.prepend (Module.new do
  def initialize *_args
    super
    @dummy_text = ?\u0000
  end

  def next_string
    (string = super) == @dummy_text ? (string.extend Prawn::Text::NoopLstripBang) : string
  end
end)
