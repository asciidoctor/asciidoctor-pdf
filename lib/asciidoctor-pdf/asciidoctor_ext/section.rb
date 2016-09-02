class Asciidoctor::Section
  def numbered_title opts = {}
    unless (@cached_numbered_title ||= nil)
      if (slevel = (@level == 0 && @special ? 1 : @level)) == 0
        @is_numbered = false
        @cached_numbered_title = @cached_formal_numbered_title = title
      elsif @numbered && !@caption && slevel <= (@document.attr 'sectnumlevels', 3).to_i
        @is_numbered = true
        @cached_numbered_title = %(#{sectnum} #{title})
        @cached_formal_numbered_title = if slevel == 1 && @document.doctype == 'book'
          %(#{@document.attr 'chapter-label', 'Chapter'} #{@cached_numbered_title}).lstrip
        else
          @cached_numbered_title
        end
      else
        @is_numbered = false
        @cached_numbered_title = @cached_formal_numbered_title = captioned_title
      end
    end
    opts[:formal] ? @cached_formal_numbered_title : @cached_numbered_title
  end unless method_defined? :numbered_title

  def part?
    @document.doctype == 'book' && @level == 0 && !@special
  end unless method_defined? :part?

  def chapter?
    @document.doctype == 'book' && (@level == 1 || (@special && @level == 0))
  end unless method_defined? :chapter?

  def part_or_chapter?
    @document.doctype == 'book' && @level < 2
  end unless method_defined? :part_or_chapter?
end
