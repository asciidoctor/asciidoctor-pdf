# encoding: UTF-8

#
# copied from asciidoctor
#

ASCIIDOCTOR_PDF_PROJECT_DIR = File.dirname File.dirname File.dirname(__FILE__)
Dir.chdir ASCIIDOCTOR_PDF_PROJECT_DIR

if RUBY_VERSION < '1.9'
  require 'rubygems'
end

require 'simplecov' if ENV['COVERAGE'] == 'true'

require File.join(ASCIIDOCTOR_PDF_PROJECT_DIR, 'lib', 'asciidoctor-pdf')

require 'minitest/autorun'

autoload :FileUtils, 'fileutils'
autoload :Pathname,  'pathname'

RE_XMLNS_ATTRIBUTE = / xmlns="[^"]+"/
RE_DOCTYPE = /\s*<!DOCTYPE (.*)/

if defined? Minitest::Test
  # We're on Minitest 5+. Nothing to do here.
else
  # Minitest 4 doesn't have Minitest::Test yet.
  Minitest::Test = MiniTest::Unit::TestCase
end

class Minitest::Test
  # input: input adoc from test/data folder
  # output: output name in tmp/ folder
  # opts: generation options, side note: docdir is added automatically, backend is set to pdf by default and header_footer to true
  # delete_after: for debugging force it to false, allow to not delete the generated doc after the test
  # &asserts: a block where you can work on the generated output. First parameter is a pdf reader and second one the output file
  def render(input, output = nil, opts = {:backend => 'pdf', :header_footer => true}, delete_after = true, &asserts)
    file_dirname = File.dirname File.dirname(__FILE__)

    opts[:attributes] ||= {}
    opts[:attributes]['docdir'] = File.join file_dirname, 'data'

    input = File.read(File.join(File.expand_path(file_dirname), 'data', input))
    converter = Asciidoctor::Document.new(input.lines.entries, opts).render
    to_file = File.join(File.expand_path(file_dirname), '../', 'tmp', output || (input + '.pdf'))
    tmp_dir = File.dirname(to_file)
    Dir.mkdir(tmp_dir) unless File.exists?(tmp_dir)
    converter.render_file to_file

    unless File.exist? to_file
      fail 'can\'t generate ' + to_file
    end

    File.open(to_file, 'rb') do |io|
      reader = PDF::Reader.new(io)
      (asserts || lambda |o| {}).call(reader, to_file)
    end

    # don't delete if the test fails to be able to investigate
    if delete_after
      File.delete to_file
    end
  end
end

###
#
# Context goodness provided by @citrusbyte's contest.
# See https://github.com/citrusbyte/contest
#
###

# Contest adds +teardown+, +test+ and +context+ as class methods, and the
# instance methods +setup+ and +teardown+ now iterate on the corresponding
# blocks. Note that all setup and teardown blocks must be defined with the
# block syntax. Adding setup or teardown instance methods defeats the purpose
# of this library.
class Minitest::Test
  def self.setup(&block)
    define_method :setup do
      super(&block)
      instance_eval(&block)
    end
  end

  def self.teardown(&block)
    define_method :teardown do
      instance_eval(&block)
      super(&block)
    end
  end

  def self.context(*name, &block)
    subclass = Class.new(self)
    remove_tests(subclass)
    subclass.class_eval(&block) if block_given?
    const_set(context_name(name.join(" ")), subclass)
  end

  def self.test(name, &block)
    define_method(test_name(name), &block)
  end

  class << self
    alias_method :should, :test
    alias_method :describe, :context
  end

  private

  def self.context_name(name)
    "Test#{sanitize_name(name).gsub(/(^| )(\w)/) { $2.upcase }}".to_sym
  end

  def self.test_name(name)
    "test_#{sanitize_name(name).gsub(/\s+/,'_')}".to_sym
  end

  def self.sanitize_name(name)
    name.gsub(/\W+/, ' ').strip
  end

  def self.remove_tests(subclass)
    subclass.public_instance_methods.grep(/^test_/).each do |meth|
      subclass.send(:undef_method, meth.to_sym)
    end
  end
end

def context(*name, &block)
  Minitest::Test.context(name, &block)
end