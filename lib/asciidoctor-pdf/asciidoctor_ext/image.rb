module Asciidoctor
module Image
  class << self
    def image_type path
      (::File.extname path)[1..-1].downcase
    end
  end

  def image_type
    (attr 'format', nil, false) || ::File.extname(inline? ? target : (attr 'target'))[1..-1].downcase
  end

  def target_with_image_type
    image_path = inline? ? (target) : (attr 'target')
    [image_path, (attr 'format', nil, false) || (::File.extname image_path)[1..-1].downcase]
  end
end
end
