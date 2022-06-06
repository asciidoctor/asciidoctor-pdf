class PDFConverterColumns < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def traverse node
    if node.context == :document &&
        (columns = ColumnBox === bounds ? 1 : theme.base_columns || 1) > 1
      column_box [bounds.left, cursor],
        columns: columns,
        width: bounds.width,
        reflow_margins: true,
        spacer: theme.base_column_gap do
        super
      end
    else
      super
    end
  end
end
