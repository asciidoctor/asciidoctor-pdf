# frozen_string_literal: true

require 'pdf/inspector'
require_relative 'inspectors/image'
require_relative 'inspectors/line'
require_relative 'inspectors/rect'
require_relative 'inspectors/text'

#PDF::Inspector::Text.prepend (Module.new do
#  def page= page
#    @page_number = page.number
#    super
#  end
#
#  def move_text_position tx, ty
#    @positions << [tx, ty, @page_number]
#  end
#end)

(PDF_INSPECTOR_CLASS = {
  image: ImageInspector,
  line: LineInspector,
  page: PDF::Inspector::Page,
  rect: RectInspector,
  text: TextInspector,
}).default = TextInspector
