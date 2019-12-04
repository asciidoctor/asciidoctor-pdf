# frozen_string_literal: true

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new :lint do |t|
    t.patterns = ['Rakefile', 'Gemfile', 'tasks/*.rake', 'lib/**/*.rb', 'spec/**/*.rb']
  end
rescue LoadError => e
  task :lint do
    raise 'Failed to load lint task.
Install required gems using: bundle --path=.bundle/gems
Then, invoke Rake using: bundle exec rake', cause: e
  end
end
