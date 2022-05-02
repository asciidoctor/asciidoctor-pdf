class PDFConverterCustomPartTitle < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_part_title node, title, opts = {}
    fill_absolute_bounds 'E64C3D'
    move_down cursor * 0.25
    indent bounds.width * 0.5 do
      ink_prose title, line_height: 1.3, color: 'FFFFFF', inline_format: true, align: :right, size: 42, margin: 0
    end
    indent bounds.width * 0.33 do
      move_down 12
      stroke_horizontal_rule 'FFFFFF', line_width: 3
    end
    page.imported
  end
end
