# frozen_string_literal: true

require_relative 'pdf/version'
require 'asciidoctor'
require 'prawn'
# NOTE: patch float precision constant so prawn-table does not fail to arrange cells that span columns (see #1835)
Prawn.send :remove_const, :FLOAT_PRECISION
Prawn::FLOAT_PRECISION = 1e-3
require 'prawn/templates'
begin
  require 'prawn/gmagick'
rescue LoadError
end unless defined? GMagick::Image
autoload :Set, 'set'
require_relative 'pdf/measurements'
require_relative 'pdf/sanitizer'
require_relative 'pdf/text_transformer'
require_relative 'pdf/ext'
require_relative 'pdf/theme_loader'
require_relative 'pdf/converter'
