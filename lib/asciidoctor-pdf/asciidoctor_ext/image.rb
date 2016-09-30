module Asciidoctor
module Image
  DataUriRx = /^data:image\/(?<fmt>png|jpe?g|gif|pdf|bmp|tiff);base64,(?<data>.*)$/

  class << self
    def format path, node = nil
      (node && (node.attr 'format', nil, false)) || (::File.extname path).downcase[1..-1]
    end
  end

  def format
    (attr 'format', nil, false) || ::File.extname(inline? ? target : (attr 'target')).downcase[1..-1]
  end

  def target_and_format
    image_path = inline? ? target : (attr 'target')
    if (image_path.start_with? 'data:') && (m = DataUriRx.match image_path)
      [(m[:data].extend ::Base64), m[:fmt]]
    else
      [image_path, (attr 'format', nil, false) || (::File.extname image_path).downcase[1..-1]]
    end
  end
end
end
