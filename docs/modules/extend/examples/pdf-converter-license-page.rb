class PDFConverterLicensePage < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def traverse node
    return super unless node.context == :document
    start_new_page unless at_page_top?
    theme_font :heading, level: 2 do
      ink_heading 'License', level: 2
    end
    license_text = File.read 'LICENSE'
    theme_font :code do
      ink_prose license_text, normalize: false, align: :left, color: theme.base_font_color
    end
    start_new_page
    super
  end
end
