# frozen_string_literal: true

require 'digest'
require_relative 'formatted_string'

module Asciidoctor
  module PDF
    class IndexCatalog
      include TextTransformer

      LeadingAlphaRx = /^\p{Alpha}/

      attr_accessor :start_page_number

      def initialize
        @categories = {}
        @start_page_number = 1
        @dests = {}
        @sequence = 0
      end

      def next_anchor_name
        %(__indexterm-#{@sequence += 1})
      end

      def store_term names, dest, assoc = {}
        if (num_terms = (names = names.map {|name| FormattedString.new name }).size) == 1
          store_primary_term names[0], dest, assoc
        elsif num_terms == 2
          store_secondary_term names[0], names[1], dest, assoc
        elsif num_terms > 2
          store_tertiary_term names[0], names[1], names[2], dest, assoc
        end
      end

      def store_primary_term name, dest = nil, assoc = {}
        store_dest dest if dest
        (init_category name.chr.upcase).store_term name, dest, assoc
      end

      def store_secondary_term primary_name, secondary_name, dest = nil, assoc = {}
        store_dest dest if dest
        (store_primary_term primary_name).store_term secondary_name, dest, assoc
      end

      def store_tertiary_term primary_name, secondary_name, tertiary_name, dest, assoc = {}
        store_dest dest
        (store_secondary_term primary_name, secondary_name).store_term tertiary_name, dest, assoc
      end

      def init_category name
        name = '@' unless LeadingAlphaRx.match? name
        @categories[name] ||= IndexTermCategory.new name
      end

      def find_category name
        @categories[name]
      end

      def find_primary_term name
        @categories.each_value do |category|
          term = category.terms.find {|candidate| candidate.name == name }
          return term if term
        end
        nil
      end

      def link_associations group = nil
        if group
          group.terms.each do |term|
            associations = term.associations
            if (see_name = associations[:see])
              see_name = FormattedString.new see_name
              term.see = (find_primary_term see_name) || (UnresolvedIndexTerm.new see_name)
            elsif (see_also_names = associations[:see_also])
              term.see_also = see_also_names.map do |see_also_name|
                see_also_name = FormattedString.new see_also_name
                (find_primary_term see_also_name) || (UnresolvedIndexTerm.new see_also_name)
              end
            end
            link_associations term unless term.leaf?
          end
        else
          @categories.each_value {|category| link_associations category }
        end
      end

      def store_dest dest
        @dests[dest[:anchor]] = dest
      end

      def link_dest_to_page anchor, physical_page_number
        if (dest = @dests[anchor])
          virtual_page_number = (dest[:page_sortable] = physical_page_number) - (@start_page_number - 1)
          dest[:page] = (virtual_page_number < 1 ? (RomanNumeral.new physical_page_number, :lower) : virtual_page_number).to_s
        end
      end

      def empty?
        @categories.empty?
      end

      def categories
        @categories.values.sort
      end
    end

    class IndexTermGroup
      include Comparable
      attr_reader :name

      def initialize name
        @name = name
        @terms = {}
      end

      def store_term name, dest, assoc = {}
        term = (@terms[name] ||= (IndexTerm.new name))
        term.add_dest dest if dest
        term.associations ||= {}
        unless assoc.empty?
          if !term.associations[:see] && (see = assoc[:see])
            term.associations[:see] = see
          end
          if (see_also = assoc[:see_also])
            (term.associations[:see_also] ||= []).concat see_also
          end
        end
        term
      end

      def terms
        @terms.empty? ? [] : @terms.values.sort
      end

      def <=> other
        (val = @name.casecmp other.name) == 0 ? @name <=> other.name : val
      end
    end

    class IndexTermCategory < IndexTermGroup; end

    class UnresolvedIndexTerm < IndexTermGroup; end

    class IndexTerm < IndexTermGroup
      attr_reader :anchor

      attr_accessor :associations

      attr_accessor :see

      attr_writer :see_also

      def initialize name
        super
        @dests = ::Set.new
        @anchor = %(__indextermdef-#{(::Digest::MD5.new << name.to_s).hexdigest})
        @associations = @see = @see_also = nil
      end

      alias subterms terms

      def add_dest dest
        @dests << dest
        self
      end

      def dests
        @dests.select {|d| d.key? :page }.sort_by {|d| d[:page_sortable] }
      end

      def container?
        @dests.empty? || @dests.none? {|d| d.key? :page }
      end

      def leaf?
        @terms.empty?
      end

      def see_also
        @see_also&.sort
      end
    end
  end
end
