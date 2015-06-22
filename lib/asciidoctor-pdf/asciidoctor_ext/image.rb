module Asciidoctor
module Image
  class << self
    def image_type path
      (::File.extname path).downcase[1..-1]
    end
  end

  def image_type
    ::File.extname(inline? ? target : (attr 'target')).downcase[1..-1]
  end

  def target_with_image_type
    image_path = inline? ? (target) : (attr 'target')
    [image_path, (::File.extname image_path).downcase[1..-1]]
  end
end
end
