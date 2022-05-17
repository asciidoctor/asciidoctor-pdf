class PDFConverterNarrowTOC < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_toc *_args
    indent 100, 100 do
      super
    end
  end
end
