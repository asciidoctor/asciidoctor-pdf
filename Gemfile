source 'https://rubygems.org'

gem 'prawn', '1.3.0' if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.0.0')

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

group :examples do
  gem 'rouge', '2.0.6'
  # Add unicode (preferred) or activesupport to transform case of text containing multibyte chars on Ruby < 2.4
  #gem 'activesupport', '4.2.7.1' if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
  #gem 'unicode' if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
end
