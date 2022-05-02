class PDFConverterChapterTOC < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_section sect, opts = {}
    result = super
    if (toc_extent = sect.attr 'pdf-toc-extent')
      levels = (sect.document.attr 'chapter-toclevels', 1).to_i + 1
      page_numbering_offset = @index.start_page_number - 1
      float do
        ink_toc sect, levels, toc_extent.from.page, toc_extent.from.cursor, page_numbering_offset
      end
    end
    result
  end

  def ink_chapter_title sect, title, opts
    super
    if ((doc = sect.document).attr? 'chapter-toc') && (levels = (doc.attr 'chapter-toclevels', 1).to_i + 1) > 1
      old_toc_extent = @toc_extent
      theme_font :base do
        sect.set_attr 'pdf-toc-extent', (allocate_toc sect, levels, cursor, false)
      end
      @toc_extent = old_toc_extent
    end
  end
end
