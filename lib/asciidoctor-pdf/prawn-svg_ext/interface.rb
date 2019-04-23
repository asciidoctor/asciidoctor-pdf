module Prawn; module SVG
  class Interface
    def resize opts = {}
      sizing = document.sizing
      sizing.requested_width = opts[:width]
      sizing.requested_height = opts[:height]
      sizing.calculate
    end
  end
end; end unless Prawn::SVG::Interface.method_defined? :resize
