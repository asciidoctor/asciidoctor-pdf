# frozen_string_literal: true
unless RUBY_VERSION >= '2.4'
  begin
    require 'unicode' unless defined? Unicode::VERSION
  rescue LoadError
    begin
      require 'active_support/multibyte' unless defined? ActiveSupport::Multibyte
    rescue LoadError; end
  end
end

module Asciidoctor
module PDF
module TextTransformer
  XMLMarkupRx = /&#?[a-z\d]+;|</
  PCDATAFilterRx = /(&#?[a-z\d]+;|<[^>]+>)|([^&<]+)/
  WordRx = /\S+/
  SoftHyphen = ?\u00ad

  def uppercase_pcdata string
    if XMLMarkupRx.match? string
      string.gsub(PCDATAFilterRx) { $2 ? (uppercase_mb $2) : $1 }
    else
      uppercase_mb string
    end
  end

  if RUBY_VERSION >= '2.4'
    def uppercase_mb string
      string.upcase
    end

    def lowercase_mb string
      string.downcase
    end
  # NOTE Unicode library is 4x as fast as ActiveSupport::MultiByte::Chars
  elsif defined? ::Unicode
    def uppercase_mb string
      string.ascii_only? ? string.upcase : (::Unicode.upcase string)
    end

    def lowercase_mb string
      string.ascii_only? ? string.downcase : (::Unicode.downcase string)
    end
  elsif defined? ::ActiveSupport::Multibyte
    MultibyteChars = ::ActiveSupport::Multibyte::Chars

    def uppercase_mb string
      string.ascii_only? ? string.upcase : (MultibyteChars.new string).upcase.to_s
    end

    def lowercase_mb string
      string.ascii_only? ? string.downcase : (MultibyteChars.new string).downcase.to_s
    end
  else
    def uppercase_mb string
      string.upcase
    end

    def lowercase_mb string
      string.downcase
    end
  end

  def hyphenate_pcdata string, hyphenator
    if XMLMarkupRx.match? string
      string.gsub(PCDATAFilterRx) { $2 ? (hyphenate_words $2, hyphenator) : $1 }
    else
      hyphenate_words string, hyphenator
    end
  end

  def hyphenate_words string, hyphenator
    string.gsub(WordRx) { hyphenator.visualize $&, SoftHyphen }
  end
end
end
end
