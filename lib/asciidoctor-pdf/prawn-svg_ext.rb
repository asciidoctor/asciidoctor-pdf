require 'prawn-svg' unless defined? Prawn::SVG::Interface
require_relative 'prawn-svg_ext/interface'
# NOTE disable system fonts since they're non-portable
Prawn::SVG::Interface.font_path.clear
