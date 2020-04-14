# frozen_string_literal: true

source 'https://rubygems.org'

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

gem 'asciidoctor', ENV['ASCIIDOCTOR_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_VERSION'
gem 'open-uri-cached', require: false
gem 'prawn-gmagick', ENV['PRAWN_GMAGICK_VERSION'], require: false if ENV.key? 'PRAWN_GMAGICK_VERSION'
# NOTE use prawn-table from upstream (pre-0.2.3) to verify fix for #599
gem 'prawn-table', git: 'https://github.com/prawnpdf/prawn-table.git', ref: '515f2db294866a343b05d15f94e5fb417a32f6ff', require: false
gem 'pygments.rb', ENV['PYGMENTS_VERSION'], require: false if ENV.key? 'PYGMENTS_VERSION'
gem 'rghost', ENV['RGHOST_VERSION'], require: false if ENV.key? 'RGHOST_VERSION'
gem 'rouge', ENV['ROUGE_VERSION'], require: false if ENV.key? 'ROUGE_VERSION'
gem 'text-hyphen', require: false
# Add unicode (preferred) or activesupport to transform case of text containing multibyte chars on Ruby < 2.4
gem 'unicode', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
#gem 'activesupport', '4.2.7.1', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')

group :docs do
  gem 'yard', require: false
end

group :lint do
  unless Gem.win_platform? && RUBY_ENGINE == 'ruby' && (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
    gem 'rubocop', '~> 0.81.0', require: false
    gem 'rubocop-rspec', '~> 1.38.0', require: false
  end
end

group :coverage do
  gem 'deep-cover-core', '~> 0.7.0', require: false
  gem 'simplecov', '~> 0.17.0', require: false
end
