# frozen_string_literal: true

class Prawn::Table::Cell::Text
  include ::Asciidoctor::Logging

  # Override draw_content method to drop cursor advancement
  remove_method :draw_content
  def draw_content
    with_font do
      remaining_text = with_text_color do
        (text_box \
          width: spanned_content_width + FPTolerance,
          height: spanned_content_height + FPTolerance,
          at: [0, @pdf.cursor]).render
      end
      logger.error %(the table cell on page #{@pdf.page_number} has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page) unless remaining_text.empty? || @pdf.scratch?
    end
  end
end
