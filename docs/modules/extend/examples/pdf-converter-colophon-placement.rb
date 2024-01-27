class AsciidoctorPDFExtensions < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_toc doc, num_levels, toc_page_number, start_cursor, num_front_matter_pages = 0
    colophon = (doc.instance_variable_get :@colophon) || (doc.sections.find {|sect| sect.sectname == 'colophon' })
    return super unless colophon
    go_to_page toc_page_number unless (page_number == toc_page_number) || scratch?
    if scratch?
      (doc.instance_variable_set :@colophon, colophon).parent.blocks.delete colophon
    else
      # if doctype=book and media=prepress, use blank page before table of contents
      go_to_page page_number.pred if @ppbook
      colophon.set_option 'nonfacing' # ensure colophon is configured to be non-facing
      convert_section colophon
      go_to_page page_number.next
    end
    offset = @ppbook ? 0 : 1
    toc_page_numbers = super doc, num_levels, (toc_page_number + offset), start_cursor, num_front_matter_pages
    scratch? ? ((toc_page_numbers.begin - offset)..toc_page_numbers.end) : toc_page_numbers
  end
end
