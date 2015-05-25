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
  NumericCharRefRx = /&#(\d{2,4});/
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

  def upcase_pcdata string
    if BuiltInEntityCharOrTagRx =~ string
      string.gsub(SegmentPcdataRx) { $2 ? $2.upcase : $1 }
    else
      string.upcase
    end
  end
end
end
end
