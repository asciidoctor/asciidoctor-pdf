module Asciidoctor
module Image
  DataUriRx = /^data:image\/(?<fmt>png|jpe?g|gif|pdf|bmp|tiff);base64,(?<data>.*)$/

  class << self
    def format path, attributes = nil
      (attributes && attributes['format']) || ((ext = ::File.extname path).downcase.slice 1, ext.length)
    end
  end

  def format
    (attr 'format', nil, false) || ((ext = ::File.extname(inline? ? target : (attr 'target'))).downcase.slice 1, ext.length)
  end

  def target_and_format
    image_path = inline? ? target : (attr 'target')
    if (image_path.start_with? 'data:') && (m = DataUriRx.match image_path)
      [(m[:data].extend ::Base64), m[:fmt]]
    else
      [image_path, (attr 'format', nil, false) || ((ext = ::File.extname image_path).downcase.slice 1, ext.length)]
    end
  end
end
end
