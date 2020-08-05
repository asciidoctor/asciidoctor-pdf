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
require 'prawn/table/version'
require 'base64'
require 'chunky_png'
require 'fileutils' unless defined? FileUtils
require 'open3' unless defined? Open3
require 'pathname' unless defined? Pathname
require 'pdf/inspector'
require 'socket'

# NOTE: fix invalid bits for PNG in Gmagick
Gmagick.prepend (Module.new do
  def initialize image_blob
    super
    @bits = [@bits, 8].max
  end
end) if defined? GMagick::Image

# NOTE: fix warning in Prawn::Font:TTF
Prawn::Font::TTF.prepend (Module.new do
  def initialize *args
    @italic_angle = nil
    super
  end
end)

# NOTE: fix warning in TTFunk::Table
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
  include ::RSpec::Matchers

  attr_accessor :text
  attr_accessor :pages

  def initialize
    @color = nil
    @cursor = nil
    @fonts = {}
    @text = []
    @pages = []
  end

  def find_text string, filter = {}
    if ::Hash === string
      filter = string.merge filter
    else
      filter[:string] = string
    end
    if ::Regexp === filter[:string]
      string_rx = filter.delete :string
      @text.select {|candidate| filter <= candidate && (string_rx.match? candidate[:string]) }
    else
      @text.select {|candidate| filter <= candidate }
    end
  end

  def find_unique_text string, filter = {}
    result = find_text string, filter
    (expect result).to have_size 1 unless result.empty?
    result[0]
  end

  def strings text = @text
    text.map {|it| it[:string] }
  end

  def lines text = @text
    prev = nil
    text.each_with_object [] do |it, accum|
      #if prev && (prev[:y] == it[:y] || (prev[:y] - it[:y]).abs < [it[:font_size], prev[:font_size]].min * 0.5)
      if prev && (prev[:y] == it[:y] || (prev[:y] - it[:y]).abs < 6)
        if it[:x] - prev[:x] > prev[:width] + 0.5
          accum << %(#{accum.pop.rstrip} #{it[:string].lstrip})
        else
          accum << %(#{accum.pop}#{it[:string]})
        end
      else
        accum << it[:string]
      end
      prev = it
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

  # Tf
  def set_text_font_and_size *params
    @state.set_text_font_and_size(*params)
    @font_settings = { name: @fonts[params[0]], size: params[1], color: @color }
  end

  # scn (used for font color in SVG)
  def set_color_for_nonstroking_and_special *params
    @color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| '%02X' % (it.to_f * 255).round }.join
  end

  # SCN
  def set_color_for_stroking_and_special *params
    @color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| '%02X' % (it.to_f * 255).round }.join
  end

  def move_text_position x, y
    @cursor = { page_number: @page_number, x: x, y: y }
  end

  def show_text_with_positioning chunks
    show_text chunks.reject {|candidate| ::Numeric === candidate }.join, true
  end

  def show_text text, kerned = false
    # NOTE: this may be a rough approximation
    text_width = (@state.current_font.unpack text).reduce 0 do |width, code|
      width + (@state.current_font.glyph_width code) * @font_settings[:size] / 1000.0
    end

    string = @state.current_font.to_utf8 text
    if @cursor
      accum = @cursor
      accum[:order] = @text.size + 1
      accum[:font_name] = @font_settings[:name]
      accum[:font_size] = @font_settings[:size]
      accum[:font_color] = @font_settings[:color]
      accum[:string] = string
      accum[:width] = text_width
      @text << accum
      @pages[-1][:text] << accum
      @cursor = nil
    else
      (accum = @text[-1])[:string] += string
      accum[:width] += text_width
    end
    accum[:kerned] ||= kerned
  end
end

