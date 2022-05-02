# frozen_string_literal: true

Prawn.image_handler.register! Prawn::Images::PNG if defined? GMagick::Image
