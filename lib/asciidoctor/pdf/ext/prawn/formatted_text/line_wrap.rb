# frozen_string_literal: true

Prawn::Text::Formatted::LineWrap.prepend (Module.new do
  def add_fragment_to_line fragment
    case fragment
    when ''
      true
    when ?\n
      @newline_encountered = true
      false
    else
      if (joined_string = @arranger.preview_joined_string)
        joined_string_width = @document.width_of (tokenize joined_string)[0], kerning: @kerning
      else
        joined_string_width = 0
      end
      last_idx = (segments = tokenize fragment).length - 1
      segments.each_with_index do |segment, idx|
        if segment == (zero_width_space segment.encoding)
          segment_width = effective_segment_width = 0
        else
          segment_width = effective_segment_width = @document.width_of segment, kerning: @kerning
          effective_segment_width += joined_string_width if idx === last_idx
        end
        if @accumulated_width + effective_segment_width <= @width
          @accumulated_width += segment_width
          if segment[-1] == (shy = soft_hyphen segment.encoding)
            @accumulated_width -= (@document.width_of shy, kerning: @kerning)
          end
          @fragment_output += segment
        else
          @line_contains_more_than_one_word = false if @accumulated_width == 0 && @line_contains_more_than_one_word
          end_of_the_line_reached segment
          fragment_finished fragment
          return false
        end
      end
      fragment_finished fragment
      true
    end
  end
end)
