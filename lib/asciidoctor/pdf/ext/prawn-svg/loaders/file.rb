# frozen_string_literal: true

Prawn::SVG::Loaders::File.prepend (Module.new do
  attr_reader :jail_path

  def initialize root_path
    if Hash === root_path
      @jail_path = root_path[:root]
      root_path = root_path[:base]
      super
    else
      super
      @jail_path = self.root_path
    end
  end

  def assert_valid_path! path
    if jail_path && !(path.start_with? %(#{jail_path}#{File::SEPARATOR}))
      raise Prawn::SVG::UrlLoader::Error, %(file path points to location outside of jail #{jail_path})
    end
  end
end)
