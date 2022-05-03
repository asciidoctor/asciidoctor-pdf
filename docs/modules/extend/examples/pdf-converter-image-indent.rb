class PDFConverterImageIndent < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_image node
    if (image_indent = theme.image_indent)
      indent(*Array(image_indent)) { super }
    else
      super
    end
  end
end
