# frozen_string_literal: true

require 'prawn/icon'
Prawn::Icon::Compatibility.prepend (Module.new { def warning *_args; end })
Prawn::Icon::FontData.prepend (Module.new do
  def load_fonts document
    if (family = document.font_families[@set.to_s])
      @path = family[:normal]
    else
      document.font_families[@set.to_s] = { normal: path }
    end
    self
  end

  def path
    @path ||= super
  end
end)
require_relative 'prawn-icon/legacy'
require_relative 'prawn-icon/interface'
