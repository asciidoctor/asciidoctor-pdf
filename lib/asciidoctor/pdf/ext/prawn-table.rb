# frozen_string_literal: true

require 'prawn/table'

Prawn::Table.prepend (Module.new do
  def initial_row_on_initial_page
    return 0 if fits_on_page? @pdf.bounds.height
    height_required = (row (0..number_of_header_rows)).height_with_span
    return -1 if fits_on_page? height_required, true
    @pdf.bounds.move_past_bottom
    0
  end
end)

require_relative 'prawn-table/cell'
require_relative 'prawn-table/cell/asciidoc'
require_relative 'prawn-table/cell/text'
