# frozen_string_literal: true

# TODO: add these methods to Asciidoctor core
class Asciidoctor::List
  # Check whether this list is nested inside the item of another list.
  #
  # Return true if the parent of this list is a list item. Otherwise, return false.
  def nested?
    Asciidoctor::ListItem === @parent
  end unless method_defined? :nested?

  # Get the nesting level of this list within the broader list (unordered or ordered) structure.
  #
  # This method differs from the level property in that it considers only list ancestors.
  # It's important for selecting the marker for an unordered list.
  #
  # Return the 1-based level of this list within the list structure.
  def list_level
    l = 1
    ancestor = self
    # FIXME: does not cross out of AsciiDoc table cell
    while (ancestor = ancestor.parent)
      l += 1 if Asciidoctor::List === ancestor && (ancestor.context == :ulist || ancestor.context == :olist)
    end
    l
  end unless method_defined? :list_level
end
