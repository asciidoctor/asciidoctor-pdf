# frozen_string_literal: true

module Warning
  module Processor
    def warn str
      super unless str.start_with?(*Gem.path) || (str.include? 'Pattern matching is experimental')
    end
  end

  extend Processor
end
