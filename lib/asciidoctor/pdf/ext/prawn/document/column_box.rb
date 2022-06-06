# frozen_string_literal: true

Prawn::Document::ColumnBox.prepend (Module.new do
  def absolute_bottom
    stretchy? ? @parent.absolute_bottom : super
  end

  def move_past_bottom
    (doc = @document).y = @y
    return if (@current_column = (@current_column + 1) % @columns) > 0
    par = @parent
    @y = par.absolute_top if @reflow_margins
    initial_margins = doc.page.margins
    par.move_past_bottom
    if doc.page.margins != initial_margins
      doc.bounds = self.class.new doc, par, (margin_box = doc.margin_box).absolute_top_left,
        columns: @columns, reflow_margins: true, spacer: @spacer, width: margin_box.width
    end
    nil
  end
end)
