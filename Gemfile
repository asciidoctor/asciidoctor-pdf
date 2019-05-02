source 'https://rubygems.org'

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

gem 'asciidoctor', ENV['ASCIIDOCTOR_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_VERSION'
# NOTE use prawn-table from upstream (pre-0.2.3) to verify fix for #599
gem 'prawn-table', git: 'https://github.com/prawnpdf/prawn-table.git', ref: '515f2db294866a343b05d15f94e5fb417a32f6ff'
# Add unicode (preferred) or activesupport to transform case of text containing multibyte chars on Ruby < 2.4
gem 'unicode', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
#gem 'activesupport', '4.2.7.1', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')

group :examples do
  gem 'rouge', '2.2.1', require: false
end

group :docs do
  gem 'yard', require: false
end
