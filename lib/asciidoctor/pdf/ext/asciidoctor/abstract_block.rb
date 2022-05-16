# frozen_string_literal: true

Asciidoctor::AbstractBlock.prepend (Module.new do
  def empty?
    blocks.empty?
  end

  def first_child
    blocks[0]
  end

  def last_child
    blocks[-1]
  end

  def last_child?
    self == parent.blocks[-1]
  end

  def next_sibling
    (siblings = parent.blocks)[(siblings.index self) + 1]
  end

  def previous_sibling
    (self_idx = (siblings = parent.blocks).index self) > 0 ? siblings[self_idx - 1] : nil
  end

  def remove
    parent.blocks.delete self
  end
end)
