# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

gem 'asciidoctor', ENV['ASCIIDOCTOR_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_VERSION'
# NOTE use prawn-table from upstream (pre-0.2.3) to verify fix for #599
gem 'prawn-table', git: 'https://github.com/prawnpdf/prawn-table.git', ref: '515f2db294866a343b05d15f94e5fb417a32f6ff', require: false
# Add unicode (preferred) or activesupport to transform case of text containing multibyte chars on Ruby < 2.4
gem 'unicode', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
#gem 'activesupport', '4.2.7.1', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
gem 'pygments.rb', ENV['PYGMENTS_VERSION'], require: false if ENV.key? 'PYGMENTS_VERSION'
gem 'rghost', ENV['RGHOST_VERSION'], require: false if ENV.key? 'RGHOST_VERSION'
gem 'rouge', ENV['ROUGE_VERSION'], require: false if ENV.key? 'ROUGE_VERSION'
gem 'text-hyphen', require: false

group :docs do
  gem 'yard', require: false
end

group :coverage do
  gem 'deep-cover-core', '~> 0.7.0', require: false if ENV.key? 'COVERAGE'
end
