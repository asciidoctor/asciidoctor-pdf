class PDFConverterAvoidBreakAfterSectionTitle < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def arrange_section sect, title, opts = {}
    return if @y >= (@margin_box.absolute_top / 3) # <1>
    orphaned = nil
    dry_run single_page: true do # <2>
      start_page = page
      theme_font :heading, level: opts[:level] do
      if opts[:part]
        inscribe_part_title sect, title, opts # <3>
      elsif opts[:chapterlike]
        inscribe_chapter_title sect, title, opts # <3>
      else
        inscribe_general_heading sect, title, opts # <3>
      end
      if page == start_page
        page.tare_content_stream
        orphaned = stop_if_first_page_empty { traverse sect } # <4>
      end
    end
    start_new_page if orphaned # <5>
    nil
  end
end
