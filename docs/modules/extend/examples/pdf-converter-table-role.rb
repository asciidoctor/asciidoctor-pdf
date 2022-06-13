class PDFConverterTableRole < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_table node
    if node.role?
      key_prefix = %(role_<table>_#{node.roles[0]}_)
      unless (role_entries = theme.each_pair.select {|name, val| name.start_with? key_prefix }).empty?
        save_theme do
          role_entries.each do |name, val|
            theme[%(table_#{name.to_s.delete_prefix key_prefix})] = val
          end
          super
        end
        return
      end
    end
    super
  end
end
