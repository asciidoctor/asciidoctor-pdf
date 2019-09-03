if ENV['COVERAGE'] == 'deep'
  ENV['DEEP_COVER'] = 'true'
  require 'deep_cover'
elsif ENV['COVERAGE'] == 'true'
  require 'deep_cover/builtin_takeover'
  require 'simplecov'
end

require 'asciidoctor/pdf'
require 'base64'
require 'chunky_png'
require 'open3' unless defined? Open3
require 'pathname' unless defined? Pathname
require 'pdf/inspector'

# NOTE fix warning in Prawn::Font:TTF
Prawn::Font::TTF.prepend (Module.new do
  def initialize *args
    @italic_angle = nil
    super
  end
end)

# NOTE fix warning in TTFunk::Table
TTFunk::Table.prepend (Module.new do
  def initialize *args
    @offset = nil
    super
  end
end)

PDF::Reader.prepend (Module.new do
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

PDF::Inspector::Text.prepend (Module.new do
  def page= page
    @page_number = page.number
    super
  end

  def move_text_position tx, ty
    @positions << [tx, ty, @page_number]
  end
end)

class EnhancedPDFTextInspector < PDF::Inspector
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

  def strings text = @text
    text.map {|it| it[:string] }
  end

  def lines text = @text
    prev_y = nil
    text.reduce [] do |accum, it|
      current_line = prev_y && (prev_y - it[:y]).abs < 6 ? accum.pop : ''
      accum << %(#{current_line}#{it[:string]})
      prev_y = it[:y]
      accum
    end
  end

  def page pagenum
    @pages[pagenum - 1]
  end

  def page= page
    @pages << { size: (page.attributes[:MediaBox].slice 2, 2), text: [] }
    @page_number = page.number
    @state = ::PDF::Reader::PageState.new page
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
    show_text chunks.reject {|candidate| ::Numeric === candidate }.join, true
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

class LineInspector < PDF::Inspector
  attr_accessor :lines

  def initialize
    @lines = []
    @from = nil
    @color = nil
    @graphic_states = {}
    @page_number = 1
    @width = nil
  end

  def append_line x, y
    @lines << { page_number: @page_number, from: @from, to: { x: x, y: y }, color: @color, width: @width }
  end

  def begin_new_subpath x, y
    @from = { x: x, y: y }
  end

  def page= page
    @page_number = page.number
    @graphic_states = page.graphic_states
  end

  def set_color_for_stroking_and_special *params
    @color = params.map {|it| '%02X' % (it.to_f * 255).round }.join
  end

  def set_graphics_state_parameters ref
    if (opacity = @graphic_states[ref][:ca])
      @color += '%02X' % (opacity * 255).round
    end
  end

  def set_line_width line_width
    @width = line_width
  end
end

RSpec.configure do |config|
  config.before :suite do
    FileUtils.mkdir_p output_dir
  end

  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true unless ENV.key? 'DEBUG'
  end

  def asciidoctor_2_or_better?
    defined? Asciidoctor::Converter.for
  end

  def asciidoctor_1_5_7_or_better?
    defined? Asciidoctor::LoggerManager
  end

  def asciidoctor_pdf_bin opts = {}
    bin_path = File.join __dir__, '..', 'bin', 'asciidoctor-pdf'
    if opts.fetch :with_ruby, true
      ruby = File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']
      if (ruby_opts = opts[:ruby_opts])
        [ruby, *ruby_opts, bin_path]
      else
        [ruby, bin_path]
      end
    else
      bin_path
    end
  end

  def run_command cmd, *args
    Dir.chdir __dir__ do
      if Array === cmd
        args.unshift(*cmd)
        cmd = args.shift
      end
      Open3.capture3 cmd, *args
    end
  end

  def examples_dir
    File.join __dir__, '..', 'examples'
  end

  def example_file path
    File.join examples_dir, path
  end

  def fixtures_dir
    File.join __dir__, 'fixtures'
  end

  def fixture_file path, opts = {}
    if opts[:relative]
      (((Pathname.new fixtures_dir) / path).relative_path_from Pathname.new Dir.pwd).to_s
    else
      File.join fixtures_dir, path
    end
  end

  def output_dir
    File.join __dir__, 'output'
  end

  def output_file path
    File.join output_dir, path
  end

  (PDF_INSPECTOR_CLASS = {
    text: EnhancedPDFTextInspector,
    page: PDF::Inspector::Page,
    rect: PDF::Inspector::Graphics::Rectangle,
    line: LineInspector,
  }).default = EnhancedPDFTextInspector

  alias :original_to_pdf :to_pdf

  def to_pdf input, opts = {}
    analyze = opts.delete :analyze
    opts[:attributes] = { 'imagesdir' => fixtures_dir, 'nofooter' => '' } unless opts.key? :attributes
    if (attribute_overrides = opts.delete :attribute_overrides)
      (opts[:attributes] ||= {}).update attribute_overrides
    end
    if Hash === (pdf_theme = opts[:pdf_theme])
      opts[:pdf_theme] = build_pdf_theme pdf_theme, (pdf_theme.delete :extends)
    end
    if Pathname === input
      opts[:to_dir] = output_dir unless opts.key? :to_dir
      doc = Asciidoctor.convert_file input, (opts.merge backend: 'pdf', safe: :safe)
      if analyze == :document
        return doc.converter
      else
        pdf_io = doc.attr 'outfile'
      end
    elsif analyze == :document
      return Asciidoctor.convert input, (opts.merge backend: 'pdf', safe: :safe, header_footer: true)
    else
      # NOTE use header_footer for compatibility with Asciidoctor < 2
      pdf_io = StringIO.new (Asciidoctor.convert input, (opts.merge backend: 'pdf', safe: :safe, header_footer: true)).render
    end
    analyze ? (PDF_INSPECTOR_CLASS[analyze].analyze pdf_io) : (PDF::Reader.new pdf_io)
  end

  def to_pdf_file input, output_filename, opts = {}
    opts[:to_file] = (to_file = File.join output_dir, output_filename)
    opts[:attributes] = { 'imagesdir' => fixtures_dir, 'nofooter' => '' } unless opts.key? :attributes
    if (attribute_overrides = opts.delete :attribute_overrides)
      (opts[:attributes] ||= {}).update attribute_overrides
    end
    if Hash === (pdf_theme = opts[:pdf_theme])
      opts[:pdf_theme] = build_pdf_theme pdf_theme, (pdf_theme.delete :extends)
    end
    if Pathname === input
      Asciidoctor.convert_file input, (opts.merge backend: 'pdf', safe: :safe)
    else
      Asciidoctor.convert input, (opts.merge backend: 'pdf', safe: :safe, header_footer: true)
    end
    to_file
  end

  def build_pdf_theme overrides = {}, extends = nil
    (Asciidoctor::PDF::ThemeLoader.load_theme extends).tap {|theme| overrides.each {|k, v| theme[k] = v } }
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
      dest_page = pages.find {|candidate| candidate.page_object == dest_page_object }
      top = dest_page.attributes[:MediaBox][3] == dest[3]
      if (count = entry[:Count]) == 0
        closed = true
        children = []
      else
        closed = count < 0
        children = extract_outline pdf, entry
      end
      result << { title: title, dest: { pagenum: dest_page.number, x: dest[2], y: dest[3], top: top }, closed: closed, children: children }
      entry = entry[:Next]
    end
    result
  end

  def get_names pdf
    objects = pdf.objects
    Hash[*objects[objects[pdf.catalog[:Names]][:Dests]][:Names]]
  end

  def get_page_labels pdf
    objects = pdf.objects
    Hash[*objects[pdf.catalog[:PageLabels]][:Nums]].reduce([]) {|accum, (idx, val)| accum[idx] = val[:P]; accum }
  end

  def get_annotations pdf, page_num = nil
    objects = pdf.objects
    if page_num
      (pdf.page page_num).attributes[:Annots].to_a.map {|ref| objects[ref] }
    else
      pdf.pages.reduce([]) {|accum, page| page.attributes[:Annots].to_a.each {|ref| accum << objects[ref] }; accum }
    end
  end

  def get_images pdf, page_num = nil
    if page_num
      (pdf.page page_num).xobjects.select {|_, candidate| candidate.hash[:Subtype] == :Image }.values
    else
      pdf.pages.reduce([]) {|accum, page| page.xobjects.each {|_, candidate| candidate.hash[:Subtype] == :Image ? (accum << candidate) : accum }; accum }
    end
  end

  def get_page_size pdf, page_num
    (pdf.page page_num).attributes[:MediaBox].slice 2, 2
  end

  def get_page_number pdf, page
    page = pdf.objects[page] if PDF::Reader::Reference === page
    found = pdf.pages.find {|candidate| candidate.page_object == page }
    found ? found.number : nil
  end

  def lorem_ipsum id
    (@lorem_ipsum_data ||= (YAML.load_file fixture_file 'lorem-ipsum.yml'))[id]
  end

  def windows?
    RbConfig::CONFIG['host_os'] =~ /win|ming/
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

  def compute_image_differences reference, actual, difference = nil
    diff = []
    if reference
      reference_image = ChunkyPNG::Image.from_file reference
      if actual
        actual_image = ChunkyPNG::Image.from_file actual
      else
        actual_image = ChunkyPNG::Image.new reference_image.width, reference_image.height
      end
    else
      actual_image = ChunkyPNG::Image.from_file actual
      reference_image = ChunkyPNG::Image.new actual_image.width, actual_image.height
    end

    actual_image.height.times do |y|
      actual_image.row(y).each_with_index do |pixel, x|
        diff << [x,y] unless pixel == reference_image[x,y]
      end
    end

    if diff.length > 0 && difference
      x = diff.map {|xy| xy[0] }
      y = diff.map {|xy| xy[1] }
      actual_image.rect x.min, y.min, x.max, y.max, (ChunkyPNG::Color.rgb 0, 255, 0)
      actual_image.save difference
    end

    diff.length
  end
end

RSpec::Matchers.define_negated_matcher :not_raise_exception, :raise_exception

RSpec::Matchers.define :have_size do |expected|
  match {|actual| actual.size == expected }
  failure_message {|actual| %(expected #{actual} to have size #{expected}, but was #{actual.size}) }
end

RSpec::Matchers.define :have_message do |expected|
  match do |logger|
    result = false
    if (messages = logger.messages).size == 1
      if (message = messages[0])[:severity] == expected[:severity]
        if Regexp === (expected_message = expected[:message])
          result = true if expected_message.match? message[:message]
        elsif expected_message.start_with? '~'
          result = true if message[:message].include? expected_message[1..-1]
        elsif message[:message] === expected_message
          result = true
        end
      end
    end
    result
  end

  failure_message { %(expected #{expected[:severity]} message#{expected[:message].chr == '~' ? ' containing ' : ' matching '}`#{expected[:message]}' to have been logged) }
end

RSpec::Matchers.define :log_message do |expected|
  match notify_expectation_failures: true do |actual|
    with_memory_logger expected[:using_log_level] do |logger|
      actual.call
      (expect logger).to have_message expected if logger
      true
    end
  end

  #match_when_negated notify_expectation_failures: true do |actual|
  #  with_memory_logger expected.to_h[:using_log_level] do |logger|
  #    actual.call
  #    logger ? logger.empty? : true
  #  end
  #end

  supports_block_expectations
end

# define matcher to replace `.not_to log_message` until notify_expectation_failures is supported for negated match
# see https://github.com/rspec/rspec-expectations/issues/1124
RSpec::Matchers.define :not_log_message do |expected|
  match notify_expectation_failures: true do |actual|
    with_memory_logger expected.to_h[:using_log_level] do |logger|
      actual.call
      logger ? logger.empty? : true
    end
  end

  supports_block_expectations
end

RSpec::Matchers.define :visually_match do |reference_filename|
  reference_path = (Pathname.new reference_filename).absolute? ? reference_filename : (File.join __dir__, 'reference', reference_filename)
  match do |actual_path|
    # NOTE add this line to detect which tests use a visual match
    #warn caller.find {|it| it.include? '_spec.rb:' }
    return false unless File.exist? reference_path
    images_output_dir = output_file 'visual-comparison-workdir'
    Dir.mkdir images_output_dir unless Dir.exist? images_output_dir
    output_basename = File.join images_output_dir, (File.basename actual_path, '.pdf')
    system 'pdftocairo', '-png', actual_path, %(#{output_basename}-actual)
    system 'pdftocairo', '-png', reference_path, %(#{output_basename}-reference)

    pixels = 0

    Dir[%(#{output_basename}-{actual,reference}-*.png)].map {|filename|
      (/-(?:actual|reference)-(\d+)\.png$/.match filename)[1]
    }.sort.uniq.each do |idx|
      reference_page_filename = %(#{output_basename}-reference-#{idx}.png)
      reference_page_filename = nil unless File.exist? reference_page_filename
      actual_page_filename = %(#{output_basename}-actual-#{idx}.png)
      actual_page_filename = nil unless File.exist? actual_page_filename
      next if reference_page_filename && actual_page_filename && (FileUtils.compare_file reference_page_filename, actual_page_filename)
      pixels += compute_image_differences reference_page_filename, actual_page_filename, %(#{output_basename}-diff-#{idx}.png)
    end

    pixels.zero?
  end

  failure_message {|actual_path| %(expected #{actual_path} to be visually identical to #{reference_path}) }
end
