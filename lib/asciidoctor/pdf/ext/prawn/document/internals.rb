# frozen_string_literal: true

# TODO: remove after upgrading to Prawn 2.5.0
# NOTE: for some reason, using Module.prepend doesn't work in this case on Ruby 2.7
module Prawn::Document::Internals
  def save_graphics_state state = nil, &block
    save_transformation_stack
    renderer.save_graphics_state state, &block
    restore_transformation_stack if block_given?
  end
end
