# frozen_string_literal: true

require 'prawn-svg' unless defined? Prawn::SVG::Interface
require_relative 'prawn-svg/loaders/web'
require_relative 'prawn-svg/url_loader'
# NOTE: disable system fonts since they're non-portable
Prawn::SVG::Interface.font_path.clear
