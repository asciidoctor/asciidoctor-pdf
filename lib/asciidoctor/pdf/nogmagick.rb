# frozen_string_literal: true

if defined? GMagick::Image
  Prawn.image_handler.unregister Gmagick
  Prawn.image_handler.register! Prawn::Images::PNG
end
