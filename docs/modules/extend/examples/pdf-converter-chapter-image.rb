class PDFConverterChapterImage < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_chapter_title sect, title, opts
    if (image_path = sect.attr 'image')
      image_attrs = { 'target' => image_path, 'pdfwidth' => '1in' }
      image_block = ::Asciidoctor::Block.new sect.document, :image, content_model: :empty, attributes: image_attrs
      convert_image image_block, relative_to_imagesdir: true, pinned: true
    end
    super
  end
end