class ImageInspector < PDF::Inspector
  attr_reader :images

  def initialize
    @images = []
    @x = @y = @width = @height = nil
    @page_number = 0
  end

  def page= page
    @page_number = page.number
    @image_xobjects = page.xobjects.each_with_object({}) do |(name, xobject), accum|
      accum[name] = xobject if xobject.hash[:Subtype] == :Image
    end
  end

  def page_count
    @page_number
  end

  def concatenate_matrix width, _p2, _p3, height, x, y
    @width = width
    @height = height
    @x = x
    @y = y + height
  end

  def invoke_xobject name
    return unless @image_xobjects.key? name
    image_info = (image = @image_xobjects[name]).hash
    @images << { name: name, page_number: @page_number, x: @x, y: @y, width: @width, height: @height, intrinsic_height: image_info[:Height], intrinsic_width: image_info[:Width], data: image.data }
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
    @dash = nil
  end

  def append_curved_segment *args
    x, y = args.pop 2
    @from = { x: x, y: y }
  end

  def append_line x, y
    style = @dash ? (@dash[0] > @width ? :dashed : :dotted) : :solid
    @lines << { page_number: @page_number, from: @from, to: { x: x, y: y }, color: @color, width: @width, style: style } unless @color.nil? && @width.nil?
    @from = { x: x, y: y }
  end

  def begin_new_subpath x, y
    @from = { x: x, y: y }
  end

  def close_subpath
    @from = nil
  end

  def page= page
    @page_number = page.number
    @graphic_states = page.graphic_states
  end

  # SCN
  def set_color_for_stroking_and_special *params
    @color = params.size == 4 ? params.map {|it| it * 100 } : params.map {|it| '%02X' % (it.to_f * 255).round }.join
  end

  # gs
  def set_graphics_state_parameters ref
    if (opacity = @graphic_states[ref][:ca])
      @color += '%02X' % (opacity * 255).round
    end
  end

  # d
  # NOTE: dash is often set before line width, so we must defer resolving until line is appended
  def set_line_dash a, _b
    @dash = a.empty? ? nil : a
  end

  # w
  def set_line_width line_width
    @width = line_width
  end

  # Q
  def restore_graphics_state
    @width = nil
  end
end

