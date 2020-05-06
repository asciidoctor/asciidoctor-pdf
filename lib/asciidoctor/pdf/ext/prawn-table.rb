# frozen_string_literal: true

require 'prawn/table' unless defined? Prawn::Table::VERSION
require_relative 'prawn-table/cell'
require_relative 'prawn-table/cell/asciidoc'
require_relative 'prawn-table/cell/text'
