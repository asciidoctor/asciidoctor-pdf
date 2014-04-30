# -*- encoding: utf-8 -*-
require File.expand_path('lib/asciidoctor-pdf/version', File.dirname(__FILE__))

require 'rake/clean'

default_tasks = []

begin
  require 'bundler/gem_tasks'

  task :commit_release do
    Bundler::GemHelper.new.send :guard_clean
    sh %(git commit --allow-empty -a -m 'Release #{Asciidoctor::Pdf::VERSION}')
  end

  # Enhance the release task to create an explicit commit for the release
  Rake::Task[:release].enhance [:commit_release]
rescue LoadError
end

begin
  require 'rdoc/task'
  Rake::RDocTask.new do |t|
    t.rdoc_dir = 'rdoc'
    t.title = %(Asciidoctor EPUB3 #{Asciidoctor::Pdf::VERSION})
    t.main = %(README.adoc)
    t.rdoc_files.include 'README.adoc', 'LICENSE.adoc', 'NOTICE.adoc', 'lib/**/*.rb', 'bin/**/*'
  end
rescue LoadError
end

=begin NOT CURRENTLY IN USE
begin
  require 'rake/testtask'
  Rake::TestTask.new do |t|
    t.libs << 'test'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = true
    t.warning = true
    if RUBY_VERSION >= '2'
      t.options = '--tty=no'
    end
  end
  default_tasks << :test
rescue LoadError
end

begin
  require 'cucumber'
  require 'cucumber/rake/task'
  CUKE_RESULTS_FILE = 'feature-results.html'
  ARUBA_TMP_DIR = 'tmp'
  CLEAN << CUKE_RESULTS_FILE if File.file? CUKE_RESULTS_FILE
  CLEAN << ARUBA_TMP_DIR if File.directory? ARUBA_TMP_DIR
  desc 'Run features'
  Cucumber::Rake::Task.new :features do |t|
    opts = %(features --format html -o #{CUKE_RESULTS_FILE} --format progress -x --tags ~@pending)
    opts = %(#{opts} --tags #{ENV['TAGS']}) if ENV['TAGS']
    t.cucumber_opts = opts
    t.fork = false
  end

  desc 'Run features tagged as work-in-progress (@wip)'
  Cucumber::Rake::Task.new 'features:wip'  do |t|
    #t.cucumber_opts = %(features --format html -o #{CUKE_RESULTS_FILE} --format pretty -x -s --tags @wip)
    t.cucumber_opts = %(features --format html -o #{CUKE_RESULTS_FILE} --format progress -x --tags @wip)
    t.fork = false
  end

  default_tasks << :features
  task :cucumber => :features
  task 'cucumber:wip' => 'features:wip'
  task :wip => 'features:wip'
rescue LoadError
end
=end

task :default => default_tasks unless default_tasks.empty?
