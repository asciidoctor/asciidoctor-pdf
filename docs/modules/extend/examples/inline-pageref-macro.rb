Asciidoctor::Extensions.register do
  inline_macro :pageref do
    process do |parent, refid|
      doc = (doc = parent.document).nested? ? doc.parent_document : doc
      if (ref = doc.catalog[:refs][refid])
        section = (closest ref, :section) || doc
        unless (physical_pagenum = section.attr 'pdf-page-start')
          doc.instance_variable_set :@pass, 1 unless (doc.instance_variable_get :@pass) == 2
          next create_inline parent, :quoted, '00' # reserve space for real page number
        end
        attributes = { 'refid' => refid, 'fragment' => refid, 'path' => nil }
        create_anchor parent, %(#{physical_pagenum + 1 - (start_page_number doc)}), { type: :xref, attributes: attributes }
      else
        create_inline parent, :quoted, '???'
      end
    end

    def closest node, context
      node.context == context ? node : ((parent = node.parent) && (closest parent, context))
    end

    def start_page_number doc
      doc.converter.index.start_page_number
    end
  end

  postprocessor do
    process do |doc|
      if (doc.instance_variable_get :@pass) == 1
        doc.instance_variable_set :@pass, 2
        doc.convert # WARNING: this may have side effects
      end
      doc.converter
    end
  end
end
