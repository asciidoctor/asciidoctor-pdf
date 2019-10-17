require 'rghost'

module Asciidoctor
module PDF
class Optimizer
  QUALITY_NAMES = ({
    'default' => :default,
    'screen' => :screen,
    'ebook' => :ebook,
    'printer' => :printer,
    'prepress' => :prepress,
  }).default = :default

  def initialize quality = 'default', compatibility_level = '1.4'
    @quality = QUALITY_NAMES[quality]
    @compatibility_level = compatibility_level
  end

  def generate_file target
    filename_o = (filename = Pathname.new target).sub_ext '-o.pdf'
    pdfmark = filename.sub_ext '.pdfmark'
    (::RGhost::Convert.new target).to :pdf,
      filename: filename_o.to_s,
      quality: @quality,
      d: { Printed: false, CannotEmbedFontPolicy: '/Warning', CompatibilityLevel: @compatibility_level },
      raw: pdfmark.file? ? pdfmark.to_s : nil
    filename_o.rename target
  end
end
end
end
