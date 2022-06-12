class PDFConverterSourceLanguageLabel < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def arrange_block node, &block
    return super unless node.style == 'source' && (lang = node.attr 'language')
    super node do |extent|
      current_column = bounds.current_column if ColumnBox === bounds
      return_val = instance_exec extent, &block
      if extent && !scratch?
        float do
          go_to_page extent.current.page
          bounds.current_column = current_column if ColumnBox === bounds
          (extent.from.page - extent.current.page).times { advance_page }
          move_cursor_to extent.from.cursor
          pad_box theme.code_padding, node do
            theme_font :code do
              ink_prose lang,
                align: :right,
                text_transform: :uppercase,
                margin: 0,
                color: theme.quote_cite_font_color
            end
          end
        end
      end
      return_val
    end
  end
end
