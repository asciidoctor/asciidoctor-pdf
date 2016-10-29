module Asciidoctor
module Prawn
module Images
  class << self
    def extended base
      base.class.__send__ :alias_method, :_initial_image, :image
    end
  end

  # Dispatch to suitable image method in Prawn based on file extension.
  def image file, opts = {}
    # FIXME handle case when SVG is a File or IO object
    if ::String === file && (file.downcase.end_with? '.svg')
      opts[:fallback_font_name] ||= default_svg_font if respond_to? :default_svg_font
      svg (::IO.read file), opts
    else
      _initial_image file, opts
    end
  end

  # Retrieve the intrinsic image dimensions for the specified path.
  #
  # Returns a Hash containing :width and :height keys that map to the image's
  # intrinsic width and height values (in pixels)
  def intrinsic_image_dimensions path
    if path.end_with? '.svg'
      img_obj = ::Prawn::Svg::Interface.new ::IO.read(path), self, {}
      img_size = img_obj.document.sizing
      { width: img_size.output_width, height: img_size.output_height }
    else
      # NOTE build_image_object caches image data previously loaded
      _, img_size = ::File.open(path, 'rb') {|fd| build_image_object fd }
      { width: img_size.width, height: img_size.height }
    end
  end
end

::Prawn::Document.extensions << Images
end
end
