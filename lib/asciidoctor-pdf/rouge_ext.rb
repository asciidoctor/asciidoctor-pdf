require 'rouge'
require_relative 'rouge_ext/formatters/prawn'
require_relative 'rouge_ext/themes/asciidoctor_pdf_default'
require_relative 'rouge_ext/themes/bw' unless Rouge::Theme.find 'bw'
