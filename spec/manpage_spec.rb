require_relative 'spec_helper'

describe 'Asciidoctor::Pdf::Converter - Manpage' do
  it 'should generate name section automatically' do
    pdf = to_pdf <<~'EOS', doctype: 'manpage', analyze: :text
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

    text = pdf.text
    name_title_text = text.find {|candidate| candidate[:string] == 'Name' }
    (expect name_title_text).not_to be_nil
    (expect name_title_text[:font_size]).to eql 22
    name_body_text = text.find {|candidate| candidate[:string] == 'cmd - does stuff' }
    (expect name_body_text).not_to be_nil
    (expect name_body_text[:font_size]).to eql 10.5
    (expect text.index {|candidate| candidate[:string] == 'Synopsis' }).to be > (text.index {|candidate| candidate[:string] == 'Name' })
  end

  it 'should uppercase title of name section if other sections are uppercase' do
    pdf = to_pdf <<~'EOS', doctype: 'manpage', analyze: :text
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

    text = pdf.text
    name_title_text = text.find {|candidate| candidate[:string] == 'NAME' }
    (expect name_title_text).not_to be_nil
    (expect name_title_text[:font_size]).to eql 22
  end
end
