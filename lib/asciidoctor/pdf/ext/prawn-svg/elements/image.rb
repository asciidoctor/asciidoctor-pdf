# frozen_string_literal: true

Prawn::SVG::Elements::Image.prepend (Module.new do
  def image_dimensions data
    unless (handler = find_image_handler data)
      raise ::Prawn::SVG::Elements::Base::SkipElementError, 'Unsupported image type supplied to image tag'
    end
    image = handler.new data
    [image.width.to_f, image.height.to_f]
  end

  def find_image_handler data
    Prawn.image_handler.find data rescue nil
  end
end)
