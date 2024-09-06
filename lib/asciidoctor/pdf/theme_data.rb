# frozen_string_literal: true

module Asciidoctor
  module PDF
    class ThemeData
      attr_reader :table

      def initialize data = nil
        @table = (data || {}).transform_keys(&:to_sym)
      end

      def [] name
        @table[name.to_sym]
      end

      def []= name, value
        @table[name.to_sym] = value
      end

      def each_pair &block
        @table.each_pair(&block)
      end

      def eql? other
        @table.to_h.eql? other.to_h
      end

      def delete_field name
        @table.delete name
      end

      def dup
        ThemeData.new @table
      end

      def method_missing name, *args
        if (name_str = name.to_s).end_with? '='
          @table[name_str.chop.to_sym] = args[0]
        else
          @table[name]
        end
      end

      def respond_to? name, _include_all = false
        @table.key? name.to_sym
      end

      def respond_to_missing? name, _include_all = false
        @table.key? name.to_sym
      end

      def to_h
        @table
      end
    end
  end
end
