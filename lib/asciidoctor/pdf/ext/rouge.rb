# frozen_string_literal: true
require 'rouge'
require_relative 'rouge/formatters/prawn'
require_relative 'rouge/themes/asciidoctor_pdf_default'
require_relative 'rouge/themes/bw' unless Rouge::Theme.find 'bw'
