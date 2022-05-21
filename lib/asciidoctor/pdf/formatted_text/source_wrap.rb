# frozen_string_literal: true

module Asciidoctor
  module PDF
    module FormattedText
      module SourceWrap
        NoBreakSpace = ?\u00a0

        # Override Prawn::Text::Formatted::Box#wrap method to add line numbers in source blocks.
        # Note that this implementation assumes that the :single_line option is falsy.
        def wrap array
          return super unless array[0][:linenum] # sanity check
          initialize_wrap array
          @line_wrap.extend SourceLineWrap
          highlight_line = stop = nil
          unconsumed = @arranger.unconsumed
          until stop
            if (first_fragment = unconsumed[0])[:linenum]
              linenum_text = first_fragment[:text]
              linenum_spacer ||= { text: (NoBreakSpace.encode linenum_text.encoding) + (' ' * (linenum_text.length - 1)), linenum: :spacer }
              highlight_line = (second_fragment = unconsumed[1])[:highlight] ? second_fragment.dup : nil
            else # wrapped line
              first_fragment[:text] = first_fragment[:text].lstrip
              @arranger.unconsumed.unshift highlight_line if highlight_line
              @arranger.unconsumed.unshift linenum_spacer.dup
            end
            @line_wrap.wrap_line \
              document: @document,
              kerning: @kerning,
              width: @width,
              arranger: @arranger,
              disable_wrap_by_char: @disable_wrap_by_char
            if enough_height_for_this_line?
              move_baseline_down
              print_line
              stop = @arranger.finished?
            else
              stop = true
            end
          end
          @text = @printed_lines.join ?\n
          @everything_printed = @arranger.finished?
          @arranger.unconsumed
        end
      end

      module SourceLineWrap
        def update_line_status_based_on_last_output
          @arranger.current_format_state[:linenum] ? nil : super
        end
      end
    end
  end
end
