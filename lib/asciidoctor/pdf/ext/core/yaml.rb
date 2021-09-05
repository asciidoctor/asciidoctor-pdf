# frozen_string_literal: true

require 'yaml'

unless (YAML.method :safe_load).parameters.include? [:key, :aliases]
  YAML.singleton_class.prepend (Module.new do
    def safe_load yaml, permitted_classes: [], permitted_symbols: [], aliases: false, filename: nil, symbolize_names: false
      super yaml, permitted_classes, permitted_symbols, aliases, filename, symbolize_names: symbolize_names
    end
  end)
end
