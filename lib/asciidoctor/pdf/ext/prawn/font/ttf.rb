# frozen_string_literal: true

Prawn::Font::TTF.prepend (Module.new do
  def character_width_by_code code
    return 0 if code == 0
    super
  end
end)
