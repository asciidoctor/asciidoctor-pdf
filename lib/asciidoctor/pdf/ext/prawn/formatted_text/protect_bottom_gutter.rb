# frozen_string_literal: true

module Prawn::Text::Formatted::ProtectBottomGutter
  def enough_height_for_this_line?
    return super unless @arranger.finished?
    begin
      @height -= @bottom_gutter
      super
    ensure
      @height += @bottom_gutter
    end
  end
end
