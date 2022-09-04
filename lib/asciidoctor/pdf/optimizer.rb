# frozen_string_literal: true

module Asciidoctor
  module PDF
    module Optimizer
      attr_reader :quality
      attr_reader :compatibility_level
      attr_reader :compliance

      def initialize quality = 'default', compatibility_level = '1.4', compliance = 'PDF'
        @quality = quality
        @compatibility_level = compatibility_level
        @compliance = compliance
      end

      def optimize_file target
        raise ::NotImplementedError, %(#{Optimizer} subclass #{self.class} must implement the ##{__method__} method)
      end

      private_class_method def self.included into
        into.extend Config
      end

      module Config
        def register_for name
          Optimizer.register self, name.to_s
        end
      end

      module Factory
        @@registry = {}

        def for name
          if (optimizer = @@registry[name]).nil? && name == 'rghost'
            if (::Asciidoctor::Helpers.require_library %(#{__dir__}/optimizer/rghost), 'rghost', :warn).nil?
              @@registry[name] = false
            else
              optimizer = @@registry[name] = Optimizer::RGhost
            end
          end
          optimizer || nil
        end

        def register optimizer, name
          optimizer ? (@@registry[name] = optimizer) : (@@registry.delete name)
        end
      end

      class Base
        include Optimizer
      end

      extend Factory
    end
  end
end
