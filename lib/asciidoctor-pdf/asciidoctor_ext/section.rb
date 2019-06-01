class Asciidoctor::Section
  def numbered_title opts = {}
    unless (@cached_numbered_title ||= nil)
      slevel = @level == 0 && @special ? 1 : @level
      if @numbered && !@caption && slevel <= (@document.attr 'sectnumlevels', 3).to_i
        @is_numbered = true
        @cached_formal_numbered_title = if @document.doctype == 'book'
          if slevel == 0
            @cached_numbered_title = %(#{sectnum nil, ':'} #{title})
            %(#{@document.attr 'part-signifier', 'Part'} #{@cached_numbered_title}).lstrip
          elsif slevel == 1
            @cached_numbered_title = %(#{sectnum} #{title})
            %(#{@document.attr 'chapter-signifier', (@document.attr 'chapter-label', 'Chapter')} #{@cached_numbered_title}).lstrip
          else
            @cached_numbered_title = %(#{sectnum} #{title})
          end
        else
          @cached_numbered_title = %(#{sectnum} #{title})
        end
      elsif slevel == 0
        @is_numbered = false
        @cached_numbered_title = @cached_formal_numbered_title = title
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
