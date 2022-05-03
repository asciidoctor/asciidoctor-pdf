# frozen_string_literal: true

module Asciidoctor
  module PDF
    module TextTransformer
      XMLMarkupRx = /&#?[a-z\d]+;|</
      PCDATAFilterRx = /(&#?[a-z\d]+;|<[^>]+>)|([^&<]+)/
      TagFilterRx = /(<[^>]+>)|([^<]+)/
      ContiguousCharsRx = /\p{Graph}+/
      WordRx = /\p{Word}+/
      Hyphen = '-'
      SoftHyphen = ?\u00ad
      LowerAlphaChars = 'a-z'
      # NOTE: use more widely-supported ғ instead of ꜰ as replacement for F
      # NOTE: use more widely-supported ǫ instead of ꞯ as replacement for Q
      # NOTE: use more widely-supported s (lowercase latin "s") instead of ꜱ as replacement for S
      # NOTE: in small caps, x (lowercase latin "x") remains unchanged
      SmallCapsChars = 'ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴoᴘǫʀsᴛᴜᴠᴡxʏᴢ'

      def capitalize_words_pcdata string
        if XMLMarkupRx.match? string
          string.gsub(PCDATAFilterRx) { $2 ? (capitalize_words $2) : $1 }
        else
          capitalize_words string
        end
      end

      def capitalize_words string
        string.gsub(ContiguousCharsRx) { $&.capitalize }
      end

      def hyphenate_words_pcdata string, hyphenator
        if XMLMarkupRx.match? string
          string.gsub(PCDATAFilterRx) { $2 ? (hyphenate_words $2, hyphenator) : $1 }
        else
          hyphenate_words string, hyphenator
        end
      end

      def hyphenate_words string, hyphenator
        string.gsub(WordRx) { hyphenator.visualize $&, SoftHyphen }
      end

      def lowercase_pcdata string
        if string.include? '<'
          string.gsub(TagFilterRx) { $2 ? $2.downcase : $1 }
        else
          string.downcase
        end
      end

      def uppercase_pcdata string
        if XMLMarkupRx.match? string
          string.gsub(PCDATAFilterRx) { $2 ? $2.upcase : $1 }
        else
          string.upcase
        end
      end

      def smallcaps_pcdata string
        if XMLMarkupRx.match? string
          string.gsub(PCDATAFilterRx) { $2 ? ($2.tr LowerAlphaChars, SmallCapsChars) : $1 }
        else
          string.tr LowerAlphaChars, SmallCapsChars
        end
      end
    end
  end
end
