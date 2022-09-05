# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::PDF::FormattedText do
  it 'should not wrap LoadError if require fails' do
    (expect do
      require 'no-such-gem'
    end).to raise_exception LoadError, %r/no-such-gem/
  end
end
