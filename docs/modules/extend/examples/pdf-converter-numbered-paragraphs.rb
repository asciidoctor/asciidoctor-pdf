class PDFConverterNumberedParagraphs < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def init_pdf doc
    doc
      .find_by(context: :paragraph) {|candidate| [:document, :section].include? candidate.parent.context }
      .each_with_index {|paragraph, idx| paragraph.set_attr 'number', idx + 1 }
    super
  end

  def convert_paragraph node
    if (paragraph_number = node.attr 'number')
      float do
        label = %(#{paragraph_number}.#{::Prawn::Text::NBSP})
        label_width = rendered_width_of_string label
        bounding_box [-label_width, cursor], width: label_width do
          ink_prose label, color: 'CCCCCC', align: :right, margin: 0, single_line: true
        end
      end
    end
    super
  end
end
