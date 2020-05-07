# frozen_string_literal: true

module Asciidoctor
  module PDF
    module TextTransformer
      XMLMarkupRx = /&#?[a-z\d]+;|</
      PCDATAFilterRx = /(&#?[a-z\d]+;|<[^>]+>)|([^&<]+)/
      TagFilterRx = /(<[^>]+>)|([^<]+)/
      WordRx = /\S+/
      Hyphen = '-'
      SoftHyphen = ?\u00ad
      HyphenatedHyphen = '-' + SoftHyphen

      def capitalize_words_pcdata string
        if XMLMarkupRx.match? string
          string.gsub(PCDATAFilterRx) { $2 ? (capitalize_words_mb $2) : $1 }
        else
          capitalize_words_mb string
        end
      end

      def capitalize_words_mb string
        string.gsub(WordRx) { capitalize_mb $& }
      end

      def hyphenate_words_pcdata string, hyphenator
        if XMLMarkupRx.match? string
          string.gsub(PCDATAFilterRx) { $2 ? (hyphenate_words $2, hyphenator) : $1 }
        else
          hyphenate_words string, hyphenator
        end
      end

      def hyphenate_words string, hyphenator
        string.gsub(WordRx) { (hyphenator.visualize $&, SoftHyphen).gsub HyphenatedHyphen, Hyphen }
      end

      def lowercase_pcdata string
        if string.include? '<'
          string.gsub(TagFilterRx) { $2 ? (lowercase_mb $2) : $1 }
        else
          lowercase_mb string
        end
      end

      def uppercase_pcdata string
        if XMLMarkupRx.match? string
          string.gsub(PCDATAFilterRx) { $2 ? (uppercase_mb $2) : $1 }
        else
          uppercase_mb string
        end
      end

      def capitalize_mb string
        string.capitalize
      end

      def lowercase_mb string
        string.downcase
      end

      def uppercase_mb string
        string.upcase
      end
    end
  end
end
