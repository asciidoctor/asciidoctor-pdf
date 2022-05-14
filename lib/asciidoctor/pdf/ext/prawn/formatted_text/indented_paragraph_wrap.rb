# frozen_string_literal: true

module Prawn::Text::Formatted
  module IndentedParagraphWrap
    # Override Prawn::Text::Formatted::Box#wrap method to add support for :indent_paragraphs to (formatted_)text_box.
    def wrap array
      initialize_wrap array
      stop = nil
      until stop
        if (first_line_indent = @indent_paragraphs) && @printed_lines.empty?
          @width -= first_line_indent
          stop = @document.indent(first_line_indent) { wrap_and_print_line }
          @width += first_line_indent
        else
          stop = wrap_and_print_line
        end
      end
      @text = @printed_lines.join ?\n
      @everything_printed = @arranger.finished?
      @arranger.unconsumed
    end

    def wrap_and_print_line
      @line_wrap.wrap_line \
        document: @document,
        kerning: @kerning,
        width: @width,
        arranger: @arranger,
        disable_wrap_by_char: @disable_wrap_by_char
      if enough_height_for_this_line?
        move_baseline_down
        print_line
        @single_line || @arranger.finished?
      else
        true
      end
    end
  end
end
