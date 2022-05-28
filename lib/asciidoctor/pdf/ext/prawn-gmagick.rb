# frozen_string_literal: true

begin
  require 'prawn/gmagick'
rescue LoadError # rubocop:disable Lint/SuppressedException
end unless defined? GMagick::Image

Gmagick.prepend (Module.new do
  def initialize image_blob
    super
    # apply patch for https://github.com/packetmonkey/prawn-gmagick/issues/19
    if bits != 8 && (GMagick::Image.format image_blob) == 'PNG'
      (io = StringIO.new image_blob).read 8
      chunk_size = io.read 4
      self.bits = ((io.read chunk_size.unpack1 'N').unpack 'NNC')[-1] if (io.read 4) == 'IHDR'
    end
  end
end) if defined? GMagick::Image
