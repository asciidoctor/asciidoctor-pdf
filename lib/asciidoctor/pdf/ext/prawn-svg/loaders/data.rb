# frozen_string_literal: true

class Prawn::SVG::Loaders::Data
  remove_const :REGEXP
  REGEXP = %r(\Adata:image/(?:png|jpe?g|svg\+xml);base64(?:;[a-z0-9]+)*,)i
end
