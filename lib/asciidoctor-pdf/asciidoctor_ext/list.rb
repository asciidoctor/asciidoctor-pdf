# TODO add these methods to Asciidoctor core
class Asciidoctor::List
  # Check whether this list is an outline list (unordered or ordered).
  #
  # Return true if this list is an outline list. Otherwise, return false.
  def outline?
    @context == :ulist || @context == :olist
  end unless method_defined? :outline?

  # Check whether this list is nested inside the item of another list.
  #
  # Return true if the parent of this list is a list item. Otherwise, return false.
  def nested?
    Asciidoctor::ListItem === @parent
  end unless method_defined? :nested?
end
