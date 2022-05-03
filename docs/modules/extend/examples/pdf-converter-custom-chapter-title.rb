class PDFConverterCustomChapterTitle < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_chapter_title node, title, opts = {}
    move_down cursor * 0.25
    ink_heading title, (opts.merge align: :center, text_transform: :uppercase)
    stroke_horizontal_rule 'DDDDDD', line_width: 2
    move_down theme.block_margin_bottom
    theme_font :base do
      layout_prose 'Custom text here, maybe a chapter preamble.'
    end
    start_new_page
  end
end
