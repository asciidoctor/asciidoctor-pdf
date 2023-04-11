module DrawWrapIndicator
  WrapIndicatorChar = ?\u23ce

  module_function

  def render_in_front fragment
    doc = fragment.document
    wrap_indicator_color = doc.theme.code_linenum_font_color
    wrap_indicator_width = doc.rendered_width_of_char WrapIndicatorChar
    wrap_indicator_fragment = { text: WrapIndicatorChar, color: wrap_indicator_color }
    wrap_indicator_fragment[:size] = doc.font_size * 0.75
    y_offset = (doc.font_size - wrap_indicator_fragment[:size]) * 0.5
    wrap_indicator_options = {
      document: doc,
      at: [doc.bounds.right - (wrap_indicator_width * 0.5), fragment.top - y_offset],
      width: wrap_indicator_width,
      align: :center,
    }
    doc.bounds.add_right_padding -wrap_indicator_width
    (::Prawn::Text::Formatted::Box.new [wrap_indicator_fragment], wrap_indicator_options).render
    doc.bounds.add_right_padding wrap_indicator_width
  end
end

module LineWrapWithIndicator
  def add_fragment_to_line fragment
    @arranger.consumed.last[:callback] = [DrawWrapIndicator] unless (return_val = super)
    return_val
  end
end

module WrapWithIndicator
  def wrap array
    @line_wrap.extend LineWrapWithIndicator
    super
  end
end

class PDFConverterCodeWithWrapIndicator < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def arrange_block node, &block
    return super if node.content_model != :verbatim || scratch?
    # replace previous line with next commented line if you don't want the wrap indicator when linenums are enabled
    #return super if node.content_model != :verbatim || (node.option? 'linenums') || scratch?
    super node do |extent|
      (block.binding.local_variable_get :extensions) << WrapWithIndicator if extent
      instance_exec extent, &block
    end
  end
end
