# frozen_string_literal: true

class Prawn::Icon::Legacy
  FontsDir = ::File.absolute_path %(#{__dir__}/../../../../../data/fonts)
  MappingDataPath = ::File.join FontsDir, 'fa-legacy-mapping.yml'
  class << self
    def mapping
      @mapping ||= YAML.load_file MappingDataPath
    end
  end
end
