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
          %(Chapter #{@cached_numbered_title})
        else
          @cached_numbered_title
        end
      else
        @is_numbered = false
        @cached_numbered_title = @cached_formal_numbered_title = captioned_title
      end
    end
    opts[:formal] ? @cached_formal_numbered_title : @cached_numbered_title
  end unless respond_to? :numbered_title

  def chapter?
    @document.doctype == 'book' && @level == 1 || (@special && @level == 0)
  end
end
