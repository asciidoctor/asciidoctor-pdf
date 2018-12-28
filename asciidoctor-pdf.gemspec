# -*- encoding: utf-8 -*-
require File.expand_path '../lib/asciidoctor-pdf/version', __FILE__
require 'open3' unless defined? Open3

Gem::Specification.new do |s|
  s.name = 'asciidoctor-pdf'
  s.version = Asciidoctor::Pdf::VERSION

  s.summary = 'Converts AsciiDoc documents to PDF using Prawn'
  s.description = <<-EOS
An extension for Asciidoctor that converts AsciiDoc documents to PDF using the Prawn PDF library.
  EOS

  s.authors = ['Dan Allen', 'Sarah White']
  s.email = 'dan@opendevise.com'
  s.homepage = 'https://github.com/asciidoctor/asciidoctor-pdf'
  s.license = 'MIT'

  s.required_ruby_version = '>= 1.9.3'

  files = begin
    (result = Open3.popen3('git ls-files -z') {|_, out| out.read }.split %(\0)).empty? ? Dir['**/*'] : result
  rescue
    Dir['**/*']
  end
  s.files = files.grep %r/^(?:(?:data|lib)\/.+|docs\/theming-guide\.adoc|Gemfile|Rakefile|(?:CHANGELOG|LICENSE|NOTICE|README)\.adoc|#{s.name}\.gemspec)$/
  # FIXME optimize-pdf is currently a shell script, so listing it here won't work
  #s.executables = ['asciidoctor-pdf', 'optimize-pdf']
  s.executables = ['asciidoctor-pdf']
  s.test_files = files.grep %r/^(?:test|spec|feature)\/.*$/

  s.require_paths = ['lib']

  s.add_development_dependency 'rake', '~> 12.3.2'

  s.add_runtime_dependency 'asciidoctor', '>= 1.5.0'
  # prawn >= 2.0.0 requires Ruby >= 2.0.0, so we must cast a wider net to support Ruby 1.9.3
  s.add_runtime_dependency 'prawn', '>= 1.3.0', '< 2.3.0'
  s.add_runtime_dependency 'prawn-table', '0.2.2'
  # prawn-templates >= 0.0.5 requires prawn >= 2.2.0, so we must cast a wider net to support Ruby 1.9.3
  s.add_runtime_dependency 'prawn-templates', '>= 0.0.3', '<= 0.1.1'
  # prawn-svg >= 0.22.1 requires Ruby >= 2.0.0, so we must cast a wider net to support Ruby 1.9.3
  s.add_runtime_dependency 'prawn-svg', '>= 0.21.0', '< 0.28.0'
  s.add_runtime_dependency 'prawn-icon', '1.4.0'
  s.add_runtime_dependency 'safe_yaml', '~> 1.0.4'
  s.add_runtime_dependency 'thread_safe', '~> 0.3.6'
  s.add_runtime_dependency 'concurrent-ruby', '~> 1.0.5'
  # For our usage, treetop 1.6.2 is slower than 1.5.3
  s.add_runtime_dependency 'treetop', '1.5.3'
end
