# frozen_string_literal: true

Prawn::Document::ColumnBox.prepend (Module.new do
  def absolute_bottom
    stretchy? ? @parent.absolute_bottom : super
  end

  def move_past_bottom
    initial_page = @document.page
    super
    if (page = @document.page) != initial_page && page.margins != initial_page.margins
      @document.bounds = self.class.new @document, @parent, (margin_box = @document.margin_box).absolute_top_left,
        columns: @columns, reflow_margins: true, spacer: @spacer, width: margin_box.width
    end
  end
end)
