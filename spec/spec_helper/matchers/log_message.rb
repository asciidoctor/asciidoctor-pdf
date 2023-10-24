# frozen_string_literal: true

RSpec::Matchers.define :log_message do |expected|
  handler = proc do |negated|
    if expected
      log_level_override = expected.delete :using_log_level
      expected = nil if expected.empty?
    end
    with_memory_logger log_level_override do |logger|
      actual.call
      if expected
        (expect logger).send (negated ? :not_to : :to), (have_message expected)
      else
        (expect logger).send (negated ? :to : :not_to), be_empty
      end
      true
    end
  end

  match notify_expectation_failures: true do |actual|
    instance_exec &handler
  end

  match_when_negated notify_expectation_failures: true do |actual|
    instance_exec true, &handler
  end

  supports_block_expectations
end
