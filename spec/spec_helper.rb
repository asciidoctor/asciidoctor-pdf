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

  def with_memory_logger level = nil
    old_logger = Asciidoctor::LoggerManager.logger
    memory_logger = Asciidoctor::MemoryLogger.new
    memory_logger.level = level if level
    begin
      Asciidoctor::LoggerManager.logger = memory_logger
      yield memory_logger
    ensure
      Asciidoctor::LoggerManager.logger = old_logger
    end
  end
end
