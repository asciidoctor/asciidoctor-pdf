require 'asciidoctor/pdf'
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

PDF::Inspector::Text.prepend(Module.new do
  def page= page
    @page_number = page.number
    super
  end

  def move_text_position tx, ty
    @positions << [tx, ty, @page_number]
  end
end)

class PDFTextInspector < PDF::Inspector
  attr_accessor :text
  attr_accessor :pages

  def initialize
    @color = nil
    @cursor = nil
    @fonts = {}
    @text = []
    @pages = []
  end

  def find_text filter
    filter = { string: filter } unless ::Hash === filter
    if ::Regexp === filter[:string]
      string_rx = filter.delete :string
      @text.select {|candidate| filter <= candidate && (string_rx.match? candidate[:string]) }
    else
      @text.select {|candidate| filter <= candidate }
    end
  end

  def strings
    @text.map {|it| it[:string] }
  end

  def page= page
    @pages << { size: (page.attributes[:MediaBox].slice 2, 2), text: [] }
    @page_number = page.number
    @state = PDF::Reader::PageState.new page
    page.fonts.each do |label, stream|
      base_font = stream[:BaseFont].to_s
      base_font = (base_font.partition '+')[-1] if base_font.include? '+'
      @fonts[label] = base_font
    end
  end

  def set_text_font_and_size *params
    @state.set_text_font_and_size(*params)
    @font_settings = { name: @fonts[params[0]], size: params[1], color: @color }
  end

  def set_color_for_stroking_and_special *params
    @color = params.map {|it| '%02X' % (it.to_f * 255).round }.join
  end

  def move_text_position x, y
    @cursor = { page_number: @page_number, x: x, y: y }
  end

  def show_text_with_positioning chunks
    show_text chunks.reject {|candidate| Numeric === candidate }.join, true
  end

  def show_text text, kerned = false
    string = @state.current_font.to_utf8 text
    if @cursor
      accum = @cursor
      accum[:order] = @text.size + 1
      accum[:font_name] = @font_settings[:name]
      accum[:font_size] = @font_settings[:size]
      accum[:font_color] = @font_settings[:color]
      accum[:string] = string
      @text << accum
      @pages[-1][:text] << accum
      @cursor = nil
    else
      (accum = @text[-1])[:string] += string
    end
    accum[:kerned] ||= kerned
  end
end

RSpec.configure do |config|
  config.before :suite do
    FileUtils.mkdir_p output_dir
  end

  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true
  end

  def asciidoctor_2_or_better?
    defined? Asciidoctor::Converter.for
  end

  def asciidoctor_1_5_7_or_better?
    defined? Asciidoctor::LoggerManager
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
    text: PDFTextInspector,
    page: PDF::Inspector::Page,
    rect: PDF::Inspector::Graphics::Rectangle,
    line: PDF::Inspector::Graphics::Line,
  }).default = PDFTextInspector

  def to_pdf input, opts = {}
    analyze = opts.delete :analyze
    opts[:attributes] = 'nofooter' unless opts.key? :attributes
    if (theme_overrides = opts.delete :theme_overrides)
      opts[:pdf_theme] = Asciidoctor::PDF::ThemeLoader.load_theme.tap {|theme| theme_overrides.each {|k, v| theme[k] = v } }
    end
    if Pathname === input
      opts[:to_dir] = output_dir unless opts.key? :to_dir
      pdf_io = (Asciidoctor.convert_file input, (opts.merge backend: 'pdf', safe: :safe)).attr 'outfile'
    else
      # NOTE use header_footer for compatibility with Asciidoctor < 2
      pdf_io = StringIO.new (Asciidoctor.convert input, (opts.merge backend: 'pdf', safe: :safe, header_footer: true)).render
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
    if asciidoctor_1_5_7_or_better?
      old_logger = Asciidoctor::LoggerManager.logger
      logger = Asciidoctor::MemoryLogger.new
      logger.level = level if level
      begin
        Asciidoctor::LoggerManager.logger = logger
        yield logger
      ensure
        Asciidoctor::LoggerManager.logger = old_logger
      end
    else
      old_stderr = $stderr
      $stderr = StringIO.new
      begin
        yield
      ensure
        $stderr = old_stderr
      end
    end
  end
end
