# frozen_string_literal: true

RSpec::Matchers.define :have_message do |expected|
  actual = nil
  match notify_expectation_failures: true do |logger|
    result = false
    messages = logger.messages
    expected_index = expected[:index] || 0
    if (message = messages[expected_index])
      if message[:severity] == expected[:severity]
        message_text = Hash === (message_data = message[:message]) ? message_data[:text] : message_data
        if Regexp === (expected_message = expected[:message])
          result = true if expected_message.match? message_text
        elsif expected_message.start_with? '~'
          result = true if message_text.include? expected_message[1..-1]
        elsif message_text === expected_message
          result = true
        end
        result = false if (file = expected[:file]) && !(Hash === message_data && file == message_data[:source_location].file)
        result = false if (lineno = expected[:lineno]) && !(Hash === message_data && lineno == message_data[:source_location].lineno)
      end
      actual = message
    end
    (expect messages).to have_size expected_index + 1 if result && expected[:last]
    result
  end

  failure_message do
    %(expected #{expected[:severity]} message#{expected[:message].to_s.chr == '~' ? ' containing ' : ' matching '}`#{expected[:message]}' to have been logged) + (actual ? %(, but got #{actual[:severity]}: #{actual[:message]}) : '')
  end
end
