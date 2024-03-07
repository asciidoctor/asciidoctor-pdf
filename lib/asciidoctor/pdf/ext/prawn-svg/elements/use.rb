# frozen_string_literal: true

# see https://github.com/mogest/prawn-svg/issues/164
Prawn::SVG::Elements::Use.prepend (Module.new do
  def parse
    result = super
    if @referenced_element_source.name == 'symbol' && !(@referenced_element_source.attributes.key? 'viewBox')
      @referenced_element_class = Prawn::SVG::Elements::Container
    end
    result
  end
end)
