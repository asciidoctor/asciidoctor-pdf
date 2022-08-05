class PDFConverterCenteredPartTitle < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_part_title node, title, opts = {}
    vertical_padding = (padding = expand_padding_value @theme.heading_h1_padding)[0] + padding[2]
    title_height = height_of_typeset_text title, inline_format: true, text_transform: @text_transform
    space_above = (effective_page_height - (title_height + vertical_padding)) * 0.5
    move_down space_above
    opts = opts.merge align: :center
    page.imported
    super
  end
end
