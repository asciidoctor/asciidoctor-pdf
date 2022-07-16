# frozen_string_literal: true

class ImageInspector < PDF::Inspector
  attr_reader :images

  def initialize
    @images = []
    @x = @y = @width = @height = nil
    @page_number = 0
  end

  def page= page
    @page_number = page.number
    @image_xobjects = page.xobjects.each_with_object({}) do |(name, xobject), accum|
      accum[name] = xobject if xobject.hash[:Subtype] == :Image
    end
  end

  def page_count
    @page_number
  end

  def concatenate_matrix width, _p2, _p3, height, x, y
    @width = width
    @height = height
    @x = x
    @y = y + height
  end

  def invoke_xobject name
    return unless @image_xobjects.key? name
    image_info = (image = @image_xobjects[name]).hash
    @images << { name: name, page_number: @page_number, x: @x, y: @y, width: @width, height: @height, intrinsic_height: image_info[:Height], intrinsic_width: image_info[:Width], data: image.data }
  end
end
