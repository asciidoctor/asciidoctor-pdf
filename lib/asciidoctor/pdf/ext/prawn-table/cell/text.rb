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

  # Override the styled_width_of to account for hard line breaks
  remove_method :styled_width_of
  def styled_width_of text
    # NOTE: remove :style since it's handled by with_font
    options = @text_options.reject {|k| k == :style }
    if text.length > 3 && (text.include? '<br>')
      (text.split '<br>').map {|line| (line = line.strip).empty? ? 0 : with_font { @pdf.width_of line, options } }.max
    else
      with_font { @pdf.width_of text, options }
    end
  end
end
