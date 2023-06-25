# frozen_string_literal: true

class Prawn::Table::Cell::Text
  include ::Asciidoctor::Logging

  ImageTagRx = /<img(?: [^>]+ )?width="([^"]+)"[^>]*>/

  # Override draw_content method to drop cursor advancement
  remove_method :draw_content
  def draw_content
    with_font do
      self.valign = [:center, -font.descender * 0.5] if valign == :center
      (bounds = @pdf.bounds).instance_variable_set :@table_cell, true
      remaining_text = with_text_color do
        (text_box width: bounds.width, height: bounds.height, at: [0, @pdf.cursor]).render
      end
      unless remaining_text.empty? || @pdf.scratch?
        logger.error message_with_context %(the table cell on page #{@pdf.page_number} has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page), source_location: @source_location
      end
    end
  end

  # Override the styled_width_of to account for image widths and hard line breaks.
  # This method computes the width of the text without wrapping (so InlineImageArranger is not called).
  # This override also effectively backports the fix for prawn-table#42.
  remove_method :styled_width_of
  def styled_width_of text
    # NOTE: remove :style since it's handled by with_font
    options = @text_options.reject {|k| k == :style }
    width_of_images = 0
    if (inline_format = @text_options.key? :inline_format) && (text.include? '<img ')
      placeholder_width = styled_width_of 'M'
      text = text.gsub ImageTagRx do
        if (pctidx = $1.index '%')
          if pctidx == $1.length - 1
            # TODO: look up the intrinsic image width in pixels
            #width_of_images += (<image width> - placeholder_width)
            next ''
          else
            width_of_images += (($1.slice pctidx + 1, $1.length).to_f - placeholder_width)
          end
        else
          width_of_images += ($1.to_f - placeholder_width)
        end
        'M'
      end
    end
    if inline_format && text.length > 3 && (text.include? '<br>')
      (text.split '<br>').map {|line| (line = line.strip).empty? ? 0 : with_font { @pdf.width_of line, options } }.max + width_of_images
    else
      with_font { @pdf.width_of text, options } + width_of_images
    end
  end
end
