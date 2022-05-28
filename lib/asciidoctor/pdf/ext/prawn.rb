# frozen_string_literal: true

# NOTE: patch float precision constant so prawn-table does not fail to arrange cells that span columns (see #1835)
Prawn.send :remove_const, :FLOAT_PRECISION
Prawn::FLOAT_PRECISION = 1e-3

# the following are organized under the Asciidoctor::Prawn namespace
require_relative 'prawn/document/column_box'
require_relative 'prawn/font_metric_cache'
require_relative 'prawn/font/afm'
require_relative 'prawn/images'
require_relative 'prawn/formatted_text/arranger'
require_relative 'prawn/formatted_text/box'
require_relative 'prawn/formatted_text/fragment'
require_relative 'prawn/formatted_text/indented_paragraph_wrap'
require_relative 'prawn/formatted_text/protect_bottom_gutter'
require_relative 'prawn/extensions'
