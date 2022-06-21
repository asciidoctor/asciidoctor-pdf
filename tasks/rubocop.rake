# frozen_string_literal: true

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new :lint do |t|
    t.patterns = Dir['lib/**/*.rb'] - ['lib/asciidoctor/pdf/formatted_text/parser.rb'] + %w(Gemfile Rakefile bin/* spec/**/*.rb tasks/*.rake)
  end
rescue LoadError => e
  task :lint do
    raise <<~'EOS', cause: e
    Failed to load lint task.
    Install required gems using: bundle --path=.bundle/gems
    Next, invoke Rake using: bundle exec rake
    EOS
  end
end
