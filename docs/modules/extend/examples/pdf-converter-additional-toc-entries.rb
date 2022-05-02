class PDFConverterAdditionalTOCEntries < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def get_entries_for_toc node
    return super if node.context == :document
    node.blocks.select do |candidate|
      candidate.context == :section ||
        (candidate.id && (candidate.title? || candidate.reftext?))
    end
  end
end
