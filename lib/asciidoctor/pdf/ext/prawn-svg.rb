# frozen_string_literal: true

require 'prawn-svg'
require_relative 'prawn-svg/calculators/document_sizing'
require_relative 'prawn-svg/elements/image'
require_relative 'prawn-svg/loaders/data'
require_relative 'prawn-svg/loaders/file'
require_relative 'prawn-svg/loaders/web'
require_relative 'prawn-svg/url_loader'
# NOTE: disable system fonts since they're non-portable
Prawn::SVG::Interface.font_path.clear
