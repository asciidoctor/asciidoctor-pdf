# frozen_string_literal: true

RSpec::Matchers.define :log_messages do |expecteds|
  match notify_expectation_failures: true do |actual|
    with_memory_logger do |logger|
      actual.call
      expecteds.each_with_index do |it, idx|
        (expect logger).to have_message (it.merge index: idx)
      end if logger
      true
    end
  end

  supports_block_expectations
end
