module Asciidoctor
module Image
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
    [image_path, (attr 'format', nil, false) || (::File.extname image_path).downcase[1..-1]]
  end
end
end
