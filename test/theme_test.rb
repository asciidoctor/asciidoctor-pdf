# encoding: UTF-8
unless defined? ASCIIDOCTOR_PDF_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'helper/test_helper'
end

require 'pdf-reader'

# sanity check to ensure we really have a correctly generated PDF
def basic_pdf_asserts reader
  assert_equal 'The Title', reader.info[:Title]
  assert_equal 'A writer', reader.info[:Author]
  assert_equal 'A writer', reader.info[:Producer]
end

context 'Theme' do

  test 'first page can have a background' do
    render 'bg.adoc', 'bg.pdf' do |reader|
      basic_pdf_asserts reader

      count = 0
      reader.pages[0].xobjects.each do |name, stream|
        if stream.hash[:Subtype] == :Image
          count += 1
        end
      end
      assert_equal 1, count
    end
  end


  test 'footer can get a logo' do
    render 'footer.adoc', 'footer.pdf' do |reader|
      basic_pdf_asserts reader

      assert_equal 3, reader.pages.length
      reader.pages.each do |page|
        unless page.number == 1
          count = 0
          page.xobjects.each do |name, stream|
            if stream.hash[:Subtype] == :Image
              count += 1
            end
          end
          assert_equal 1, count
        end
      end
    end
  end

end
