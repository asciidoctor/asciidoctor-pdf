class PDFConverterArticleTitleWithAuthorAndDate < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_general_heading doc, title, opts
    return super unless opts[:role] == :doctitle # <1>
    theme_font :heading_doctitle do
      ink_prose title, align: :center # <2>
    end
    revremark = doc.attr 'revremark' # <3>
    if doc.author || doc.revdate || revremark # <4>
      theme_font :base do
        author_date_separator = (doc.author && doc.revdate) ? ' – ' : '' # <5>
        revremark_separator = ((doc.author || doc.revdate) && revremark) ? ' | ' : '' # <6>
        ink_prose %(#{doc.author}#{author_date_separator}#{doc.revdate}#{revremark_separator}#{revremark}), align: :center # <7>
      end
    end
    theme_margin :heading_doctitle, :bottom
  end
end
