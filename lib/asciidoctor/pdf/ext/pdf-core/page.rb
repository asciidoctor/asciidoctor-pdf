# frozen_string_literal: true

class PDF::Core::Page
  InitialPageContent = %(q\n)

  # Record the page's current state as the tare content stream (i.e., empty, meaning no content has been written).
  def tare_content_stream
    @tare_content_stream = content.stream.filtered_stream
  end

  # Returns whether the current page is empty based on tare content stream (i.e., no content has been written).
  # Returns false if a page has not yet been created.
  def empty?
    content.stream.filtered_stream == (@tare_content_stream ||= InitialPageContent) && document.page_number > 0
  end

  # Flags this page as imported.
  #
  def imported
    @imported_page = true
  end

  alias imported_page imported

  # Reset the content of the page.
  # Note that this method may leave behind an orphaned background image.
  def reset_content
    return if content.stream.filtered_stream == InitialPageContent
    xobjects.clear
    ext_gstates.clear
    new_content = document.state.store[document.ref({})]
    new_content << 'q' << ?\n
    content.replace new_content
    @tare_content_stream = InitialPageContent
    nil
  end
end
