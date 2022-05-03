# frozen_string_literal: true

require 'pathname'
require 'rghost'
require 'rghost/gs_alone'
require 'tmpdir'

RGhost::GSAlone.prepend (Module.new do
  def initialize params, debug
    (@params = params.dup).push(*(@params.pop.split File::PATH_SEPARATOR))
    @debug = debug
  end

  def run
    RGhost::Config.config_platform unless File.exist? RGhost::Config::GS[:path].to_s
    (cmd = @params.slice 1, @params.length).unshift RGhost::Config::GS[:path].to_s
    #puts cmd if @debug
    system(*cmd)
  end
end)

RGhost::Engine.prepend (Module.new do
  def shellescape str
    str
  end
end)

module Asciidoctor
  module PDF
    class Optimizer
      # see https://www.ghostscript.com/doc/current/VectorDevices.htm#PSPDF_IN for details
      (QUALITY_NAMES = {
        'default' => :default,
        'screen' => :screen,
        'ebook' => :ebook,
        'printer' => :printer,
        'prepress' => :prepress,
      }).default = :default

      attr_reader :quality
      attr_reader :compatibility_level

      def initialize quality = 'default', compatibility_level = '1.4', compliance = 'PDF'
        @quality = QUALITY_NAMES[quality]
        @compatibility_level = compatibility_level
        @compliance = compliance
        if (gs_path = ::ENV['GS'])
          ::RGhost::Config::GS[:path] = gs_path
        end
      end

      def optimize_file target
        ::Dir::Tmpname.create ['asciidoctor-pdf-', '.pdf'] do |tmpfile|
          filename_o = ::Pathname.new target
          filename_tmp = ::Pathname.new tmpfile
          if (pdfmark = filename_o.sub_ext '.pdfmark').file?
            inputs = [target, pdfmark.to_s].join ::File::PATH_SEPARATOR
          else
            inputs = target
          end
          d = { Printed: false, CannotEmbedFontPolicy: '/Warning', CompatibilityLevel: @compatibility_level }
          case @compliance
          when 'PDF/A', 'PDF/A-1', 'PDF/A-2', 'PDF/A-3'
            d[:PDFA] = ((@compliance.split '-', 2)[1] || 1).to_i
            d[:ShowAnnots] = false
          when 'PDF/X', 'PDF/X-1', 'PDF/X-3'
            d[:PDFX] = true
            d[:ShowAnnots] = false
          end
          (::RGhost::Convert.new inputs).to :pdf, filename: filename_tmp.to_s, quality: @quality, d: d
          filename_o.binwrite filename_tmp.binread
        end
        nil
      end
    end
  end
end
