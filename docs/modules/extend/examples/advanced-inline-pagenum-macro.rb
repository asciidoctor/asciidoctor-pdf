Asciidoctor::Extensions.register do
  inline_macro :pagenum do
    format :short
    parse_content_as :text
    process do |parent, scope|
      doc = parent.document
      if scope == 'section'
        if doc.nested?
          inner_doc = doc
          parent = (doc = doc.parent_document).find_by(context: :table_cell) do |it|
            it.style == :asciidoc && it.inner_document == inner_doc
          end.first
        end
        section = (closest parent, :section) || doc
        physical_pagenum = section.attr 'pdf-page-start'
      else
        physical_pagenum = doc.converter.page_number
      end
      create_inline parent, :quoted, %(#{physical_pagenum + 1 - (start_page_number doc)})
    end

    def closest node, context
      node.context == context ? node : ((parent = node.parent) && (closest parent, context))
    end

    def start_page_number doc
      doc.converter.index.start_page_number
    end
  end
end
