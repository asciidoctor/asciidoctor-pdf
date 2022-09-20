class PDFConverterTableRole < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_table node
    return super unless node.role?
    key_prefix = %(role_<table>_#{node.roles[0]}_)
    role_entries = theme.each_pair.select {|name, val| name.to_s.start_with? key_prefix }
    return super if role_entries.empty?
    save_theme do
      role_entries.each do |name, val|
        theme[%(table_#{name.to_s.delete_prefix key_prefix})] = val
      end
      super
    end
  end
end
