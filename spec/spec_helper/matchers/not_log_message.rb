# frozen_string_literal: true

# define matcher to replace `.not_to log_message` until notify_expectation_failures is supported for negated match
# see https://github.com/rspec/rspec-expectations/issues/1124
RSpec::Matchers.define :not_log_message do |expected|
  match notify_expectation_failures: true do |actual|
    with_memory_logger expected.to_h[:using_log_level] do |logger|
      actual.call
      (expect logger).to be_empty if logger
      true
    end
  end

  supports_block_expectations
end
