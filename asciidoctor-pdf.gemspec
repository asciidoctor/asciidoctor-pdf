# -*- encoding: utf-8 -*-
require File.expand_path('lib/asciidoctor-pdf/version', File.dirname(__FILE__))

Gem::Specification.new do |s| 
  s.name = 'asciidoctor-pdf'
  s.version = Asciidoctor::Pdf::VERSION

  s.summary = 'Converts AsciiDoc documents to PDF files using Prawn'
  s.description = <<-EOS
An extension for Asciidoctor that converts AsciiDoc documents to PDF files using the Prawn PDF generator.
  EOS

  s.author = 'OpenDevise Inc.'
  s.email = 'dan@opendevise.io'
  s.homepage = 'https://github.com/asciidoctor/asciidoctor-pdf'
  s.license = 'MIT'

  s.required_ruby_version = '>= 1.9'

  begin
    s.files = `git ls-files -z -- */* {README.adoc,LICENSE.adoc,NOTICE.adoc,Rakefile}`.split "\0"
  rescue
    s.files = Dir['**/*']
  end

  s.executables = %w(asciidoctor-pdf optimize-pdf)
  s.test_files = s.files.grep(/^(?:test|spec|feature)\/.*$/)
  s.require_paths = %w(lib)

  s.has_rdoc = true
  s.rdoc_options = %(--charset=UTF-8 --title="Asciidoctor PDF" --main=README.adoc -ri)
  s.extra_rdoc_files = %w(README.adoc LICENSE.adoc NOTICE.adoc)

  s.add_development_dependency 'rake', '~> 10.0'
  #s.add_development_dependency 'rdoc', '~> 4.1.0'

  s.add_runtime_dependency 'asciidoctor', ['>= 1.5.0.preview.7', '< 1.6.0']
  s.add_runtime_dependency 'coderay', '1.1.0'
  s.add_runtime_dependency 'prawn', '0.13.1'
  s.add_runtime_dependency 'prawn-svg', '0.12.0.12'
  s.add_runtime_dependency 'treetop', '1.4.15'
  s.add_runtime_dependency 'tilt', '2.0.0'
  s.add_runtime_dependency 'slim', '2.0.2'

  #s.add_runtime_dependency 'thread_safe', '~> 0.3.1'
end
