require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Manpage' do
  it 'should generate name section automatically' do
    pdf = to_pdf <<~'EOS', doctype: 'manpage', analyze: true
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
    EOS

    expected_name_title = asciidoctor_1_5_7_or_better? ? 'Name' : '1. NAME'
    name_title_text = (pdf.find_text expected_name_title)[0]
    (expect name_title_text).not_to be_nil
    (expect name_title_text[:font_size]).to eql 22
    name_body_text = (pdf.find_text 'cmd - does stuff')[0]
    (expect name_body_text).not_to be_nil
    (expect name_body_text[:font_size]).to eql 10.5
    (expect (pdf.find_text font_size: 22).map {|it| it[:string] }).to eql [expected_name_title, 'Synopsis', 'Options']
  end

  it 'should uppercase title of name section if other sections are uppercase' do
    pdf = to_pdf <<~'EOS', doctype: 'manpage', analyze: true
    = cmd(1)
    Author Name
    v1.0.0
    :manmanual: CMD
    :mansource: CMD

    == NAME

    cmd - does stuff

    == SYNOPSIS

    *cmd* [_OPTION_]... _FILE_...

    == OPTIONS

    *-v*:: Prints the version.
    EOS

    name_title_text = (pdf.find_text 'NAME')[0]
    (expect name_title_text).not_to be_nil
    (expect name_title_text[:font_size]).to eql 22
  end if asciidoctor_1_5_7_or_better?
end
