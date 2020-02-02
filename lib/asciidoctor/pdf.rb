# frozen_string_literal: true

require_relative 'pdf/version'
require 'asciidoctor' unless defined? Asciidoctor.load
require 'prawn'
begin
  require 'prawn/gmagick'
rescue LoadError
end unless defined? GMagick::Image
require_relative 'pdf/measurements'
require_relative 'pdf/sanitizer'
require_relative 'pdf/text_transformer'
require_relative 'pdf/ext'
require_relative 'pdf/theme_loader'
require_relative 'pdf/converter'
