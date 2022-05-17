class PDFConverterChangeBars < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_paragraph node
    start_cursor = cursor
    super
    if node.role? 'changed'
      float do
        bounding_box [bounds.left - 4, start_cursor], width: 2, height: (start_cursor - cursor) do
          fill_bounds 'FF0000'
        end
      end
    end
  end
end
