class PDFConverterLargeTables < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_table node
    if node.document.options[:scratch] || (!(node.attr? 'page-size') && !(node.attr? 'page-layout'))
      return super
    end
    prev_page_layout = page.layout
    prev_page_margin = page_margin
    prev_page_size = page.size
    table_page_size = (node.attr? 'page-size') ? (node.attr 'page-size') : page.size.to_s
    table_page_layout = (node.attr? 'page-layout') ? (node.attr 'page-layout') : page.layout.to_s
    all_attributes = (doc = node.document).attributes
    attributes = all_attributes.each_with_object({}) do |(k, v), accum|
      accum[k] = v if doc.attribute_locked? k
    end
    attributes['pdf-page-size'] = table_page_size
    attributes['pdf-page-layout'] = table_page_layout
    table_doc = Asciidoctor.load [], backend: 'pdf', safe: :safe, attributes: attributes, standalone: true, scratch: true
    all_attributes.each {|(k, v)| table_doc.set_attribute k, v if String === v }
    table_doc << node.dup
    table_doc.convert
    table_pdf = StringIO.new table_doc.converter.render
    pgnum = 0
    delete_current_page if page.empty?
    while (pgnum += 1)
      break unless import_page table_pdf, page: pgnum, advance: false, advance_if_missing: false
    end
    start_new_page layout: prev_page_layout, margin: prev_page_margin, size: prev_page_size
    nil
  end
end
