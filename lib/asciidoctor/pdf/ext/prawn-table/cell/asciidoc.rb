# frozen_string_literal: true

module Prawn
  class Table
    class Cell
      class AsciiDoc < Cell
        include ::Asciidoctor::Logging

        attr_accessor :align
        attr_accessor :root_font_size
        attr_accessor :valign

        def initialize pdf, opts = {}
          @font_options = {}
          @align = @valign = @root_font_size = nil
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
          parent_doc = (doc = content.document).nested? ? doc.parent_document : doc
          padding_y = cell.padding_top + cell.padding_bottom
          max_height = @pdf.bounds.height
          extent = nil
          apply_font_properties do
            extent = @pdf.dry_run keep_together: true, single_page: true do
              push_scratch parent_doc
              # NOTE: we should be able to use cell.max_width, but returns 0 in some conditions (like when colspan > 1)
              indent cell.padding_left, bounds.width - cell.width + cell.padding_right do
                move_down padding_y if padding_y > 0
                conceal_page_top { traverse cell.content }
              end
              pop_scratch parent_doc
            end
          end
          # NOTE: prawn-table doesn't support cells that exceed the height of a single page
          # NOTE: height does not include top/bottom padding, but must account for it when checking for overrun
          (extent.single_page_height || max_height) - padding_y
        end

        def natural_content_width
          # QUESTION: can we get a better estimate of the natural width?
          @natural_content_width ||= (@pdf.bounds.width - padding_left - padding_right)
        end

        def natural_content_height
          # NOTE: when natural_content_height is called, we already know max width
          @natural_content_height ||= dry_run
        end

        # NOTE: prawn-table doesn't support cells that exceed the height of a single page
        def draw_content
          if (pdf = @pdf).scratch?
            pdf.move_down natural_content_height
            return
          end
          # NOTE: draw_bounded_content automatically adds FPTolerance to width and height
          pdf.bounds.instance_variable_set :@width, spanned_content_width
          # NOTE: we've already reserved the space, so just let the box stretch to the maximum that could fit on a page
          pdf.bounds.instance_variable_set :@height, (pdf.margin_box.height - padding_top - padding_bottom)
          if @valign != :top && (excess_y = spanned_content_height - natural_content_height) > 0
            # QUESTION: could this cause a unexpected page overrun?
            pdf.move_down(@valign == :center ? (excess_y.fdiv 2) : excess_y)
          end
          # # use perform_on_single_page to prevent content from being written on extra pages
          # # the problem with this approach is that we don't know whether any content is written to next page
          # apply_font_properties do
          #   if (pdf.perform_on_single_page { pdf.traverse content })
          #     logger.error %(the table cell on page #{pdf.page_number} has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page)
          #   end
          # end
          start_page = pdf.page_number
          parent_doc = (doc = content.document).nested? ? doc.parent_document : doc
          doc.catalog[:footnotes] = parent_doc.catalog[:footnotes]
          # TODO: apply horizontal alignment; currently it is necessary to specify alignment on content blocks
          apply_font_properties { pdf.traverse content }
          if (extra_pages = pdf.page_number - start_page) > 0
            unless extra_pages == 1 && pdf.page.empty?
              logger.error message_with_context %(the table cell on page #{start_page} has been truncated; Asciidoctor PDF does not support table cell content that exceeds the height of a single page), source_location: @source_location
            end
            extra_pages.times { pdf.delete_current_page }
          end
          nil
        end

        private

        def apply_font_properties
          # NOTE: font_info holds font properties outside table; used as fallback values
          # QUESTION: should we inherit table cell font properties?
          font_info = (pdf = @pdf).font_info
          font_color, font_family, font_size, font_style = @font_options.values_at :color, :family, :size, :style
          prev_font_color, pdf.font_color = pdf.font_color, font_color if font_color
          font_family ||= font_info[:family]
          if font_size
            prev_font_scale, pdf.font_scale = pdf.font_scale, (font_size.to_f / @root_font_size)
          else
            font_size = font_info[:size]
          end
          font_style ||= font_info[:style]
          if (@align == :center || @align == :right) && content.blocks.map(&:context).uniq == [:paragraph]
            prev_text_align = pdf.instance_variable_get :@base_text_align
            pdf.instance_variable_set :@base_text_align, @align
          end
          pdf.font font_family, size: font_size, style: font_style do
            yield
          ensure
            pdf.font_color = prev_font_color if prev_font_color
            pdf.font_scale = prev_font_scale if prev_font_scale
            pdf.instance_variable_set :@base_text_align, prev_text_align if prev_text_align
          end
        end
      end
    end
  end
end
