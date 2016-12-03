require 'prawn-svg' unless defined? Prawn::Svg::VERSION
require_relative 'prawn-svg_ext/interface'
# NOTE disable system fonts since they're non-portable
Prawn::Svg::Interface.font_path.clear
