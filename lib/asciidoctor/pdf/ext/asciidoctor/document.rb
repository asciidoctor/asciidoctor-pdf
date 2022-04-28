# frozen_string_literal: true

class Asciidoctor::Document
  # promote preface block (i.e., preamble block with title in book doctype) to preface section
  # FIXME: this should be handled by core
  def promote_preface_block
    if doctype == 'book' && (blk0 = blocks[0])&.context == :preamble && blk0.title? && !blk0.title.nil_or_empty? &&
        blk0.blocks[0]&.style != 'abstract' && (blk1 = blocks[1])&.context == :section
      preface = Asciidoctor::Section.new self, blk1.level, false, attributes: { 1 => 'preface', 'style' => 'preface' }
      preface.special = true
      preface.sectname = 'preface'
      preface.title = blk0.instance_variable_get :@title
      preface.id = preface.generate_id
      if (first_child = blk0.blocks[0])&.option? 'notitle'
        preface.set_option 'notitle'
        first_child.role = 'lead' if first_child.context == :paragraph && !first_child.role?
      end
      preface.blocks.replace (blk0.blocks.map do |b|
        b.parent = preface
        b
      end)
      blocks[0] = preface
    end
    nil
  end
end
