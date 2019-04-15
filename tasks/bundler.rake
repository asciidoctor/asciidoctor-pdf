begin
  require 'bundler/gem_tasks'
  $default_tasks << :build
rescue LoadError
  warn $!.message
end
