class PDFConverterCustomTitlePage < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_title_page doc
    move_cursor_to page_height * 0.75
    theme_font :title_page do
      stroke_horizontal_rule '2967B2', line_width: 1.5, line_style: :double
      move_down 10
      doctitle = doc.doctitle partition: true
      theme_font :title_page_title do
        ink_prose doctitle.main, align: :center, color: theme.base_font_color, line_height: 1, margin: 0
      end
      if (subtitle = doctitle.subtitle)
        theme_font :title_page_subtitle do
          move_down 10
          ink_prose subtitle, align: :center, margin: 0
          move_down 10
        end
      end
      stroke_horizontal_rule '2967B2', line_width: 1.5, line_style: :double
      move_cursor_to page_height * 0.5
      convert ::Asciidoctor::Block.new doc, :image,
        content_model: :empty,
        attributes: { 'target' => 'sample-logo.jpg', 'pdfwidth' => '1.5in', 'align' => 'center' },
        pinned: true
    end
  end
end
