class PDFConverterAdmonitionThemePerType < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_admonition node
    type = node.attr 'name'
    key_prefix = %(admonition_#{type}_)
    entries = theme.each_pair.select {|name, val| name.to_s.start_with? key_prefix }
    return super if entries.empty?
    save_theme do
      entries.each do |name, val|
        theme[%(admonition_#{name.to_s.delete_prefix key_prefix})] = val
      end
      super
    end
  end
end
