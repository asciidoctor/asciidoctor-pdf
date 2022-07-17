# frozen_string_literal: true

unless (Pathname.instance_method :rmtree).arity > 0
  Pathname.prepend (Module.new do
    def rmtree **kwargs
      FileUtils.rm_rf @path, **kwargs
      nil
    end
  end)
end

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
