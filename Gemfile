source 'https://rubygems.org'

# Look in asciidoctor-pdf.gemspec for runtime and development dependencies
gemspec

if (ruby_version = Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.1.0')
  if ruby_version < (Gem::Version.new '2.0.0')
    gem 'addressable', '2.4.0'
    gem 'prawn', '1.3.0'
    gem 'prawn-svg', '0.21.0'
    gem 'rake', '12.2.1'
  else
    gem 'prawn', '2.1.0'
    gem 'prawn-svg', '0.26.0'
  end
end

group :examples do
  gem 'rouge', '2.2.1'
  # Add unicode (preferred) or activesupport to transform case of text containing multibyte chars on Ruby < 2.4
  #gem 'activesupport', '4.2.7.1' if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
  #gem 'unicode' if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.4.0')
end

group :docs do
  gem 'yard'
end
