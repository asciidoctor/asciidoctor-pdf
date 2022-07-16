# frozen_string_literal: true

require 'pdf/inspector'
require_relative 'inspectors/image'
require_relative 'inspectors/line'
require_relative 'inspectors/rect'
require_relative 'inspectors/text'

(PDF_INSPECTOR_CLASS = {
  image: ImageInspector,
  line: LineInspector,
  page: PDF::Inspector::Page,
  rect: RectInspector,
  text: TextInspector,
}).default = TextInspector
