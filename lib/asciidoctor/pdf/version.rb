# frozen_string_literal: true

module Asciidoctor
  module PDF
    VERSION = '1.5.0.rc.1'
  end
  Pdf = PDF unless const_defined? :Pdf, false
end
