class PDFConverterColumns < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def traverse node
    return super unless node.context == :document && (columns = theme.base_columns)
    column_box [0, cursor], columns: columns, width: bounds.width, reflow_margins: true, spacer: theme.base_column_gap do
      super
    end
  end
end
