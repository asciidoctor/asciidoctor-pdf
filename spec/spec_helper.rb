require 'asciidoctor-pdf'
require 'pathname'
require 'pdf/inspector'

PDF::Reader.prepend(Module.new do
  def source
    objects.instance_variable_get :@io
  end

  def catalog
    root
  end

  def outlines
    objects[catalog[:Outlines]]
  end
end)

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

  (PDF_INSPECTOR_CLASS = {
    text: PDF::Inspector::Text,
    page: PDF::Inspector::Page,
    rect: PDF::Inspector::Graphics::Rectangle,
  }).default = PDF::Inspector::Page

  def to_pdf input, opts = {}
    analyze = opts.delete :analyze
    opts[:attributes] = 'nofooter' unless opts.key? :attributes
    if Pathname === input
      opts[:to_dir] = output_dir unless opts.key? :to_dir
      pdf_io = (Asciidoctor.convert_file input, (opts.merge backend: 'pdf', safe: :safe)).attr 'outfile'
    else
      pdf_io = StringIO.new (Asciidoctor.convert input, (opts.merge backend: 'pdf', safe: :safe, standalone: true)).render
    end
    analyze ? (PDF_INSPECTOR_CLASS[analyze].analyze pdf_io) : (PDF::Reader.new pdf_io)
  end

  def extract_outline pdf, list = pdf.outlines
    result = []
    objects = pdf.objects
    pages = pdf.pages
    entry = list[:First]
    while entry
      entry = objects[entry]
      title = (((title = entry[:Title]).slice 2, title.size).unpack 'n*').pack 'U*'
      dest = entry[:Dest]
      dest_page_object = objects[dest[0]]
      dest_page = pdf.pages.find {|candidate| candidate.page_object == dest_page_object }
      top = dest_page.attributes[:MediaBox][3] == dest[3]
      children = entry[:Count] > 0 ? (extract_outline pdf, entry) : []
      result << { title: title, dest: { pagenum: dest_page.number, x: dest[2], y: dest[3], top: top }, children: children }
      entry = entry[:Next]
    end
    result
  end

  def get_names pdf
    objects = pdf.objects
    Hash[*objects[objects[pdf.catalog[:Names]][:Dests]][:Names]]
  end

  def get_page_size pdf, page_num
    (pdf.page page_num).attributes[:MediaBox].slice 2, 2
  end

  def get_page_number pdf, page
    page = pdf.objects[page] if PDF::Reader::Reference === page
    found = pdf.pages.find {|candidate| candidate.page_object == page }
    found ? found.number : nil
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
