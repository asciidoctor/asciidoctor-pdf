# frozen_string_literal: true

Prawn::SVG::Elements::Image.prepend (Module.new do
  def image_dimensions data
    image = (Prawn.image_handler.find data).new data
    [image.width.to_f, image.height.to_f]
  rescue
    raise ::Prawn::SVG::Elements::Base::SkipElementError, 'image supplied to image tag is an unrecognised format'
  end
end)
