# frozen_string_literal: true

Prawn::Document.prepend (Module.new do
  # Wraps the column_box method and automatically sets the height unless the :height option is specified.
  def column_box point, options, &block
    options[:height] = cursor unless options.key? :height
    super
  end
end)

Prawn::Document::ColumnBox.prepend (Module.new do
  attr_accessor :current_column

  def move_past_bottom
    (doc = @document).y = @y
    return if (@current_column = (@current_column + 1) % @columns) > 0
    par = @parent
    if (reset_y = @reflow_margins) && (reset_y == true || reset_y > doc.page_number)
      @y = par.absolute_top
      @height = par.height unless stretchy?
    end
    initial_margins = doc.page.margins
    par.move_past_bottom
    if doc.page.margins != initial_margins
      doc.bounds = self.class.new doc, par, [(margin_box = doc.margin_box).absolute_left, @y],
        columns: @columns, reflow_margins: @reflow_margins, spacer: @spacer, width: margin_box.width, height: @height
    end
    nil
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
