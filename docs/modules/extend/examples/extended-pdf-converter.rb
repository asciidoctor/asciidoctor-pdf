class ExtendedPDFConverter < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  # overrides go here
end
