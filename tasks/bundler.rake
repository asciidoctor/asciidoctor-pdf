# frozen_string_literal: true

begin
  require 'bundler/gem_tasks'
  $default_tasks << :build # rubocop:disable Style/GlobalVars
rescue LoadError
  warn $!.message
end
