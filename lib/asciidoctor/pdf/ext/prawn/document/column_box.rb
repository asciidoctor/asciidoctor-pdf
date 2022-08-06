# frozen_string_literal: true

Prawn::Document::ColumnBox.prepend (Module.new do
  attr_accessor :current_column

  def last_column
    @columns - 1
  end

  def move_past_bottom
    (doc = @document).y = @y
    return if (@current_column = (@current_column + 1) % @columns) > 0
    parent_ = @parent
    reset_top parent_ if (reflow_at = @reflow_margins) && (reflow_at == true || reflow_at > doc.page_number)
    initial_margins = doc.page.margins
    parent_.move_past_bottom
    if doc.page.margins != initial_margins
      doc.bounds = self.class.new doc, parent_, [(margin_box = doc.margin_box).absolute_left, @y],
        columns: @columns, reflow_margins: @reflow_margins, spacer: @spacer, width: margin_box.width, height: @height
    end
    nil
  end

  def reset_top parent_ = @parent
    @current_column = 0
    @height = parent_.height unless stretchy?
    @y = parent_.absolute_top
  end

  # Rearranges the column box into a single column, where the original columns are in a single file. Used
  # for the purpose of computing the extent of content in a scratch document.
  def single_file
    if @reflow_margins && @parent.absolute_top > @y && @columns > @current_column + 1
      # defer reflow margins until all columns on current page have been exhausted
      @reflow_margins = @document.page_number + (@columns - @current_column)
    end
    @width = bare_column_width
    @columns = 1
    @current_column = 0
    nil
  end
end)