RSpec.configure do |config|
  config.before :suite do
    FileUtils.rm_r output_dir, force: true, secure: true
    FileUtils.mkdir output_dir
  end

  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true unless (ENV.key? 'DEBUG') || config.reporter.failed_examples.find {|it| it.metadata[:visual] }
  end

  def bin_script name, opts = {}
    bin_path = Gem.bin_path (opts.fetch :gem, 'asciidoctor-pdf'), name
    if (defined? DeepCover) && !(DeepCover.const_defined? :TAKEOVER_IS_ON)
      [Gem.ruby, '-rdeep_cover', bin_path]
    elsif windows?
      [Gem.ruby, bin_path]
    else
      bin_path
    end
  end

  def asciidoctor_bin
    bin_script 'asciidoctor', gem: 'asciidoctor'
  end

  def asciidoctor_pdf_bin
    bin_script 'asciidoctor-pdf'
  end

  def asciidoctor_pdf_optimize_bin
    bin_script 'asciidoctor-pdf-optimize'
  end

  def run_command cmd, *args
    Dir.chdir __dir__ do
      if Array === cmd
        args.unshift(*cmd)
        cmd = args.shift
      end
      kw_args = Hash === args[-1] ? args.pop : {}
      env_override = kw_args[:env] || {}
      unless kw_args[:use_bundler]
        env_override['RUBYOPT'] = nil
        if defined? Bundler
          rubylib = []
          if (prawn_table_spec = Gem::Specification.find_by_name 'prawn-table')
            rubylib << (prawn_table_spec.source.path + 'lib').to_s
          end
          env_override['RUBYLIB'] = rubylib.join File::PATH_SEPARATOR unless rubylib.empty?
        end
      end
      if (out = kw_args[:out])
        Open3.pipeline_w([env_override, cmd, *args, { out: out }]) {}
      else
        Open3.capture3 env_override, cmd, *args
      end
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
    image: ImageInspector,
    line: LineInspector,
    page: PDF::Inspector::Page,
    rect: PDF::Inspector::Graphics::Rectangle,
    text: EnhancedPDFTextInspector,
  }).default = EnhancedPDFTextInspector

  def to_pdf input, opts = {}
    analyze = opts.delete :analyze
    enable_footer = opts.delete :enable_footer
    opts[:attributes] = { 'imagesdir' => fixtures_dir } unless opts.key? :attributes
    opts[:attributes]['nofooter'] = '' unless enable_footer
    if (attribute_overrides = opts.delete :attribute_overrides)
      (opts[:attributes] ||= {}).update attribute_overrides
    end
    opts = opts.merge backend: 'pdf' unless opts.key? :backend
    if Hash === (pdf_theme = opts[:pdf_theme])
      opts[:pdf_theme] = build_pdf_theme pdf_theme, (pdf_theme.delete :extends)
    end
    if Pathname === input
      opts[:to_dir] = output_dir unless opts.key? :to_dir
      doc = Asciidoctor.convert_file input, (opts.merge safe: :safe)
      if analyze == :document
        return doc.converter
      else
        pdf_io = doc.attr 'outfile'
      end
    elsif analyze == :document
      return Asciidoctor.convert input, (opts.merge safe: :safe, standalone: true)
    else
      Asciidoctor.convert input, (opts.merge safe: :safe, to_file: (pdf_io = StringIO.new), standalone: true)
    end
    analyze ? (PDF_INSPECTOR_CLASS[analyze].analyze pdf_io) : (PDF::Reader.new pdf_io)
  end

  def to_pdf_file input, output_filename, opts = {}
    opts[:to_file] = (to_file = File.join output_dir, output_filename)
    enable_footer = opts.delete :enable_footer
    opts[:attributes] = { 'imagesdir' => fixtures_dir } unless opts.key? :attributes
    opts[:attributes]['nofooter'] = '' unless enable_footer
    if (attribute_overrides = opts.delete :attribute_overrides)
      (opts[:attributes] ||= {}).update attribute_overrides
    end
    if Hash === (pdf_theme = opts[:pdf_theme])
      opts[:pdf_theme] = build_pdf_theme pdf_theme, (pdf_theme.delete :extends)
    end
    if Pathname === input
      Asciidoctor.convert_file input, (opts.merge backend: 'pdf', safe: :safe)
    else
      Asciidoctor.convert input, (opts.merge backend: 'pdf', safe: :safe, standalone: true)
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
    labels = get_page_labels pdf
    entry = list[:First] if list
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
      result << { title: title, dest: { pagenum: dest_page.number, label: labels[dest_page.number - 1], x: dest[2], y: dest[3], top: top }, closed: closed, children: children }
      entry = entry[:Next]
    end
    result
  end

  def get_names pdf
    if (names = pdf.catalog[:Names])
      objects = pdf.objects
      Hash[*objects[objects[names][:Dests]][:Names]]
    else
      {}
    end
  end

  def get_page_labels pdf
    objects = pdf.objects
    Hash[*objects[pdf.catalog[:PageLabels]][:Nums]].each_with_object([]) {|(idx, val), accum| accum[idx] = val[:P] }
  end

  def get_annotations pdf, page_num = nil
    objects = pdf.objects
    if page_num
      (pdf.page page_num).attributes[:Annots].to_a.map {|ref| objects[ref] }
    else
      pdf.pages.each_with_object([]) {|page, accum| page.attributes[:Annots].to_a.each {|ref| accum << objects[ref] } }
    end
  end

  def get_images pdf, page_num = nil
    if page_num
      (pdf.page page_num).xobjects.select {|_, candidate| candidate.hash[:Subtype] == :Image }.values
    else
      pdf.pages.each_with_object([]) {|page, accum| page.xobjects.each {|_, candidate| candidate.hash[:Subtype] == :Image ? (accum << candidate) : accum } }
    end
  end

  def get_page_size pdf, page_num = 1
    if PDF::Reader === pdf
      (pdf.page page_num).attributes[:MediaBox].slice 2, 2
    else
      pdf.pages[page_num - 1][:size]
    end
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

  def home_dir
    windows? ? (Dir.home.tr ?\\, '/') : Dir.home
  end

  def with_memory_logger level = nil
    old_logger, logger = Asciidoctor::LoggerManager.logger, Asciidoctor::MemoryLogger.new
    logger.level = level if level
    Asciidoctor::LoggerManager.logger = logger
    yield logger
  ensure
    Asciidoctor::LoggerManager.logger = old_logger
  end

  def with_local_webserver host = resolve_localhost, port = 9876
    base_dir = fixtures_dir
    server = TCPServer.new host, port
    server_thread = Thread.start do
      Thread.current[:requests] = requests = []
      while (session = server.accept)
        requests << (request = session.gets)
        if /^GET (\S+) HTTP\/1\.1$/ =~ request.chomp
          resource = (resource = $1) == '' ? '.' : resource
        else
          session.print %(HTTP/1.1 405 Method Not Allowed\r\nContent-Type: text/plain\r\n\r\n)
          session.print %(405 - Method not allowed\r\n)
          session.close
          next
        end
        resource, _query_string = resource.split '?', 2 if resource.include? '?'
        if File.file? (resource_file = (File.join base_dir, resource))
          if (ext = (File.extname resource_file)[1..-1])
            mimetype = ext == 'adoc' ? 'text/plain' : %(image/#{ext})
          else
            mimetype = 'text/plain'
          end
          session.print %(HTTP/1.1 200 OK\r\nContent-Type: #{mimetype}\r\n\r\n)
          File.open resource_file, 'rb:utf-8:utf-8' do |fd|
            session.write fd.read 256 until fd.eof?
          end
        else
          session.print %(HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n)
          session.print %(404 - Resource not found.\r\n)
        end
        session.close
      end
    end
    begin
      yield %(http://#{host}:#{port}), server_thread
    ensure
      server_thread.exit
      server_thread.value
      server.close
    end
  end

  def resolve_localhost
    Socket.ip_address_list.find(&:ipv4?).ip_address
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
        diff << [x, y] unless pixel == reference_image[x, y]
      end
    end

    if !diff.empty? && difference
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
  actual = nil
  match do |logger|
    result = false
    if (messages = logger.messages).size == 1
      if (message = messages[0])[:severity] == expected[:severity]
        if Hash === (message_text = message[:message])
          message_text = message_text[:text]
        end
        if Regexp === (expected_message = expected[:message])
          result = true if expected_message.match? message_text
        elsif expected_message.start_with? '~'
          result = true if message_text.include? expected_message[1..-1]
        elsif message_text === expected_message
          result = true
        end
      end
      actual = message
    end
    result
  end

  failure_message do
    %(expected #{expected[:severity]} message#{expected[:message].to_s.chr == '~' ? ' containing ' : ' matching '}`#{expected[:message]}' to have been logged) + (actual ? %(, but got #{actual[:severity]}: #{actual[:message]}) : '')
  end
end

RSpec::Matchers.define :log_message do |expected|
  match notify_expectation_failures: true do |actual|
    if expected
      log_level_override = expected.delete :using_log_level
      expected = nil if expected.empty?
    end
    with_memory_logger log_level_override do |logger|
      actual.call
      if logger
        if expected
          (expect logger).to have_message expected
        else
          (expect logger).not_to be_empty
        end
      end
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
    # NOTE: uncomment this line and run `bundle exec rspec -t ~visual` to detect which tests use a visual match
    #warn caller.find {|it| it.include? '_spec.rb:' }
    return false unless File.exist? reference_path
    images_output_dir = output_file 'visual-comparison-workdir'
    Dir.mkdir images_output_dir unless Dir.exist? images_output_dir
    output_basename = File.join images_output_dir, (File.basename actual_path, '.pdf')
    system 'pdftocairo', '-png', actual_path, %(#{output_basename}-actual)
    system 'pdftocairo', '-png', reference_path, %(#{output_basename}-reference)

    pixels = 0
    tmp_files = [actual_path]

    Dir[%(#{output_basename}-{actual,reference}-*.png)].map {|filename|
      (/-(?:actual|reference)-(\d+)\.png$/.match filename)[1]
    }.sort.uniq.each do |idx|
      reference_page_filename = %(#{output_basename}-reference-#{idx}.png)
      reference_page_filename = nil unless File.exist? reference_page_filename
      tmp_files << reference_page_filename if reference_page_filename
      actual_page_filename = %(#{output_basename}-actual-#{idx}.png)
      actual_page_filename = nil unless File.exist? actual_page_filename
      tmp_files << actual_page_filename if actual_page_filename
      next if reference_page_filename && actual_page_filename && (FileUtils.compare_file reference_page_filename, actual_page_filename)
      pixels += compute_image_differences reference_page_filename, actual_page_filename, %(#{output_basename}-diff-#{idx}.png)
    end

    if pixels > 0
      false
    else
      tmp_files.each {|it| File.unlink it } unless ENV.key? 'DEBUG'
      true
    end
  end

  failure_message {|actual_path| %(expected #{actual_path} to be visually identical to #{reference_path}) }
end
