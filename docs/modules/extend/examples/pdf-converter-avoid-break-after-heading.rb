class PDFConverterAvoidBreakAfterSectionTitle < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def arrange_heading node, title, opts
    return if y >= page_height / 3 # <1>
    orphaned = nil
    dry_run single_page: true do # <2>
      start_page = page
      theme_font :heading, level: opts[:level] do
        if opts[:part]
          ink_part_title node, title, opts # <3>
        elsif opts[:chapterlike]
          ink_chapter_title node, title, opts # <3>
        else
          ink_general_heading node, title, opts # <3>
        end
      end
      if page == start_page
        page.tare_content_stream
        orphaned = stop_if_first_page_empty do # <4>
          if node.context == :section
            traverse node
          else # discrete heading
            convert (siblings = node.parent.blocks)[(siblings.index node).next]
          end
        end
      end
    end
    advance_page if orphaned # <5>
    nil
  end
end
