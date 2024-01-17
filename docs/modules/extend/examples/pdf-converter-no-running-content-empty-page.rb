class NoRunningContentOnEmptyPageConverter < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_running_content(*)
    state.pages.each do |page_|
      page_.imported if page_.empty?
    end
    # or
    #(1..page_count).each do |pgnum|
    #  go_to_page pgnum
    #  page.imported if page.empty?
    #  ## to write content to an empty page, use this next statement instead
    #  #ink_prose ' ' if page.empty?
    #end
    super
  end
end
