class PDFConverterCustomThematicBreak < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  # tag::convert_thematic_break[]
  def convert_thematic_break node
    theme_margin :thematic_break, :top
    stroke_horizontal_rule 'FF0000', line_width: 0.5, line_style: :solid
    move_down 1
    stroke_horizontal_rule 'FF0000', line_width: 1, line_style: :solid
    move_down 1
    stroke_horizontal_rule 'FF0000', line_width: 0.5, line_style: :solid
    theme_margin :thematic_break, ((block_next = next_enclosed_block node) ? :bottom : :top), block_next || true
  end
  # end::convert_thematic_break[]
end
