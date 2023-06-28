Asciidoctor::Extensions.register do
  tree_processor do
    process do |doc|
      doc.find_by context: :table do |table|
        unless (table.option? 'breakable') || (table.option? 'unbreakable')
          table.set_option 'breakable'
        end
      end
      doc
    end
  end
end
