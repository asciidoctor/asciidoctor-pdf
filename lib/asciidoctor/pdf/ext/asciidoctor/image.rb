# frozen_string_literal: true

module Asciidoctor
  module Image
    DataUriRx = %r(^data:image/(?<fmt>png|jpe?g|gif|pdf|bmp|tiff|svg\+xml);base64,(?<data>.*)$)
    FormatAliases = { 'jpg' => 'jpeg', 'svg+xml' => 'svg' }

    def self.format image_path
      ((ext = ::File.extname image_path).downcase.slice 1, ext.length)
    end

    def self.target_and_format image_path, attributes = nil
      if (image_path.start_with? 'data:') && (m = DataUriRx.match image_path)
        [(m[:data].extend ::Base64), (FormatAliases.fetch m[:fmt], m[:fmt])]
      else
        [image_path, attributes&.[]('format') || ((ext = ::File.extname image_path).downcase.slice 1, ext.length)]
      end
    end

    def target_and_format
      image_path = inline? ? target : (attr 'target')
      if (image_path.start_with? 'data:') && (m = DataUriRx.match image_path)
        [(m[:data].extend ::Base64), (FormatAliases.fetch m[:fmt], m[:fmt])]
      else
        [image_path, (attr 'format', nil, false) || ((ext = ::File.extname image_path).downcase.slice 1, ext.length)]
      end
    end
  end
end
