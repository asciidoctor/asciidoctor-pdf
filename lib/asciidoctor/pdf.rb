# frozen_string_literal: true

require 'asciidoctor' unless defined? Asciidoctor.load
require_relative 'pdf/ext/asciidoctor'
require_relative 'pdf/version'
require_relative 'pdf/converter'
