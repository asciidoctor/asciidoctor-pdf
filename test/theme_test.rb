# encoding: UTF-8
unless defined? ASCIIDOCTOR_PDF_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'helper/test_helper'
end

require 'pdf-reader'


#
# in a context, test method allows you to render a file from test/data/ to tmp/
# the file is deleted after the test execution if delete_after is not false (true by default)
# the test method takes a block where you can do asserts on the generated pdf using reader parameter
#
# Note: you can add as secodn parameter to_file which is the path of the generated file if needed
#
# see test_helper#render for more details
#

context 'Tests' do

  test 'adoc to pdf, basic generation' do
    render 'simple.adoc' do |reader|
      assert_equal 'The Title', reader.info[:Title]
      assert_equal 'Writer #1, Writer #2', reader.info[:Author]
      assert_equal 'Writer #1, Writer #2', reader.info[:Producer]
      assert_equal "The Title\n\n\n Writer #1, Writer #2\n\n\n\n\n     Version 1.0\n\n     2015-05-19", reader.pages[0].text
      assert_equal "a sub title\n\nwith some text", reader.pages[1].text
    end
  end

end
