class Prawn::Table::Cell::Text
  # Override draw_content method to drop cursor advancement
  def draw_content
    with_font do
      with_text_color do
        (text_box :width => spanned_content_width + FPTolerance,
            :height => spanned_content_height + FPTolerance,
            :at => [0, @pdf.cursor]).render
      end
    end
  end
end
