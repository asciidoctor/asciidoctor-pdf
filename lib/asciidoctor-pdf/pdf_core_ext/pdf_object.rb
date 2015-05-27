module Asciidoctor
module PdfCore
module PdfObject
  # Convert the string to a PDF literal string if it can be encoded as ASCII-8BIT.
  # Otherwise, return the specified string.
  #--
  # QUESTION mixin to String and NilClass as to_pdf_value?
  def str2pdfval string
    if string && string.ascii_only?
      ::PDF::Core::LiteralString.new(string.encode ::Encoding::ASCII_8BIT)
    else
      string
    end
  end

  # Convert the string to a PDF object, first attempting to
  # convert it to a PDF literal string.
  #--
  # QUESTION mixin to String and NilClass as to_pdf_object?
  def str2pdfobj string
    ::PDF::Core::PdfObject(str2pdfval string)
  end
end
end
end
