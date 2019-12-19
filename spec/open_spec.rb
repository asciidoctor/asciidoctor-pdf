# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Asciidoctor::PDF::Converter - Open' do
  it 'should keep block together when it has the unbreakable option', visual: true do
    to_file = to_pdf_file <<~EOS, 'open-unbreakable-option-fit.pdf'
    Make it rain.footnote:[money]

    #{(['filler'] * 21).join %(\n\n)}

    [%unbreakable]
    --
    To install Antora, open a terminal and type:

     $ npm i -g @antora/cli@2.2 @antora/site-generator-default@2.2

    The `@` at the beginning of the package name is important.
    It tells `npm` that the `cli` package is located in the `antora` group.
    If you omit this character, `npm` will assume the package name is the name of a git repository on GitHub.
    The second `@` offsets the requested version number.footnote:[Clarification about this statement.]
    Only the major and minor segments are specified to ensure you receive the latest patch update.
    --

    Make it snow.footnote:[dollar bills]
    EOS

    (expect to_file).to visually_match 'open-unbreakable-option-fit.pdf'
  end

  it 'should break an unbreakable block if it does not fit on one page', visual: true do
    to_file = to_pdf_file <<~EOS, 'open-unbreakable-option-break.pdf'
    Make it rain.footnote:[money]

    #{(['filler'] * 21).join %(\n\n)}

    [%unbreakable]
    --
    To install Antora, open a terminal and type:

     $ npm i -g @antora/cli@2.2 @antora/site-generator-default@2.2

    The `@` at the beginning of the package name is important.
    It tells `npm` that the `cli` package is located in the `antora` group.
    If you omit this character, `npm` will assume the package name is the name of a git repository on GitHub.
    The second `@` offsets the requested version number.footnote:[Clarification about this statement.]
    Only the major and minor segments are specified to ensure you receive the latest patch update.

    #{(['filler inside open block'] * 25).join %(\n\n)}
    --

    Make it snow.footnote:[dollar bills]
    EOS

    (expect to_file).to visually_match 'open-unbreakable-option-break.pdf'
  end
end
