# frozen_string_literal: true

module Prawn::Icon::Interface
  def icon_font_data family
    ::Prawn::Icon::FontData.load self, family
  end

  def resolve_legacy_icon_name name
    ::Prawn::Icon::Legacy.mapping[%(fa-#{name})]
  end
end
