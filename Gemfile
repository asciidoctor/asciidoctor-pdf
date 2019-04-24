source 'https://rubygems.org'

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

gem 'asciidoctor', ENV['ASCIIDOCTOR_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_VERSION'

group :examples do
  gem 'rouge', '2.2.1', require: false
  # Add unicode (preferred) or activesupport to transform case of text containing multibyte chars on Ruby < 2.4
  #gem 'activesupport', '4.2.7.1', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
  #gem 'unicode', require: false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
end

group :docs do
  gem 'yard', require: false
end
