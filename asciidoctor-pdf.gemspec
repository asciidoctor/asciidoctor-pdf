begin
  require_relative 'lib/asciidoctor/pdf/version'
rescue LoadError
  require 'asciidoctor/pdf/version'
end

Gem::Specification.new do |s|
  s.name = 'asciidoctor-pdf'
  s.version = Asciidoctor::PDF::VERSION
  s.summary = 'Converts AsciiDoc documents to PDF using Asciidoctor and Prawn'
  s.description = 'An extension for Asciidoctor that converts AsciiDoc documents to PDF using the Prawn PDF library.'
  s.authors = ['Dan Allen', 'Sarah White']
  s.email = 'dan@opendevise.com'
  s.homepage = 'https://asciidoctor.org/docs/asciidoctor-pdf'
  s.license = 'MIT'
  # NOTE required ruby version is informational only; it's not enforced since it can't be overridden and can cause builds to break
  #s.required_ruby_version = '>= 2.3.0'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/asciidoctor/asciidoctor-pdf/issues',
    'changelog_uri' => 'https://github.com/asciidoctor/asciidoctor-pdf/blob/master/CHANGELOG.adoc',
    'mailing_list_uri' => 'http://discuss.asciidoctor.org',
    'source_code_uri' => 'https://github.com/asciidoctor/asciidoctor-pdf'
  }

  # NOTE the logic to build the list of files is designed to produce a usable package even when the git command is not available
  begin
    files = (result = `git ls-files -z`.split ?\0).empty? ? Dir['**/*'] : result
  rescue
    files = Dir['**/*']
  end
  s.files = files.grep %r/^(?:(?:data|lib)\/.+|docs\/theming-guide\.adoc|(?:CHANGELOG|LICENSE|NOTICE|README)\.adoc|\.yardopts|#{s.name}\.gemspec)$/
  # FIXME optimize-pdf is currently a shell script, so listing it here won't work
  #s.executables = (files.grep %r/^bin\//).map {|f| File.basename f }
  s.executables = ['asciidoctor-pdf']
  s.require_paths = ['lib']
  #s.test_files = files.grep %r/^(?:test|spec|feature)\/.*$/

  s.add_runtime_dependency 'asciidoctor', '>= 1.5.3', '< 3.0.0'
  s.add_runtime_dependency 'prawn', '~> 2.2.0'
  s.add_runtime_dependency 'prawn-table', '~> 0.2.0'
  s.add_runtime_dependency 'prawn-templates', '~> 0.1.0'
  s.add_runtime_dependency 'prawn-svg', '~> 0.29.0'
  s.add_runtime_dependency 'prawn-icon', '~> 2.3.0'
  s.add_runtime_dependency 'safe_yaml', '~> 1.0.0'
  s.add_runtime_dependency 'thread_safe', '~> 0.3.0'
  s.add_runtime_dependency 'concurrent-ruby', '~> 1.1.0'
  # For our usage, treetop 1.6 is slower than treetop 1.5
  s.add_runtime_dependency 'treetop', '~> 1.5.0'

  s.add_development_dependency 'rake', '~> 12.3.0'
  # Asciidoctor PDF supports Rouge >= 2; Rouge 3.4.1 emits a superfluous warning in verbose mode
  s.add_development_dependency 'rouge', '~> 3.4.0', '!= 3.4.1'
  s.add_development_dependency 'rspec', '~> 3.8.0'
  s.add_development_dependency 'pdf-inspector', '~> 1.3.0'
  s.add_development_dependency 'chunky_png', '~> 1.3.0'
end
