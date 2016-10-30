begin
  require 'unicode' unless defined? Unicode::VERSION
rescue LoadError
  begin
    require 'active_support/multibyte' unless defined? ActiveSupport::Multibyte
  rescue LoadError; end
end

module Asciidoctor
module Pdf
module Sanitizer
  BuiltInEntityChars = {
    '&lt;' => '<',
    '&gt;' => '>',
    '&amp;' => '&'
  }
  BuiltInEntityCharRx = /(?:#{BuiltInEntityChars.keys * '|'})/
  BuiltInEntityCharOrTagRx = /(?:#{BuiltInEntityChars.keys * '|'}|<)/
  InverseBuiltInEntityChars = BuiltInEntityChars.invert
  InverseBuiltInEntityCharRx = /[#{InverseBuiltInEntityChars.keys.join}]/
  NumericCharRefRx = /&#(\d{2,6});/
  XmlSanitizeRx = /<[^>]+>/
  SegmentPcdataRx = /(?:(&[a-z]+;|<[^>]+>)|([^&<]+))/

  # Strip leading, trailing and repeating whitespace, remove XML tags and
  # resolve all entities in the specified string.
  #
  # FIXME move to a module so we can mix it in elsewhere
  # FIXME add option to control escaping entities, or a filter mechanism in general
  def sanitize string
    string.strip
        .gsub(XmlSanitizeRx, '')
        .tr_s(' ', ' ')
        .gsub(NumericCharRefRx) { [$1.to_i].pack('U*') }
        .gsub(BuiltInEntityCharRx, BuiltInEntityChars)
  end

  def escape_xml string
    string.gsub InverseBuiltInEntityCharRx, InverseBuiltInEntityChars
  end

  def uppercase_pcdata string
    if BuiltInEntityCharOrTagRx =~ string
      string.gsub(SegmentPcdataRx) { $2 ? (uppercase_mb $2) : $1 }
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
end
end
end
