# frozen_string_literal: true

module Prawn::Text::Formatted::ProtectBottomGutter
  def enough_height_for_this_line?
    if @arranger.finished? && @arranger.fragments.none? {|it| it.format_state[:full_height] }
      begin
        @height -= @bottom_gutter
        super
      ensure
        @height += @bottom_gutter
      end
    else
      super
    end
  end
end
