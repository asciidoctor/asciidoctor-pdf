# frozen_string_literal: true

# NOTE: disable system fonts since they're non-portable
Prawn::SVG::Interface.font_path.clear

# see https://github.com/mogest/prawn-svg/issues/189
if Prawn::SVG::FontRegistry.private_method_defined? :find_suitable_font
  Prawn::SVG::FontRegistry.prepend (Module.new do
    Prawn::SVG::FontRegistry.const_set :GENERIC_CSS_FONT_MAPPING_PROVIDED, Prawn::SVG::FontRegistry::GENERIC_CSS_FONT_MAPPING
    Prawn::SVG::FontRegistry.send :remove_const, :GENERIC_CSS_FONT_MAPPING
    Prawn::SVG::FontRegistry.const_set :GENERIC_CSS_FONT_MAPPING, {}

    def find_suitable_font name, weight, style
      name = (correctly_cased_font_name name) || name
      if !(installed_fonts.key? name) && ((generics = self.class::GENERIC_CSS_FONT_MAPPING_PROVIDED).key? name)
        name = generics[name]
      end
      super
    end
  end)
end
