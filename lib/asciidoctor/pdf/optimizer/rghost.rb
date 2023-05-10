# frozen_string_literal: true

require_relative '../optimizer' unless defined? Asciidoctor::PDF::Optimizer
require 'pathname'
require 'rghost'
require 'rghost/gs_alone'
require 'tmpdir'
autoload :Open3, 'open3'

# rghost still uses File.exists?
File.singleton_class.alias_method :exists?, :exist? unless File.respond_to? :exists?

RGhost::GSAlone.prepend (Module.new do
  def initialize params, debug
    (@params = params.drop 0).push(*(@params.pop.split File::PATH_SEPARATOR))
    @debug = debug
  end

  def run
    RGhost::Config.config_platform unless File.exist? RGhost::Config::GS[:path].to_s
    (cmd = @params.drop 1).unshift RGhost::Config::GS[:path].to_s
    #puts cmd if @debug
    _out, err, status = Open3.capture3(*cmd)
    unless (lines = err.lines.each_with_object([]) {|l, accum| (l.include? '-dNEWPDF=') ? accum.pop : (accum << l) }).empty?
      $stderr.write(*lines)
    end
    status.success?
  end
end)

RGhost::Engine.prepend (Module.new do
  def shellescape str
    str
  end
end)

module Asciidoctor
  module PDF
    class Optimizer::RGhost < Optimizer::Base
      DEFAULT_PARAMS = %w(gs -dNOPAUSE -dBATCH -dQUIET -dNOPAGEPROMPT)

      # see https://www.ghostscript.com/doc/current/VectorDevices.htm#PSPDF_IN for details
      (QUALITY_NAMES = {
        'default' => :default,
        'screen' => :screen,
        'ebook' => :ebook,
        'printer' => :printer,
        'prepress' => :prepress,
      }).default = :default

      def initialize *_args
        super
        if @quality&.include? ':'
          @quality, @color_mode = @quality.split ':', 2
        else
          @color_mode = nil
        end
        if (gs_path = ::ENV['GS'])
          ::RGhost::Config::GS[:path] = gs_path
        end
        @newpdf = false
        default_params = DEFAULT_PARAMS.drop 0
        if (user_params = ::ENV['GS_OPTIONS'])
          (default_params += user_params.split).uniq!
          @newpdf = nil if default_params.find {|it| it.start_with? '-dNEWPDF=' }
        end
        ::RGhost::Config::GS[:default_params] = default_params
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
          d[:NEWPDF] = @newpdf unless @newpdf.nil?
          case @compliance
          when 'PDF/A', 'PDF/A-1', 'PDF/A-2', 'PDF/A-3'
            d[:PDFA] = ((@compliance.split '-', 2)[1] || 1).to_i
            d[:ShowAnnots] = false
          when 'PDF/X', 'PDF/X-1', 'PDF/X-3'
            d[:PDFX] = true
            d[:ShowAnnots] = false
          end
          case @color_mode
          when 'gray', 'grayscale'
            s = { ColorConversionStrategy: 'Gray' }
          when 'bw'
            d[:BlackText] = true
            s = { ColorConversionStrategy: 'Gray' }
          end
          (::RGhost::Convert.new inputs).to :pdf, filename: filename_tmp.to_s, quality: QUALITY_NAMES[@quality], d: d, s: s
          filename_o.binwrite filename_tmp.binread
        end
        nil
      end
    end
  end
end
