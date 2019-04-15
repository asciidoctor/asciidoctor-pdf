begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  warn $!.message
end
