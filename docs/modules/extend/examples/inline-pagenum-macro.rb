Asciidoctor::Extensions.register do
  inline_macro :pagenum do
    format :short
    process do |parent|
      create_inline parent, :quoted, parent.document.converter.page_number.to_s
    end
  end
end
