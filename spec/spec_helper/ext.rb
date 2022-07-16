# frozen_string_literal: true

# NOTE: fix warning in Prawn::Font:TTF
Prawn::Font::TTF.prepend (Module.new do
  def initialize *args
    @italic_angle = nil
    super
  end
end)

# NOTE: fix warning in TTFunk::Table
TTFunk::Table.prepend (Module.new do
  def initialize *args
    @offset = nil
    super
  end
end)

PDF::Reader.prepend (Module.new do
  def source
    objects.instance_variable_get :@io
  end

  def catalog
    root
  end

  def outlines
    objects[catalog[:Outlines]]
  end
end)

PDF::Inspector::Text.prepend (Module.new do
  def page= page
    @page_number = page.number
    super
  end

  def move_text_position tx, ty
    @positions << [tx, ty, @page_number]
  end
end)
