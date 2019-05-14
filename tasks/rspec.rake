begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new :spec do |t|
    t.verbose = true
    opts = %w(-f progress)
    opts.unshift '-w' if !ENV['CI'] || ENV['COVERAGE']
    t.rspec_opts = opts
  end
rescue LoadError
  warn $!.message
end
