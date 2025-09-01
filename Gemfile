# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

gem 'asciidoctor', ENV['ASCIIDOCTOR_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_VERSION'
if ENV.key? 'ASCIIDOCTOR_DIAGRAM_VERSION'
  gem 'asciidoctor-diagram', ENV['ASCIIDOCTOR_DIAGRAM_VERSION'], require: false
  gem 'asciidoctor-diagram-plantuml', '1.2025.3', require: false
end
gem 'asciidoctor-kroki', ENV['ASCIIDOCTOR_KROKI_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_KROKI_VERSION'
gem 'bigdecimal', require: false if (Gem::Version.new RUBY_VERSION) >= (Gem::Version.new '3.4.0')
gem 'coderay', '~> 1.1.0', require: false
gem 'ffi-icu', ENV['FFI_ICU_VERSION'], require: false if ENV.key? 'FFI_ICU_VERSION'
gem 'open-uri-cached', '~> 1.0.0', require: false
gem 'prawn-gmagick', ENV['PRAWN_GMAGICK_VERSION'], require: false if (ENV.key? 'PRAWN_GMAGICK_VERSION') && RUBY_ENGINE == 'ruby'
gem 'pygments.rb', ENV['PYGMENTS_VERSION'], require: false if ENV.key? 'PYGMENTS_VERSION'
gem 'rghost', ENV['RGHOST_VERSION'], require: false if ENV.key? 'RGHOST_VERSION'
# Asciidoctor PDF supports Rouge >= 2 (verified in CI build using 2.0.0)
gem 'rouge', (ENV.fetch 'ROUGE_VERSION', %(~> #{RUBY_ENGINE == 'jruby' ? '3' : '4'}.0)), require: false unless ENV['ROUGE_VERSION'] == 'false'
gem 'text-hyphen', require: false

group :docs do
  gem 'yard', require: false
end

group :lint do
  gem 'rubocop', '~> 1.62.0', require: false
  gem 'rubocop-rake', '~> 0.6.0', require: false
  gem 'rubocop-rspec', '~> 2.27.0', require: false
end

group :coverage do
  gem 'deep-cover-core', '~> 1.1.0', require: false
  gem 'json', '~> 2.7', require: false if (Gem::Version.new RUBY_VERSION) > (Gem::Version.new '3.3.4')
  gem 'simplecov', '~> 0.22.0', require: false
end
