# TODO add these methods to Asciidoctor core
class Asciidoctor::List
  # Check whether this list is an outline list (unordered or ordered).
  #
  # Return true if this list is an outline list. Otherwise, return false.
  def outline?
    @context == :ulist || @context == :olist
  end
end
