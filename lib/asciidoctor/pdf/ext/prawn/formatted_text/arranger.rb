Prawn::Text::Formatted::Arranger.send :prepend, (::Module.new do
  def apply_color_and_font_settings fragment, &block
    if (f_color = fragment.color)
      original_fill_color = @document.fill_color
      original_stroke_color = @document.stroke_color
      if f_color == 'transparent'
        @document.fill_color [0, 0, 0, 0]
        @document.stroke_color [0, 0, 0, 0]
        @document.transparent(0) { apply_font_settings fragment, &block }
      else
        @document.fill_color(*f_color)
        @document.stroke_color(*f_color)
        apply_font_settings fragment, &block
      end
      @document.stroke_color = original_stroke_color
      @document.fill_color = original_fill_color
    else
      apply_font_settings fragment, &block
    end
  end
end)
