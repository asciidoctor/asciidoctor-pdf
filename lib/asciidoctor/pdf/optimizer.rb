# frozen_string_literal: true

require 'pathname'
require 'rghost'
require 'tmpdir'

module Asciidoctor
  module PDF
    class Optimizer
      (QUALITY_NAMES = {
        'default' => :default,
        'screen' => :screen,
        'ebook' => :ebook,
        'printer' => :printer,
        'prepress' => :prepress,
      }).default = :default

      attr_reader :quality
      attr_reader :compatibility_level

      def initialize quality = 'default', compatibility_level = '1.4'
        @quality = QUALITY_NAMES[quality]
        @compatibility_level = compatibility_level
      end

      def generate_file target
        ::Dir::Tmpname.create ['asciidoctor-pdf-', '.pdf'] do |tmpfile|
          filename_o = Pathname.new target
          filename_tmp = Pathname.new tmpfile
          pdfmark = filename_o.sub_ext '.pdfmark'
          inputs = pdfmark.file? ? [target, pdfmark.to_s] : target
          (::RGhost::Convert.new inputs).to :pdf,
              filename: filename_tmp.to_s,
              quality: @quality,
              d: { Printed: false, CannotEmbedFontPolicy: '/Warning', CompatibilityLevel: @compatibility_level }
          filename_o.binwrite filename_tmp.binread
        end
        nil
      end
    end
  end
end
