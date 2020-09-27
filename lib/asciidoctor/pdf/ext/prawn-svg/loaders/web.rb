# frozen_string_literal: true

Prawn::SVG::Loaders::Web.prepend (Module.new do
  def initialize open_uri_loader = nil
    @open_uri_loader = Proc === open_uri_loader ? open_uri_loader : nil
  end

  def from_url url
    (url.to_s.start_with? 'http://', 'https://') ? (load_open_uri.open_uri url, 'rb', &:read) : nil
  rescue
    raise Prawn::SVG::UrlLoader::Error, $!.message
  end

  def load_open_uri
    if @open_uri_loader
      @open_uri_loader.call
    else
      require 'open-uri' unless defined? OpenURI
      OpenURI
    end
  end
end)
