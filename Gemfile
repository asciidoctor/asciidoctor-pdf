# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

gem 'asciidoctor', ENV['ASCIIDOCTOR_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_VERSION'
gem 'asciidoctor-diagram', ENV['ASCIIDOCTOR_DIAGRAM_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_DIAGRAM_VERSION'
gem 'coderay', '~> 1.1.0', require: false
gem 'open-uri-cached', '~> 1.0.0', require: false
gem 'prawn-gmagick', ENV['PRAWN_GMAGICK_VERSION'], require: false if ENV.key? 'PRAWN_GMAGICK_VERSION'
gem 'pygments.rb', ENV['PYGMENTS_VERSION'], require: false if ENV.key? 'PYGMENTS_VERSION'
gem 'rghost', ENV['RGHOST_VERSION'], require: false if ENV.key? 'RGHOST_VERSION'
# Asciidoctor PDF supports Rouge >= 2 (verified in CI build using 2.0.0)
gem 'rouge', (ENV.fetch 'ROUGE_VERSION', '~> 3.0'), require: false
gem 'text-hyphen', require: false

group :docs do
  gem 'yard', require: false
end

group :lint do
  if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.6.0')
    gem 'rubocop', '~> 1.28.0', require: false
    gem 'rubocop-rake', '~> 0.6.0', require: false
    gem 'rubocop-rspec', '~> 2.10.0', require: false
  else
    gem 'rubocop', '~> 1.30.0', require: false
    gem 'rubocop-rake', '~> 0.6.0', require: false
    gem 'rubocop-rspec', '~> 2.11.0', require: false
  end
end

group :coverage do
  gem 'deep-cover-core', '~> 1.1.0', require: false
  gem 'simplecov', '~> 0.21.0', require: false
end
