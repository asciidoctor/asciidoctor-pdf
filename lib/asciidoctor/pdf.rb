# frozen_string_literal: true

proc do
  old_verbose, $VERBOSE = $VERBOSE, nil
  begin
    require 'bigdecimal' # try to eagerly require bigdecimal with warnings off to avoid warning caused by ttfunk 1.7.0
  rescue Exception # rubocop:disable Lint/SuppressedException,Lint/RescueException
  end
  $VERBOSE = old_verbose
end.call

autoload :Set, 'set'
autoload :StringIO, 'stringio'
autoload :Tempfile, 'tempfile'
require 'time' unless defined? Time.parse
require_relative 'pdf/version'
proc do
  old_verbose, $VERBOSE = $VERBOSE, nil
  require 'asciidoctor' # avoid warning in Ruby 3.4 caused by use of logger
  $VERBOSE = old_verbose
end.call
require 'prawn'
require 'prawn/templates'
require_relative 'pdf/measurements'
require_relative 'pdf/sanitizer'
require_relative 'pdf/text_transformer'
require_relative 'pdf/ext'
require_relative 'pdf/theme_loader'
require_relative 'pdf/converter'
