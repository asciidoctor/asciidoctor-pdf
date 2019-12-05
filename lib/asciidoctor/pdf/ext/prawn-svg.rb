# frozen_string_literal: true

require 'prawn-svg' unless defined? Prawn::SVG::Interface
require_relative 'prawn-svg/interface'
# NOTE disable system fonts since they're non-portable
Prawn::SVG::Interface.font_path.clear
