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
module Sanitizer
  XMLSpecialChars = {
    '&lt;' => ?<,
    '&gt;' => ?>,
    '&amp;' => ?&,
  }
  XMLSpecialCharsRx = /(?:#{XMLSpecialChars.keys * ?|})/
  InverseXMLSpecialChars = XMLSpecialChars.invert
  InverseXMLSpecialCharsRx = /[#{InverseXMLSpecialChars.keys.join}]/
  (BuiltInNamedEntities = {
    'amp' => ?&,
    'apos' => ?',
    'gt' => ?>,
    'lt' => ?<,
    'nbsp' => ' ',
    'quot' => ?",
  }).default = ??
  SanitizeXMLRx = /<[^>]+>/
  XMLMarkupRx = /&#?[a-z\d]+;|</
  CharRefRx = /&(?:([a-z][a-z]+\d{0,2})|#(?:(\d\d\d{0,4})|x([a-f\d][a-f\d][a-f\d]{0,3})));/
  SiftPCDATARx = /(&#?[a-z\d]+;|<[^>]+>)|([^&<]+)/

  # Strip leading, trailing and repeating whitespace, remove XML tags and
  # resolve all entities in the specified string.
  #
  # FIXME move to a module so we can mix it in elsewhere
  # FIXME add option to control escaping entities, or a filter mechanism in general
  def sanitize string
    string.strip
        .gsub(SanitizeXMLRx, '')
        .tr_s(' ', ' ')
        .gsub(CharRefRx) { $1 ? BuiltInNamedEntities[$1] : [$2 ? $2.to_i : ($3.to_i 16)].pack('U1') }
  end

  def escape_xml string
    string.gsub InverseXMLSpecialCharsRx, InverseXMLSpecialChars
  end

  def encode_quotes string
    (string.include? ?") ? (string.gsub ?", '&quot;') : string
  end

  def uppercase_pcdata string
    if XMLMarkupRx.match? string
      string.gsub(SiftPCDATARx) { $2 ? (uppercase_mb $2) : $1 }
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
