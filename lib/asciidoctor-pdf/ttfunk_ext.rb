# patch ttfunk 1.5.0; see https://github.com/prawnpdf/ttfunk/issues/39
class TTFunk::Subset::Base
  alias __checksum checksum
  def checksum data
    return 0 if data.length == 0
    __checksum data
  end
end
