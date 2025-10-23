# frozen_string_literal: true

if Warning[:experimental] && (RUBY_VERSION.start_with? '2.')
  Warning[:experimental] = false
  require 'prawn-svg'
  Warning[:experimental] = true
else
  require 'prawn-svg'
end
require_relative 'prawn-svg/calculators/document_sizing'
require_relative 'prawn-svg/elements/image'
require_relative 'prawn-svg/elements/use'
require_relative 'prawn-svg/font_registry'
require_relative 'prawn-svg/loaders/data'
require_relative 'prawn-svg/loaders/file'
require_relative 'prawn-svg/loaders/web'
require_relative 'prawn-svg/url_loader'
