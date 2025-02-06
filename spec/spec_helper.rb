# frozen_string_literal: true

require_relative 'ignore-gem-warnings' if $VERBOSE

case ENV['COVERAGE']
when 'deep'
  ENV['DEEP_COVER'] = 'true'
  require 'deep_cover'
when 'true'
  require 'deep_cover/builtin_takeover'
  require 'simplecov'
end

require 'asciidoctor/pdf'
require 'fileutils'
require 'pathname'
require_relative 'spec_helper/ext'
require_relative 'spec_helper/helpers'
require_relative 'spec_helper/inspectors'
require_relative 'spec_helper/matchers'

RSpec.configure do |config|
  Warning[:experimental] = false if (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '3.0.0')

  config.extend RSpec::ExampleGroupHelpers
  config.include RSpec::ExampleHelpers

  helpers = Object.new.extend RSpec::ExampleHelpers

  config.before :suite do
    (Pathname.new helpers.output_dir).tap {|dir| dir.rmtree secure: true }.mkdir
    (Pathname.new helpers.tmp_dir).tap {|dir| dir.rmtree secure: true }.mkdir
  end

  config.after :suite do
    (Pathname.new helpers.output_dir).rmtree secure: true unless (ENV.key? 'DEBUG') || config.reporter.failed_examples.any? {|it| it.metadata[:visual] }
    (Pathname.new helpers.tmp_dir).rmtree secure: true
  end
end
