require 'asciidoctor-pdf'
require 'pathname'
require 'pdf/inspector'

RSpec.configure do |config|
  config.before :suite do
    FileUtils.mkdir_p output_dir
  end

  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true
  end

  def fixtures_dir
    File.join __dir__, 'fixtures'
  end

  def fixture_file path
    File.join fixtures_dir, path
  end

  def output_dir
    File.join __dir__, 'output'
  end

  def output_file path
    File.join output_dir, path
  end

  def to_pdf input, opts = {}
    analyze = opts.delete :analyze
    if Pathname === input
      pdf_io = (Asciidoctor.convert_file input, (opts.merge backend: 'pdf', safe: :safe)).attr 'outfile'
    else
      pdf_io = StringIO.new (Asciidoctor.convert input, (opts.merge backend: 'pdf', safe: :safe, standalone: true)).render
    end
    analyze ? ((analyze == :text ? PDF::Inspector::Text : PDF::Inspector::Page).analyze pdf_io) : (PDF::Reader.new pdf_io)
  end

  def get_names pdf
    catalog = (objects = pdf.objects)[objects.trailer[:Root]]
    Hash[*objects[objects[catalog[:Names]][:Dests]][:Names]]
  end

  def get_page_size pdf, page_num
    catalog = (objects = pdf.objects)[objects.trailer[:Root]]
    objects[objects[catalog[:Pages]][:Kids][page_num - 1]][:MediaBox].slice 2, 2
  end

  def get_page_num pdf, page
    catalog = (objects = pdf.objects)[objects.trailer[:Root]]
    page_idx = objects[catalog[:Pages]][:Kids].index page
    page_idx ? (page_idx + 1) : nil
  end

  def with_memory_logger level = nil
    old_logger = Asciidoctor::LoggerManager.logger
    logger = Asciidoctor::MemoryLogger.new
    logger.level = level if level
    begin
      Asciidoctor::LoggerManager.logger = logger
      yield logger
    ensure
      Asciidoctor::LoggerManager.logger = old_logger
    end
  end
end
