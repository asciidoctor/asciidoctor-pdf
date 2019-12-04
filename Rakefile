# frozen_string_literal: true

$default_tasks = [] # rubocop:disable Style/GlobalVars
Dir.glob('tasks/*.rake').each {|file| load file }
task default: $default_tasks unless $default_tasks.empty? # rubocop:disable Style/GlobalVars
