class PDFConverterArticleTitleWithAuthorAndDate < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_general_heading doc, title, opts
    return super unless opts[:role] == :doctitle # <1>
    ink_document_title title, opts # <2>
    ink_document_details doc, opts # <3>
    margin_bottom @theme[:heading_h1_margin_bottom] || @theme.heading_margin_bottom # <4>
  end

  def ink_document_title title, opts
    if (top_margin = @theme.heading_h1_margin_page_top || @theme.heading_margin_page_top) > 0
      move_down top_margin
    end
    pad_box @theme.heading_h1_padding do
      if (transform = resolve_text_transform opts)
        title = transform_text title, transform
      end
      if (inherited = apply_text_decoration font_styles, :heading, 1).empty?
        inline_format_opts = true
      else
        inline_format_opts = [{ inherited: inherited }]
      end
      typeset_text_opts = { color: @font_color, inline_format: inline_format_opts }.merge opts
      typeset_text title, (calc_line_metrics (opts.delete :line_height) || @base_line_height), typeset_text_opts 
    end
  end

  def ink_document_details doc, opts
    revremark = doc.attr 'revremark' # <5>
    if doc.author || doc.revdate || revremark # <6>
      move_down @theme.heading_h1_details_margin_top || 0 # <7>
      theme_font_cascade [:base, :heading_h1_details] do # <8>
        author_date_separator = doc.author && doc.revdate ? %( #{EmDash} ) : '' # <9>
        revremark_separator = (doc.author || doc.revdate) && revremark ? ' | ' : '' # <10>
        ink_prose %(#{doc.author}#{author_date_separator}#{doc.revdate}#{revremark_separator}#{revremark}), align: opts[:align] # <11>
      end
    end
  end
end
