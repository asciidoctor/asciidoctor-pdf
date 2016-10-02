class Object
  # Convert the object to a serialized PDF object.
  def to_pdf
    ::PDF::Core::PdfObject self
  end
end
