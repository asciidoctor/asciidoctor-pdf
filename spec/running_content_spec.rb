require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Running Content' do
  context 'Activation' do
    it 'should not attempt to add running content if document has no body' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      EOS

      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql 'Document Title'
    end

    it 'should add running content if document is empty (single blank page)' do
      pdf = to_pdf '', enable_footer: true, analyze: true
      text = pdf.text
      (expect text).to have_size 1
      (expect text[0][:string]).to eql '1'
    end

    it 'should start adding running content to page after imported page' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      image::blue-letter.pdf[]

      first non-imported page
      EOS

      pages = pdf.pages
      (expect pages).to have_size 2
      (expect pdf.find_text page_number: 1).to be_empty
      p2_text = pdf.find_text page_number: 2
      (expect p2_text).to have_size 2
      (expect p2_text[0][:string]).to eql 'first non-imported page'
      (expect p2_text[0][:order]).to eql 1
      (expect p2_text[1][:string]).to eql '2'
      (expect p2_text[1][:order]).to eql 2
    end
  end

  context 'Footer' do
    it 'should add running footer showing virtual page number starting at body by default' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title
      :doctype: book

      first page

      <<<

      second page

      <<<

      third page

      <<<

      fourth page
      EOS

      expected_page_numbers = %w(1 2 3 4)
      expected_x_positions = [541.009, 49.24]

      (expect pdf.pages).to have_size 5
      page_number_texts = pdf.find_text %r/^\d+$/
      (expect page_number_texts).to have_size expected_page_numbers.size
      page_number_texts.each_with_index do |page_number_text, idx|
        (expect page_number_text[:page_number]).to eql idx + 2
        (expect page_number_text[:x]).to eql expected_x_positions[idx.even? ? 0 : 1]
        (expect page_number_text[:y]).to eql 14.263
        (expect page_number_text[:font_size]).to eql 9
      end
    end

    it 'should not add running footer if nofooter attribute is set' do
      pdf = to_pdf <<~'EOS', enable_footer: false, analyze: true
      = Document Title
      :nofooter:
      :doctype: book

      body
      EOS

      (expect pdf.find_text %r/^\d+$/).to be_empty
    end

    it 'should not add running footer if height is nil' do
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: { footer_height: nil }, analyze: true
      = Document Title
      :doctype: book

      body
      EOS

      (expect pdf.find_text %r/^\d+$/).to be_empty
    end

	  it 'should add footer if theme extends base and footer height is set' do
			pdf_theme = {
				extends: 'base',
				footer_height: 36,
			}
			pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
			= Document Title
			:doctype: book

			== Beginning

			== End
			EOS

			pagenum_1_text = (pdf.find_text '1')[0]
			pagenum_2_text = (pdf.find_text '2')[0]
			(expect pagenum_1_text).not_to be_nil
			(expect pagenum_1_text[:page_number]).to eql 2
			(expect pagenum_2_text).not_to be_nil
			(expect pagenum_2_text[:page_number]).to eql 3
			(expect pagenum_1_text[:x]).to be > pagenum_2_text[:x]
		end
  end

  context 'Header' do
    it 'should add running header starting at body if header key is set in theme' do
      theme_overrides = {
        header_font_size: 9,
        header_height: 30,
        header_line_height: 1,
        header_padding: [6, 1, 0, 1],
        header_recto_right_content: '({document-title})',
        header_verso_right_content: '({document-title})'
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book

      first page

      <<<

      second page
      EOS

      expected_page_numbers = %w(1 2)

      page_height = pdf.pages[0][:size][1]
      header_texts = pdf.find_text '(Document Title)'
      (expect header_texts).to have_size expected_page_numbers.size
      expected_page_numbers.each_with_index do |page_number, idx|
        (expect header_texts[idx][:string]).to eql '(Document Title)'
        (expect header_texts[idx][:page_number]).to eql page_number.to_i + 1
        (expect header_texts[idx][:font_size]).to eql 9
        (expect header_texts[idx][:y]).to be < page_height
      end
    end

    it 'should not add running header if noheader attribute is set' do
      theme_overrides = {
        header_font_size: 9,
        header_height: 30,
        header_line_height: 1,
        header_padding: [6, 1, 0, 1],
        header_recto_right_content: '({document-title})',
        header_verso_right_content: '({document-title})'
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, attribute_overrides: { 'noheader' => '' }, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book

      body
      EOS

      (expect pdf.find_text '(Document Title)').to be_empty
    end
  end

  context 'Start at' do
    it 'should start running content at title page if running_content_start_at key is title' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(i ii 1 2 3)
    end

    it 'should start running content at title page if running_content_start_at key is title and document has front cover' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:
      :front-cover-image: image:cover.jpg[]

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      (expect pdf.find_text page_number: 1).to be_empty
      pgnum_labels = (2.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(ii iii 1 2 3)
    end

    it 'should start running content at toc page if running_content_start_at key is title and title page is disabled' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(i 1 2 3)
    end

    it 'should start running content at body if running_content_start_at key is title and title page and toc are disabled' do
      theme_overrides = { running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(1 2 3)
    end

    it 'should start running content at toc page if running_content_start_at key is toc' do
      theme_overrides = { running_content_start_at: 'toc' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
        accum
      end
      (expect pgnum_labels).to eq [nil, 'ii', '1', '2', '3']
    end

    it 'should start running content at toc page if running_content_start_at key is toc and title page is disabled' do
      theme_overrides = { running_content_start_at: 'toc' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
        accum
      end
      (expect pgnum_labels).to eq %w(i 1 2 3)
    end

    it 'should start running content at body if running_content_start_at key is toc and toc is disabled' do
      theme_overrides = { running_content_start_at: 'toc' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << ((pdf.find_text page_number: page_number, y: 14.263)[-1] || {})[:string]
        accum
      end
      (expect pgnum_labels).to eq [nil, '1', '2', '3']
    end
  end

  context 'Page numbering' do
    it 'should start page numbering at body if title page and toc are disabled' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title
      :doctype: book
      :notitle:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(1 2 3)
    end

    it 'should start page numbering at body if title page is disabled and toc is enabled' do
      pdf_theme = { running_content_start_at: 'toc' }
      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(i 1 2 3)
    end

    it 'should start page numbering at title page if page_numbering_start_at is title' do
      theme_overrides = { page_numbering_start_at: 'title', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(1 2 3 4 5)
    end

    it 'should start page numbering at toc page if page_numbering_start_at is title and title page is disabled' do
      theme_overrides = { page_numbering_start_at: 'title', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(1 2 3 4)
    end

    it 'should start page numbering at body if page_numbering_start_at is title and title page and toc are disabled' do
      theme_overrides = { page_numbering_start_at: 'title', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(1 2 3)
    end

    it 'should start page numbering at toc page if page_numbering_start_at is toc' do
      theme_overrides = { page_numbering_start_at: 'toc', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(i 1 2 3 4)
    end

    it 'should start page numbering at toc page if page_numbering_start_at is toc and title page is disabled' do
      theme_overrides = { page_numbering_start_at: 'toc', running_content_start_at: 'title' }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :notitle:
      :toc:

      == First Chapter

      == Second Chapter

      == Third Chapter
      EOS

      pgnum_labels = (1.upto pdf.pages.size).reduce([]) do |accum, page_number|
        accum << (pdf.find_text page_number: page_number, y: 14.263)[-1][:string]
        accum
      end
      (expect pgnum_labels).to eq %w(1 2 3 4)
    end
  end

  context 'Theming' do
    it 'should be able to set font styles per periphery and side in theme' do
      pdf_theme = build_pdf_theme \
        footer_font_size: 7.5,
        footer_recto_left_content: '{section-title}',
        footer_recto_left_font_style: 'bold',
        footer_recto_left_text_transform: 'lowercase',
        footer_recto_right_content: '{page-number}',
        footer_recto_right_font_color: '00ff00',
        footer_verso_left_content: '{page-number}',
        footer_verso_left_font_color: 'ff0000',
        footer_verso_right_content: '{section-title}',
        footer_verso_right_text_transform: 'uppercase'

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title

      Preamble text.

      <<<

      == Beginning

      <<<

      == Middle

      <<<

      == End
      EOS

      (expect pdf.find_text font_size: 7.5, page_number: 1, string: '1', font_color: '00FF00').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 2, string: 'BEGINNING').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 2, string: '2', font_color: 'FF0000').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 3, string: 'middle', font_name: 'NotoSerif-Bold').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 3, string: '3', font_color: '00FF00').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 4, string: 'END').to have_size 1
      (expect pdf.find_text font_size: 7.5, page_number: 4, string: '4', font_color: 'FF0000').to have_size 1
    end

    it 'should expand footer padding from single value' do
      pdf = to_pdf <<~'EOS', enable_footer: true, analyze: true
      = Document Title

      first page

      <<<

      second page
      EOS

      p2_text = pdf.find_text page_number: 2
      (expect p2_text[1][:x]).to be > p2_text[0][:x]
      (expect p2_text[1][:string]).to eql '2'
    end

    it 'should expand header padding from single value' do
      theme_overrides = {
        header_font_size: 9,
        header_height: 30,
        header_line_height: 1,
        header_padding: 5,
        header_recto_right_content: '{page-number}',
        header_verso_left_content: '{page-number}'
      }

      pdf = to_pdf <<~'EOS', pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title

      first page

      <<<

      second page
      EOS

      p2_text = pdf.find_text page_number: 2
      (expect p2_text[1][:x]).to be > p2_text[0][:x]
      (expect p2_text[1][:string]).to eql '2'
    end

    it 'should allow horizontal padding to be negative', visual: true do
      pdf_theme = {
        footer_font_color: '000000',
        footer_padding: [0, -48.24, 0, -48.24],
        footer_recto_left_content: 'text left',
        footer_recto_right_content: 'text right',
        footer_vertical_align: 'middle',
      }

      to_file = to_pdf_file <<~'EOS', 'running-content-negative-padding.pdf', pdf_theme: pdf_theme, enable_footer: true
      text left

      [.text-right]
      text right
      EOS

      (expect to_file).to visually_match 'running-content-negative-padding.pdf'
    end

    it 'should coerce content value to string' do
      pdf = to_pdf 'body', enable_footer: true, attribute_overrides: { 'pdf-theme' => (fixture_file 'running-footer-coerce-content-theme.yml') }, analyze: true

      (expect pdf.find_text '1000').to have_size 1
      (expect pdf.find_text 'true').to have_size 1
    end

    it 'should not substitute escaped attribute reference in content' do
      pdf_theme = {
        footer_recto_right_content: '\{keepme}',
        footer_verso_left_content: '\{keepme}',
      }

      pdf = to_pdf 'body', enable_footer: true, pdf_theme: pdf_theme, analyze: true

      running_text = pdf.find_text '{keepme}'
      (expect running_text).to have_size 1
    end

    it 'should drop line in content with unresolved attribute reference' do
      pdf_theme = {
        footer_recto_right_content: %(keep\ndrop{bogus}\nme),
        footer_verso_left_content: %(keep\ndrop{bogus}\nme),
      }

      pdf = to_pdf 'body', enable_footer: true, pdf_theme: pdf_theme, analyze: true

      running_text = pdf.find_text %(keep me)
      (expect running_text).to have_size 1
    end

    it 'should parse running content as AsciiDoc' do
      pdf_theme = {
        footer_recto_right_content: 'footer: *bold* _italic_ `mono`',
        footer_verso_left_content: 'https://asciidoctor.org[Asciidoctor] AsciiDoc -> PDF',
      }
      input = <<~'EOS'
      page 1

      <<<

      page 2
      EOS

      pdf = to_pdf input, enable_footer: true, pdf_theme: pdf_theme, analyze: true

      footer_y = (pdf.find_text 'footer: ')[0][:y]
      bold_text = (pdf.find_text string: 'bold', page_number: 1, y: footer_y)[0]
      (expect bold_text).not_to be_nil
      italic_text = (pdf.find_text string: 'italic', page_number: 1, y: footer_y)[0]
      (expect italic_text).not_to be_nil
      mono_text = (pdf.find_text string: 'mono', page_number: 1, y: footer_y)[0]
      (expect mono_text).not_to be_nil
      link_text = (pdf.find_text string: 'Asciidoctor', page_number: 2, y: footer_y)[0]
      (expect link_text).not_to be_nil
      convert_text = (pdf.find_text string: %( AsciiDoc \u2192 PDF), page_number: 2, y: footer_y)[0]
      (expect convert_text).not_to be_nil

      pdf = to_pdf input, enable_footer: true, pdf_theme: pdf_theme
      annotations_p2 = get_annotations pdf, 2
      (expect annotations_p2).to have_size 1
      link_annotation = annotations_p2[0]
      (expect link_annotation[:Subtype]).to eql :Link
      (expect link_annotation[:A][:URI]).to eql 'https://asciidoctor.org'
    end

    it 'should draw background color across whole periphery region', visual: true do
      pdf_theme = build_pdf_theme \
        header_background_color: '009246',
        header_border_width: 0,
        footer_background_color: 'CE2B37',
        footer_border_width: 0,
        header_height: 160,
        footer_height: 160,
        page_margin: [160, 48, 160, 48]

      to_file = to_pdf_file 'Hello world', 'running-content-background-colors.pdf', enable_footer: true, pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-background-colors.pdf'
    end

    it 'should draw column rule between columns using specified width and spacing', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_padding: [8, 0],
        header_columns: '>40% =10% <40%',
        header_column_rule_width: 0.5,
        header_column_rule_color: '333333',
        header_column_rule_spacing: 8,
        header_recto_left_content: 'left',
        header_recto_center_content: 'center',
        header_recto_right_content: 'right',
        footer_border_width: 0,
        footer_padding: [8, 0],
        footer_columns: '>40% =10% <40%',
        footer_column_rule_width: 0.5,
        footer_column_rule_color: '333333',
        footer_column_rule_spacing: 8,
        footer_recto_left_content: 'left',
        footer_recto_center_content: 'center',
        footer_recto_right_content: 'right'

      to_file = to_pdf_file <<~'EOS', 'running-content-column-rule.pdf', enable_footer: true, pdf_theme: pdf_theme
      = Document Title

      content
      EOS

      (expect to_file).to visually_match 'running-content-column-rule.pdf'
    end

    it 'should not draw column rule if there is only one column', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_padding: [8, 0],
        header_columns: '<25% =50% >25%',
        header_column_rule_width: 0.5,
        header_column_rule_color: '333333',
        header_column_rule_spacing: 8,
        header_recto_left_content: 'left',
        footer_border_width: 0,
        footer_padding: [8, 0],
        footer_columns: '<25% =50% >25%',
        footer_column_rule_width: 0.5,
        footer_column_rule_color: '333333',
        footer_column_rule_spacing: 8,
        footer_recto_right_content: 'right'

      to_file = to_pdf_file <<~'EOS', 'running-content-no-column-rule.pdf', enable_footer: true, pdf_theme: pdf_theme
      = Document Title

      content
      EOS

      (expect to_file).to visually_match 'running-content-no-column-rule.pdf'
    end
  end

  context 'Folio placement' do
    it 'should invert recto and verso if pdf-folio-placement is virtual-inverted' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      :pdf-folio-placement: virtual-inverted

      content
      EOS

      footer_text = pdf.find_text font_size: 9
      (expect footer_text).to have_size 2
      (expect footer_text[0][:string]).to eql 'verso'
      (expect footer_text[1][:string]).to eql 'verso'
    end

    it 'should invert recto and verso if pdf-folio-placement is physical-inverted' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :pdf-folio-placement: physical-inverted
      :media: print
      :doctype: book

      content
      EOS

      footer_text = pdf.find_text font_size: 9
      (expect footer_text).to have_size 2
      (expect footer_text[0][:string]).to eql 'recto'
      (expect footer_text[1][:string]).to eql 'recto'
    end

    it 'should base recto and verso on physical page number if pdf-folio-placement is physical or physical-inverted' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      { 'physical' => 'verso', 'physical-inverted' => 'recto' }.each do |placement, side|
        pdf = to_pdf <<~EOS, pdf_theme: pdf_theme, enable_footer: true, analyze: true
        = Document Title
        :pdf-folio-placement: #{placement}
        :doctype: book
        :toc:

        == Chapter

        #{40.times.map {|it| %(=== Section #{it + 1})}.join %(\n\n)}
        EOS

        (expect pdf.find_text page_number: 4, string: 'Chapter').to have_size 1
        body_start_footer_text = pdf.find_text font_size: 9, page_number: 4
        (expect body_start_footer_text).to have_size 2
        (expect body_start_footer_text[0][:string]).to eql side
      end
    end

    it 'should base recto and verso on physical page if media=prepress even if pdf-folio-placement is set' do
      pdf_theme = {
        footer_verso_left_content: 'verso',
        footer_verso_right_content: 'verso',
        footer_recto_left_content: 'recto',
        footer_recto_right_content: 'recto',
      }

      pdf = to_pdf <<~'EOS', pdf_theme: pdf_theme, enable_footer: true, analyze: true
      = Document Title
      :pdf-folio-placement: virtual-inverted
      :media: prepress
      :doctype: book

      content
      EOS

      footer_text = pdf.find_text font_size: 9
      (expect footer_text).to have_size 2
      (expect footer_text[0][:string]).to eql 'recto'
      (expect footer_text[1][:string]).to eql 'recto'
    end
  end

  context 'Page layout' do
    it 'should place footer text correctly if page layout changes' do
      theme_overrides = {
        footer_padding: 0,
        footer_verso_left_content: 'verso',
        footer_verso_right_content: nil,
        footer_recto_left_content: 'recto',
        footer_recto_right_content: nil,
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      portrait

      [.landscape]
      <<<

      landscape

      [.portrait]

      portrait
      EOS

      (expect pdf.text.size).to eql 5
      pdf.text.each do |text|
        (expect text[:x]).to eql 48.24
      end
    end

    it 'should adjust dimensions of running content to fit page layout', visual: true do
      filler = lorem_ipsum '2-sentences-2-paragraphs'
      theme_overrides = {
        footer_recto_left_content: '{section-title}',
        footer_recto_right_content: '{page-number}',
        footer_verso_left_content: '{page-number}',
        footer_verso_right_content: '{section-title}',
      }

      to_file = to_pdf_file <<~EOS, 'running-content-alt-layouts.pdf', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides)
      = Alternating Page Layouts

      This document demonstrates that the running content is adjusted to fit the page layout as the page layout alternates.

      #{filler}

      [.landscape]
      <<<

      == Landscape Page

      #{filler}

      [.portrait]
      <<<

      == Portrait Page

      #{filler}
      EOS

      (expect to_file).to visually_match 'running-content-alt-layouts.pdf'
    end
  end

  context 'Implicit attributes' do
    it 'should escape text of doctitle attribute' do
      theme_overrides = {
        footer_recto_right_content: '({doctitle})',
        footer_verso_left_content: '({doctitle})',
      }

      (expect {
        pdf = to_pdf <<~'EOS', enable_footer: true, attribute_overrides: { 'doctitle' => 'The Chronicles of <Foo> & &#166;' }, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
        :doctype: book

        == Chapter 1

        content
        EOS

        running_text = pdf.find_text %(The Chronicles of <Foo> & \u00a6)
        (expect running_text).to have_size 1
      }).to not_log_message
    end

    it 'should set document-title and document-subtitle based on doctitle' do
      pdf_theme = {
        footer_recto_left_content: '({document-title})',
        footer_recto_right_content: '[{document-subtitle}]',
        footer_verso_left_content: '({document-title})',
        footer_verso_right_content: '[{document-subtitle}]',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title: Subtitle
      :doctype: book

      == Beginning

      == End
      EOS

      [2, 3].each do |pgnum|
        main_title_text = (pdf.find_text page_number: pgnum, string: '(Document Title)')[0]
        subtitle_text = (pdf.find_text page_number: pgnum, string: '[Subtitle]')[0]
        (expect main_title_text).not_to be_nil
        (expect subtitle_text).not_to be_nil
      end
    end

    it 'should set part-title, chapter-title, and section-title based on context of current page' do
      pdf_theme = {
        footer_columns: '<25% >70%',
        footer_recto_left_content: 'FOOTER',
        footer_recto_right_content: '[{part-title}|{chapter-title}|{section-title}]',
        footer_verso_left_content: 'FOOTER',
        footer_verso_right_content: '[{part-title}|{chapter-title}|{section-title}]',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: pdf_theme, analyze: true
      = Document Title
      :doctype: book

      = Part I

      == Chapter A

      === Detail

      <<<

      === More Detail

      == Chapter B

      = Part II

      == Chapter C
      EOS

      footer_y = (pdf.find_text 'FOOTER')[0][:y]
      titles_by_page = (pdf.find_text y: footer_y).reduce({}) do |accum, it|
        accum[it[:page_number]] = it[:string] unless it[:string] == 'FOOTER'
        accum
      end
      (expect titles_by_page[2]).to eql '[Part I||]'
      (expect titles_by_page[3]).to eql '[Part I|Chapter A|Detail]'
      (expect titles_by_page[4]).to eql '[Part I|Chapter A|More Detail]'
      (expect titles_by_page[5]).to eql '[Part I|Chapter B|]'
      (expect titles_by_page[6]).to eql '[Part II||]'
      (expect titles_by_page[7]).to eql '[Part II|Chapter C|]'
    end

    it 'should assign section titles down to sectlevels defined in theme' do
      input = <<~'EOS'
      = Document Title
      :doctype: book

      == A

      <<<

      === Level 2

      <<<

      ==== Level 3

      <<<

      ===== Level 4

      == B
      EOS

      {
        nil => ['A', 'Level 2', 'Level 2', 'Level 2', 'B'],
        2 => ['A', 'Level 2', 'Level 2', 'Level 2', 'B'],
        3 => ['A', 'Level 2', 'Level 3', 'Level 3', 'B'],
        4 => ['A', 'Level 2', 'Level 3', 'Level 4', 'B'],
      }.each do |sectlevels, expected|
        theme_overrides = {
          footer_sectlevels: sectlevels,
          footer_font_family: 'Helvetica',
          footer_recto_right_content: '{section-or-chapter-title}',
          footer_verso_left_content: '{section-or-chapter-title}',
        }
        pdf = to_pdf input, enable_footer: true, pdf_theme: theme_overrides, analyze: true
        titles = (pdf.find_text font_name: 'Helvetica').map {|it| it[:string] }
        (expect titles).to eql expected
      end
    end

    it 'should use doctitle, toc-title, and preface-title as chapter-title before first chapter' do
      theme_overrides = {
        running_content_start_at: 'title',
        page_numbering_start_at: 'title',
        footer_recto_right_content: '{chapter-title}',
        footer_verso_left_content: '{chapter-title}',
      }

      pdf = to_pdf <<~'EOS', enable_footer: true, pdf_theme: (build_pdf_theme theme_overrides), analyze: true
      = Document Title
      :doctype: book
      :toc:

      content

      == Chapter 1

      content
      EOS

      expected_running_content_by_page = { 1 => 'Document Title', 2 => 'Table of Contents', 3 => 'Preface', 4 => 'Chapter 1' }
      running_content_by_page = (pdf.find_text y: 14.263).reduce({}) {|accum, text| accum[text[:page_number]] = text[:string]; accum }
      (expect running_content_by_page).to eql expected_running_content_by_page
    end

    it 'should allow style of title-related attributes to be customized using the title-style key' do
      input = <<~'EOS'
      = Document Title
      :doctype: book
      :sectnums:
      :notitle:

      == Beginning
      EOS

      pdf_theme = {
        footer_recto_left_content: '[{chapter-title}]',
        footer_recto_right_content: '',
        footer_verso_left_content: '[{chapter-title}]',
        footer_verso_right_content: '',
        footer_font_color: 'AA0000',
      }

      [
        [nil, 'Chapter 1. Beginning'],
        ['document', 'Chapter 1. Beginning'],
        ['toc', '1. Beginning'],
        ['basic', 'Beginning'],
      ].each do |(title_style, expected_title)|
        pdf_theme = pdf_theme.merge footer_title_style: title_style if title_style
        pdf = to_pdf input, pdf_theme: pdf_theme, enable_footer: true, analyze: true
        footer_text = (pdf.find_text font_color: 'AA0000')[0]
        (expect footer_text[:string]).to eql %([#{expected_title}])
      end
    end
  end

  context 'Images' do
    it 'should scale image up to width when fit=contain', visual: true do
      %w(pdfwidth=99.76 fit=contain pdfwidth=0.5in,fit=contain pdfwidth=15in,fit=contain).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_recto_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-contain-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image-fit.pdf'
      end
    end

    it 'should not overlap border when scaling image to fit content area', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_border_width: 5,
        header_border_color: 'dddddd',
        header_recto_columns: '>40% =20% <40%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'square.png'}[fit=contain]),
        header_recto_right_content: 'text',
        footer_height: 36,
        footer_padding: 0,
        footer_vertical_align: 'middle',
        footer_border_width: 5,
        footer_border_color: 'dddddd',
        footer_recto_columns: '>40% =20% <40%',
        footer_recto_left_content: 'text',
        footer_recto_center_content: %(image:#{fixture_file 'square.png'}[fit=contain]),
        footer_recto_right_content: 'text'

      to_file = to_pdf_file %([.text-center]\ncontent), 'running-content-image-contain-border.pdf', enable_footer: true, pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image-contain-border.pdf'
    end

    it 'should scale image down to width when fit=scale-down', visual: true do
      %w(pdfwidth=99.76 pdfwidth=15in,fit=scale-down).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_recto_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-scale-down-width-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image-fit.pdf'
      end
    end

    it 'should scale image down to height when fit=scale-down', visual: true do
      %w(pdfwidth=30.60 fit=scale-down).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_recto_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'tux.png'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-scale-down-height-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image-scale-down.pdf'
      end
    end

    it 'should scale image down to minimum dimension when fit=scale-down', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 24,
        header_recto_columns: '>25% =50% <25%',
        header_recto_left_content: 'text',
        header_recto_center_content: %(image:#{fixture_file 'square-viewbox-only.svg'}[fit=scale-down]),
        header_recto_right_content: 'text'
      to_file = to_pdf_file %([.text-center]\ncontent), 'running-content-image-scale-down-min.pdf', pdf_theme: pdf_theme
      (expect to_file).to visually_match 'running-content-image-scale-down-min.pdf'
    end

    it 'should not modify image dimensions when fit=scale-down if image already fits', visual: true do
      %w(pdfwidth=0.5in pdfwidth=0.5in,fit=scale-down).each_with_index do |image_attrlist, idx|
        pdf_theme = build_pdf_theme \
          header_height: 36,
          header_recto_columns: '>40% =20% <40%',
          header_recto_left_content: 'text',
          header_recto_center_content: %(image:#{fixture_file 'green-bar.svg'}[#{image_attrlist}]),
          header_recto_right_content: 'text'

        to_file = to_pdf_file %([.text-center]\ncontent), %(running-content-image-#{idx}.pdf), pdf_theme: pdf_theme

        (expect to_file).to visually_match 'running-content-image.pdf'
      end
    end

    it 'should size image based on width attribute value if no other dimension attribute is specified', visual: true do
      pdf_theme = build_pdf_theme \
        header_height: 36,
        header_recto_columns: '<25% =50% >25%',
        header_recto_center_content: %(image:#{fixture_file 'square-viewbox-only.svg'}[square,24])

      to_file = to_pdf_file %([.text-center]\ncontent), 'running-content-image-width.pdf', pdf_theme: pdf_theme

      (expect to_file).to visually_match 'running-content-image-width.pdf'
    end

    it 'should print running content on consecutive pages even when image in running content overruns bounds', visual: true do
      pdf_theme = {
        footer_recto_left_content: '{page-number}',
        footer_recto_right_content: %(image:#{fixture_file 'tux.png'}[pdfwidth=100px]),
        footer_verso_left_content: '{page-number}',
        footer_verso_right_content: %(image:#{fixture_file 'tux.png'}[pdfwidth=100px]),
      }

      to_file = to_pdf_file <<~'EOS', 'running-content-image-overrun.pdf', enable_footer: true, pdf_theme: pdf_theme
      = Article Title

      content

      <<<

      content
      EOS

      (expect to_file).to visually_match 'running-content-image-overrun.pdf'
    end

    it 'should resolve image target relative to themesdir', visual: true do
      [
        {
          'pdf-theme' => 'running-header',
          'pdf-themesdir' => fixtures_dir,
        },
        {
          'pdf-theme' => 'fixtures/running-header-outside-fixtures-theme.yml',
          'pdf-themesdir' => (File.dirname fixtures_dir),
        },
      ].each_with_index do |attribute_overrides, idx|
        to_file = to_pdf_file <<~'EOS', %(running-content-image-from-themesdir-#{idx}.pdf), attribute_overrides: attribute_overrides
        [.text-center]
        content
        EOS
        (expect to_file).to visually_match 'running-content-image.pdf'
      end
    end

    it 'should resolve image target relative to theme file when themesdir is not set', visual: true do
      attribute_overrides = { 'pdf-theme' => (fixture_file 'running-header-theme.yml', relative: true) }
      to_file = to_pdf_file <<~'EOS', 'running-content-image-from-theme.pdf', attribute_overrides: attribute_overrides
      [.text-center]
      content
      EOS

      (expect to_file).to visually_match 'running-content-image.pdf'
    end

    it 'should resolve run-in image relative to themesdir', visual: true do
      to_file = to_pdf_file 'content', 'running-content-run-in-image.pdf', attribute_overrides: { 'pdf-theme' => (fixture_file 'running-header-run-in-image-theme.yml') }
      (expect to_file).to visually_match 'running-content-run-in-image.pdf'
    end

    it 'should warn and replace image with alt text if image is not found' do
      [true, false].each do |block|
        (expect {
          pdf_theme = build_pdf_theme \
            header_height: 36,
            header_recto_columns: '=100%',
            header_recto_center_content: %(image:#{block ? ':' : ''}no-such-image.png[alt text])

          pdf = to_pdf 'content', pdf_theme: pdf_theme, analyze: true

          alt_text = pdf.find_text '[alt text]'
          (expect alt_text).to have_size 1
        }).to log_message severity: :WARN, message: %r(image to embed not found or not readable.*data/themes/no-such-image\.png$)
      end
    end

    it 'should add link to raster image if link attribute is set' do
      theme_overrides = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_recto_center_content: 'image:tux.png[link=https://www.linuxfoundation.org/projects/linux/]',
        header_verso_center_content: 'image:tux.png[link=https://www.linuxfoundation.org/projects/linux/]',
      }
      pdf = to_pdf 'body', pdf_theme: theme_overrides

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to eql :Link
      (expect link_annotation[:A][:URI]).to eql 'https://www.linuxfoundation.org/projects/linux/'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 36.0
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 30.6
    end

    it 'should add link to SVG image if link attribute is set' do
      theme_overrides = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_recto_center_content: 'image:square.svg[link=https://example.org]',
        header_verso_center_content: 'image:square.svg[link=https://example.org]',
      }
      pdf = to_pdf 'body', pdf_theme: theme_overrides

      annotations = get_annotations pdf, 1
      (expect annotations).to have_size 1
      link_annotation = annotations[0]
      (expect link_annotation[:Subtype]).to eql :Link
      (expect link_annotation[:A][:URI]).to eql 'https://example.org'
      link_rect = link_annotation[:Rect]
      (expect (link_rect[3] - link_rect[1]).round 1).to eql 36.0
      (expect (link_rect[2] - link_rect[0]).round 1).to eql 36.0
    end

    it 'should replace unrecognized font family in SVG with SVG fallback font family specified in theme' do
      theme_overrides = {
        __dir__: fixtures_dir,
        header_height: 36,
        header_columns: '0% =100% 0%',
        header_recto_center_content: 'image:svg-with-text.svg[]',
        header_verso_center_content: 'image:svg-with-text.svg[]',
        svg_fallback_font_family: 'Times-Roman',
      }
      pdf = to_pdf 'body', pdf_theme: theme_overrides, analyze: true

      text = pdf.find_text 'This text uses the default SVG font.'
      (expect text).to have_size 1
      (expect text[0][:font_name]).to eql 'Times-Roman'
    end
  end
end
