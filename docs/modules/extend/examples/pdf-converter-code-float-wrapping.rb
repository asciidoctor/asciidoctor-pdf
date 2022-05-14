class PDFConverterCodeFloatWrapping < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def supports_float_wrapping? node
    %i(paragraph listing literal).include? node.context
  end

  def convert_code node
    return super unless (float_box = @float_box ||= nil)
    indent(float_box[:left] - bounds.left, bounds.width - float_box[:right]) { super }
    @float_box = nil unless page_number == float_box[:page] && cursor > float_box[:bottom]
  end
end
