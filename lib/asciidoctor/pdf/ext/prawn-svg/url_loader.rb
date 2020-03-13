# frozen_string_literal: true

Prawn::SVG::UrlLoader.prepend (Module.new do
  def initialize enable_cache: false, enable_web: true, enable_file_with_root: nil
    @url_cache = {}
    @enable_cache = enable_cache
    loaders = []
    loaders << Prawn::SVG::Loaders::Data.new
    loaders << (Prawn::SVG::Loaders::Web.new enable_web) if enable_web
    loaders << (Prawn::SVG::Loaders::File.new enable_file_with_root) if enable_file_with_root
    @loaders = loaders
  end
end)
