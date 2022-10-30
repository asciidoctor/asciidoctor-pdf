# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Manpage' do
  it 'should generate name section automatically' do
    pdf = to_pdf <<~'END', doctype: :manpage, analyze: true
    = cmd(1)
    Author Name
    v1.0.0
    :manmanual: CMD
    :mansource: CMD

    == Name

    cmd - does stuff

    == Synopsis

    *cmd* [_OPTION_]... _FILE_...

    == Options

    *-v*:: Prints the version.
    END

    expected_name_title = 'Name'
    name_title_text = (pdf.find_text expected_name_title)[0]
    (expect name_title_text).not_to be_nil
    (expect name_title_text[:font_size]).to be 22
    name_body_text = (pdf.find_text 'cmd - does stuff')[0]
    (expect name_body_text).not_to be_nil
    (expect name_body_text[:font_size]).to eql 10.5
    (expect (pdf.find_text font_size: 22).map {|it| it[:string] }).to eql [expected_name_title, 'Synopsis', 'Options']
  end

  it 'should apply normal substitutions to manname section' do
    pdf = to_pdf <<~'END', doctype: :manpage, analyze: true
    = cmd(1)

    == Name

    cmd - does *lots* of stuff

    == Synopsis

    *cmd* [_OPTION_]... _FILE_...
    END

    lots_text = (pdf.find_text 'lots')[0]
    (expect lots_text).not_to be_nil
    (expect lots_text[:font_name]).to eql 'NotoSerif-Bold'
  end

  it 'should uppercase title of auto-generated name section if other sections are uppercase' do
    pdf = to_pdf <<~'END', doctype: :manpage, analyze: true
    = cmd(1)
    Author Name
    v1.0.0
    :manmanual: CMD
    :mansource: CMD
    :manname: cmd
    :manpurpose: does stuff

    == SYNOPSIS

    *cmd* [_OPTION_]... _FILE_...

    == OPTIONS

    *-v*:: Prints the version.
    END

    name_title_text = pdf.find_unique_text 'NAME'
    (expect name_title_text).not_to be_nil
    (expect name_title_text[:font_size]).to be 22
    (expect pdf.lines).to include 'cmd - does stuff'
  end

  it 'should not uppercase title of auto-generated name section if no other sections are found' do
    pdf = to_pdf <<~'END', doctype: :manpage, analyze: true
    = cmd(1)
    Author Name
    v1.0.0
    :manmanual: CMD
    :mansource: CMD
    :manname: cmd
    :manpurpose: does stuff
    END

    name_title_text = pdf.find_unique_text 'Name'
    (expect name_title_text).not_to be_nil
    (expect name_title_text[:font_size]).to be 22
    (expect pdf.lines).to include 'cmd - does stuff'
  end

  it 'should arrange body of manpage into columns if specified in theme' do
    pdf = to_pdf <<~'END', doctype: :manpage, pdf_theme: { page_columns: 2 }, analyze: true
    = cmd(1)

    == Name

    cmd - does stuff

    == Synopsis

    *cmd* [_OPTION_]... _FILE_...

    [.column]
    <<<

    == Options

    *-v*:: Prints the version.
    END

    midpoint = (get_page_size pdf)[0] * 0.5
    name_text = pdf.find_unique_text 'Name'
    options_text = pdf.find_unique_text 'Options'
    (expect name_text[:x]).to eql 48.24
    (expect options_text[:x]).to be > midpoint
    (expect name_text[:y]).to eql options_text[:y]
  end
end
