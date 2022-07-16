# frozen_string_literal: true

RSpec::Matchers.define :log_message do |expected|
  match notify_expectation_failures: true do |actual|
    if expected
      log_level_override = expected.delete :using_log_level
      expected = nil if expected.empty?
    end
    with_memory_logger log_level_override do |logger|
      actual.call
      if expected
        (expect logger).to have_message expected
      else
        (expect logger).not_to be_empty
      end
      true
    end
  end

  #match_when_negated notify_expectation_failures: true do |actual|
  #  with_memory_logger expected.to_h[:using_log_level] do |logger|
  #    actual.call
  #    logger ? logger.empty? : true
  #  end
  #end

  supports_block_expectations
end
