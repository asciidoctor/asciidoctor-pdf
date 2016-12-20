module Prawn; class Table; class Cell
  class AsciiDoc < Cell
    attr_accessor :align
    attr_accessor :valign

    def initialize pdf, opts = {}
      @font_options = {}
      super pdf, [], opts
    end

    def font_style= val
      @font_options[:style] = val
    end

    def text_color= val
      @font_options[:color] = val
    end

    def size= val
      @font_options[:size] = val
    end

    def font= val
      @font_options[:family] = val
    end

    # NOTE automatic image sizing only works if cell has fixed width
    def dry_run
      cell = self
      max_height = nil
      height, _, _ = @pdf.dry_run do
        max_height = bounds.height
        # NOTE we should be able to use cell.max_width, but returns 0 in some conditions (like when colspan > 1)
        indent cell.padding_left, bounds.width - cell.width + cell.padding_right do
          # HACK force margin_top to be applied
          move_down 0.0001
          # TODO truncate margin bottom of last block
          convert_content_for_block cell.content
        end
      end
      # FIXME prawn-table doesn't support cell taller than a single page
      [max_height, height].min
    end

    def natural_content_width
      # QUESTION can we get a better estimate of the natural width?
      @natural_width ||= (@pdf.bounds.width - padding_left - padding_right)
    end

    def natural_content_height
      # NOTE when natural_content_height is called, we already know max width
      @natural_height ||= dry_run
    end

    def draw_content
      pdf = @pdf
      # NOTE draw_bounded_content adds FPTolerance to width and height, which causes content to overflow
      pdf.bounds.instance_variable_set :@width, spanned_content_width
      pdf.bounds.instance_variable_set :@height, spanned_content_height
      if @valign != :top && (excess_y = spanned_content_height - natural_content_height) > 0
        pdf.move_down(@valign == :center ? (excess_y.fdiv 2) : excess_y)
      end
      # TODO apply horizontal alignment (right now must use alignment on content block)
      # QUESTION inherit table cell font properties?
      pdf.convert_content_for_block content
      nil
    end
  end
end; end; end
