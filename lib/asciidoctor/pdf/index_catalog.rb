# frozen_string_literal: true

begin
  require 'ffi-icu'
rescue LoadError # rubocop:disable Lint/SuppressedException
end unless defined? ICU

module Asciidoctor
  module PDF
    class IndexCatalog
      include TextTransformer

      LeadingAlphaRx = /^\p{Alpha}/
      CategoryNameTransliterationIDs = 'Any-Latin;Latin-ASCII;Any-Upper'

      attr_accessor :start_page_number

      def initialize locale = nil
        @categories = {}
        @start_page_number = 1
        @dests = {}
        @sequence = 0
        @locale = locale || 'en'
      end

      def next_anchor_name
        %(__indexterm-#{@sequence += 1})
      end

      def store_term names, dest
        if (num_terms = names.size) > 2
          store_tertiary_term names[0], names[1], names[2], dest
        elsif num_terms == 2
          store_secondary_term names[0], names[1], dest
        elsif num_terms == 1
          store_primary_term names[0], dest
        end
      end

      def store_primary_term name, dest = nil
        store_dest dest if dest
        (init_category name).store_term name, dest
      end

      def store_secondary_term primary_name, secondary_name, dest = nil
        store_dest dest if dest
        (store_primary_term primary_name).store_term secondary_name, dest
      end

      def store_tertiary_term primary_name, secondary_name, tertiary_name, dest
        store_dest dest
        (store_secondary_term primary_name, secondary_name).store_term tertiary_name, dest
      end

      def init_category term
        if LeadingAlphaRx.match? term
          name = term.chr
          name = !(defined? ::ICU::Transliteration) || name.ascii_only? ?
            name.upcase :
            ((::ICU::Transliteration::Transliterator.new CategoryNameTransliterationIDs).transliterate name)
        else
          name = '@'
        end
        @categories[name] ||= (IndexTermCategory.new name, @locale)
      end

      def find_category name
        @categories[name]
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

      def initialize name, locale = nil
        @name = name
        @terms = {}
        @locale = locale || 'en'
      end

      def store_term name, dest
        term = (@terms[name] ||= (IndexTerm.new name))
        term.add_dest dest if dest
        term
      end

      def terms
        @terms.empty? ? [] : @terms.values.sort
      end

      def <=> other
        if IndexTermCategory === self
          @name <=> other.name
        elsif (verdict = @name.casecmp other.name) == 0
          other.name <=> @name
        elsif (defined? ::ICU::Collation) && (!@name.ascii_only? || !other.name.ascii_only?)
          (::ICU::Collation::Collator.new @locale).compare @name, other.name
        else
          verdict
        end
      end
    end

    class IndexTermCategory < IndexTermGroup; end

    class IndexTerm < IndexTermGroup
      def initialize name
        super
        @dests = ::Set.new
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
    end
  end
end
