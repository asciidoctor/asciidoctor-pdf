# frozen_string_literal: true

require 'pygments.rb'

module Pygments
  module Ext
    module BlockStyles
      BlockSelectorRx = /^\.highlight *\{([^}]+?)\}/
      HexColorRx = /^#[a-fA-F0-9]{6}$/

      @cache = ::Hash.new do |cache, key|
        styles = {}
        if BlockSelectorRx =~ (::Pygments.css '.highlight', style: key)
          ($1.strip.split ';').each do |style|
            pname, pval = (style.split ':', 2).map(&:strip)
            if pname == 'background' || pname == 'background-color'
              styles[:background_color] = (pval.slice 1, pval.length).upcase if HexColorRx.match? pval
            elsif pname == 'color'
              styles[:font_color] = (pval.slice 1, pval.length).upcase if HexColorRx.match? pval
            end
          end
        end
        @cache = cache.merge key => styles
        styles
      end

      def self.for style
        @cache[style]
      end
    end
  end
end
