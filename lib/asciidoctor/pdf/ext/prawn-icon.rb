# frozen_string_literal: true

require 'prawn/icon'
Prawn::Icon::Compatibility.prepend (::Module.new { def warning *_args; end })
require_relative 'prawn-icon/legacy'
require_relative 'prawn-icon/interface'
