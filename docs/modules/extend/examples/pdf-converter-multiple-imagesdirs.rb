class PDFConverterMultipleImagesdirs < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def resolve_image_path node, image_path, image_format, relative_to = true
    if relative_to == true
      unless File.file? image_path
        docdir = (doc = node.document).attr 'docdir'
        %w(imagesdir imagesdir2).each do |attr_name|
          imagesdir = (doc.attr attr_name) || ''
          abs_imagesdir = File.absolute_path imagesdir, docdir
          next unless File.file? (File.absolute_path image_path, abs_imagesdir)
          relative_to = abs_imagesdir
          break
        end
      end
    end
    super
  end
end
