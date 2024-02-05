class NoRunningContentOnEmptyPageConverter < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_running_content(*)
    state.pages.each do |page_|
      page_.imported if page_.empty?
    end

    # or you can switch to each page first in case you need to use additional logic

    # pgnum = page_number
    #(1..page_count).each do |pgnum_|
    #  go_to_page pgnum_
    #  page.imported if page.empty?
    #end
    # go_to_page pgnum

    # or you can add the page numbers to the sets of page numbers on which the running content is disabled
    #state.pages.each_with_index do |page_, idx|
    #  next unless page_.empty?
    #  pgnum = idx + 1
    #  @disable_running_content[:header] << pgnum
    #  @disable_running_content[:footer] << pgnum
    #end
    super
  end
end
