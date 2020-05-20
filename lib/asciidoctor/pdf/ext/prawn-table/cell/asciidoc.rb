# frozen_string_literal: true

module Prawn
  class Table
    class Cell
      class AsciiDoc < Cell
        include ::Asciidoctor::Logging

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

        # NOTE: automatic image sizing only works if cell has fixed width
        def dry_run
          cell = self
          height = nil
          apply_font_properties do
            @pdf.dry_run do
              start_page = page
              start_cursor = cursor
              max_height = bounds.height
              # NOTE: we should be able to use cell.max_width, but returns 0 in some conditions (like when colspan > 1)
              indent cell.padding_left, bounds.width - cell.width + cell.padding_right do
                # HACK: force margin_top to be applied
                move_down 0.0001
                # TODO: truncate margin bottom of last block
                traverse cell.content
              end
              # FIXME: prawn-table doesn't support cells that exceed the height of a single page
              height = page == start_page ? start_cursor - (cursor + 0.0001) : max_height
            end
          end
          height
        end

        def natural_content_width
          # QUESTION can we get a better estimate of the natural width?
          @natural_content_width ||= (@pdf.bounds.width - padding_left - padding_right)
        end

        def natural_content_height
          # NOTE when natural_content_height is called, we already know max width
          @natural_content_height ||= dry_run
        end

        def draw_content
          pdf = @pdf
          # NOTE draw_bounded_content automatically adds FPTolerance to width and height
          pdf.bounds.instance_variable_set :@width, spanned_content_width
          # NOTE we've already reserved the space, so just let the box stretch to the bottom of the page to avoid overflow
          pdf.bounds.instance_variable_set :@height, pdf.page_content_height
          if @valign != :top && (excess_y = spanned_content_height - natural_content_height) > 0
            pdf.move_down(@valign == :center ? (excess_y.fdiv 2) : excess_y)
          end
          start_page = pdf.page_number
          # TODO: apply horizontal alignment (right now must use alignment on content block)
          # QUESTION inherit table cell font properties?
          apply_font_properties do
            pdf.traverse content
          end
          # FIXME: prawn-table doesn't support cells that exceed the height of a single page
          if (additional_pages = (end_page = pdf.page_number) - start_page) > 0
            logger.error %(the table cell on page #{end_page - additional_pages} has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page) unless additional_pages == 1 && pdf.at_page_top?
            additional_pages.times { pdf.delete_page }
          end
          nil
        end

        private

        def apply_font_properties
          # NOTE font_info holds font properties outside table; used as fallback values
          font_info = (pdf = @pdf).font_info
          font_color, font_family, font_size, font_style = @font_options.values_at :color, :family, :size, :style
          prev_font_color, pdf.font_color = pdf.font_color, font_color if font_color
          font_family ||= font_info[:family]
          if font_size
            prev_font_scale, pdf.font_scale = pdf.font_scale, (font_size.to_f / font_info[:size])
          else
            font_size = font_info[:size]
          end
          font_style ||= font_info[:style]
          pdf.font font_family, size: font_size, style: font_style do
            yield
          end
          pdf.font_color = prev_font_color if prev_font_color
          pdf.font_scale = prev_font_scale if prev_font_scale
        end
      end
    end
  end
end
