# frozen_string_literal: true

Asciidoctor::Section.prepend (Module.new do
  def numbered_title opts = {}
    idx = opts[:toc] ? 1 : 0
    stitle = opts[:toc] ? toc_title : title
    @cached_numbered_title ||= Array.new(2)
    @cached_formal_numbered_title ||= Array.new(2)
    unless @cached_numbered_title[idx]
      doc = @document
      if @numbered && !@caption && (slevel = @level) <= (doc.attr 'sectnumlevels', 3).to_i
        @is_numbered = true
        if doc.doctype == 'book'
          case slevel
          when 0
            numbered_title = %(#{sectnum nil, ':'} #{stitle})
            signifier = doc.attributes['part-signifier'] || ((doc.attr_unspecified? 'part-signifier') ? 'Part' : '')
            formal_numbered_title = %(#{signifier}#{signifier.empty? ? '' : ' '}#{numbered_title})
          when 1
            numbered_title = %(#{sectnum} #{stitle})
            signifier = doc.attributes['chapter-signifier'] || ((doc.attr_unspecified? 'chapter-signifier') ? 'Chapter' : '')
            formal_numbered_title = %(#{signifier}#{signifier.empty? ? '' : ' '}#{numbered_title})
          else
            formal_numbered_title = numbered_title = %(#{sectnum} #{stitle})
          end
        else
          formal_numbered_title = numbered_title = %(#{sectnum} #{stitle})
        end
      elsif @level == 0
        @is_numbered = false
        numbered_title = formal_numbered_title = stitle
      else
        @is_numbered = false
        numbered_title = formal_numbered_title = opts[:toc] ? captioned_toc_title : captioned_title
      end
      @cached_numbered_title[idx] = numbered_title
      @cached_formal_numbered_title[idx] = formal_numbered_title
    end
    opts[:formal] ? @cached_formal_numbered_title[idx] : @cached_numbered_title[idx]
  end

  def first_section_of_part?
    (par = @parent).context == :section && par.sectname == 'part' && self == par.blocks.find {|it| it.context == :section }
  end
end)
