require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Listing' do
  it 'should move listing block to next page if possible to avoid split' do
    pdf = to_pdf <<~EOS, analyze: true
    #{(['paragraph'] * 20).join (?\n * 2)}

    ----
    #{(['listing'] * 20).join ?\n}
    ----
    EOS

    listing_page_numbers = (pdf.find_text 'listing').map {|it| it[:page_number] }.uniq
    (expect listing_page_numbers).to eql [2]
  end

  it 'should resize font size to prevent wrapping if autofit option is set' do
    pdf = to_pdf <<~'EOS', analyze: true
    [%autofit]
    ----
    theme = ThemeLoader.load_theme theme_name, (theme_dir = (doc.attr 'pdf-themesdir') || (doc.attr 'pdf-stylesdir'))
    ----
    EOS

    (expect pdf.text).to have_size 1
    (expect pdf.text[0][:font_size]).to be < build_pdf_theme.code_font_size
  end

  it 'should not resize font size more than minimum font size' do
    pdf = to_pdf <<~'EOS', pdf_theme: { base_font_size_min: 8 }, analyze: true
    [%autofit]
    ----
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ----
    EOS

    (expect pdf.text).to have_size 2
    (expect pdf.text[0][:font_size]).to eql 8
  end
end
