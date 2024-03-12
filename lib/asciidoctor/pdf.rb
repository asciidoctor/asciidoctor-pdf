# frozen_string_literal: true

proc do
  old_verbose, $VERBOSE = $VERBOSE, nil
  require 'bigdecimal' # eagerly require bigdecimal without warnings to avoid warning caused by ttfunk 1.7.0
  $VERBOSE = old_verbose
end.call

autoload :Set, 'set'
autoload :StringIO, 'stringio'
autoload :Tempfile, 'tempfile'
require 'time' unless defined? Time.parse
require_relative 'pdf/version'
require 'asciidoctor'
require 'prawn'
require 'prawn/templates'
require_relative 'pdf/measurements'
require_relative 'pdf/sanitizer'
require_relative 'pdf/text_transformer'
require_relative 'pdf/ext'
require_relative 'pdf/theme_loader'
require_relative 'pdf/converter'
