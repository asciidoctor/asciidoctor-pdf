# frozen_string_literal: true

require 'open3'
require 'socket'
require 'tmpdir'

module RSpec::ExampleGroupHelpers
  module TareFirstPageContentStreamNoop
    def tare_first_page_content_stream
      yield
    end
  end

  module_function

  def gem_available? gem_name
    Gem.loaded_specs.key? gem_name
  end

  def jruby?
    RUBY_ENGINE == 'jruby'
  end

  def windows?
    Gem.win_platform?
  end
end

module RSpec::ExampleHelpers
  def asciidoctor_bin
    bin_script 'asciidoctor', gem: 'asciidoctor'
  end

  def asciidoctor_pdf_bin
    bin_script 'asciidoctor-pdf'
  end

  def asciidoctor_pdf_optimize_bin
    bin_script 'asciidoctor-pdf-optimize'
  end

  def bin_script name, gem: 'asciidoctor-pdf'
    bin_path = Gem.bin_path gem, name
    if (defined? DeepCover) && !(DeepCover.const_defined? :TAKEOVER_IS_ON)
      [Gem.ruby, '-rdeep_cover', bin_path]
    elsif windows?
      [Gem.ruby, bin_path]
    else
      bin_path
    end
  end

  def build_pdf_theme overrides = {}, extends = nil
    (Asciidoctor::PDF::ThemeLoader.load_theme extends).tap {|theme| overrides.each {|k, v| theme[k] = v } }
  end

  def create_class super_class = Object, &block
    klass = Class.new super_class, &block
    Object.const_set %(AnonymousClass#{klass.object_id}).to_sym, klass
    klass
  end

  def docs_dir
    File.join project_dir, 'docs'
  end

  def doc_file path
    File.absolute_path path, docs_dir
  end

  def examples_dir
    File.join project_dir, 'examples'
  end

  def example_file path
    File.join examples_dir, path
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

  def fixtures_dir
    File.join spec_dir, 'fixtures'
  end

  def fixture_file path, relative: false
    if relative
      (((Pathname.new fixtures_dir) / path).relative_path_from Pathname.new Dir.pwd).to_s
    else
      File.join fixtures_dir, path
    end
  end

  def gem_available? gem_name
    RSpec::ExampleGroupHelpers.gem_available? gem_name
  end

  def get_annotations pdf, page_num = nil
    objects = pdf.objects
    if page_num
      (pdf.page page_num).attributes[:Annots].to_a.map {|ref| objects[ref] }
    else
      pdf.pages.each_with_object([]) {|page, accum| page.attributes[:Annots].to_a.each {|ref| accum << objects[ref] } }
    end
  end

  def get_dest pdf, name
    if (name_ref = (get_names pdf)[name]) && (dest = pdf.objects[name_ref])
      { page: pdf.objects[(page_ref = dest[0])], page_number: (get_page_number pdf, page_ref), x: dest[2], y: dest[3] }
    end
  end

  def get_images pdf, page_num = nil
    if page_num
      (pdf.page page_num).xobjects.select {|_, candidate| candidate.hash[:Subtype] == :Image }.values
    else
      pdf.pages.each_with_object([]) {|page, accum| page.xobjects.each {|_, candidate| candidate.hash[:Subtype] == :Image ? (accum << candidate) : accum } }
    end
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

  def get_page_number pdf, page
    page = pdf.objects[page] if PDF::Reader::Reference === page
    pdf.pages.find {|candidate| candidate.page_object == page }&.number
  end

  def get_page_size pdf, page_num = 1
    if PDF::Reader === pdf
      (pdf.page page_num).attributes[:MediaBox].slice 2, 2
    else
      pdf.pages[page_num - 1][:size]
    end
  end

  def home_dir
    windows? ? (Dir.home.tr ?\\, '/') : Dir.home
  end

  def lorem_ipsum id
    (@lorem_ipsum_data ||= (YAML.load_file fixture_file 'lorem-ipsum.yml'))[id]
  end

  def output_dir
    File.join spec_dir, 'output'
  end

  def output_file path
    File.join output_dir, path
  end

  def project_dir
    File.absolute_path '..', spec_dir
  end

  def run_command cmd, *args
    Dir.chdir spec_dir do
      if Array === cmd
        args.unshift(*cmd)
        cmd = args.shift
      end
      kw_args = Hash === args[-1] ? args.pop : {}
      env_override = kw_args[:env] || {}
      unless kw_args[:use_bundler]
        env_override['RUBYOPT'] = nil
      end
      if (out = kw_args[:out])
        Open3.pipeline_w([env_override, cmd, *args, out: out]) {} # rubocop:disable Lint/EmptyBlock
      else
        Open3.capture3 env_override, cmd, *args
      end
    end
  end

  def resolve_localhost
    Socket.ip_address_list.find(&:ipv4?).ip_address
  end

  def spec_dir
    File.absolute_path '..', __dir__
  end

  def tmp_dir
    File.join spec_dir, 'tmp'
  end

  def to_pdf input, opts = {}
    analyze = opts.delete :analyze
    if (debug = opts.delete :debug) && ENV['CI']
      raise ArgumentError, 'debug flag not permitted in CI'
    end
    enable_footer = opts.delete :enable_footer
    safe_mode = opts.fetch :safe, :safe
    opts[:attributes] = { 'imagesdir' => fixtures_dir } unless opts.key? :attributes
    opts[:attributes]['nofooter'] = '' unless enable_footer
    if (attribute_overrides = opts.delete :attribute_overrides)
      (opts[:attributes] ||= {}).update attribute_overrides
    end
    opts = opts.merge backend: 'pdf' unless opts.key? :backend
    if Hash === (pdf_theme = opts[:pdf_theme])
      pdf_theme_extends = (pdf_theme = pdf_theme.dup).delete :extends if pdf_theme.key? :extends
      opts[:pdf_theme] = build_pdf_theme pdf_theme, pdf_theme_extends
    end
    if Pathname === input
      opts[:to_dir] = output_dir unless opts.key? :to_dir
      doc = Asciidoctor.convert_file input, (opts.merge safe: safe_mode)
      return doc.converter if analyze == :document
      pdf_io = Pathname.new doc.attr 'outfile'
    elsif analyze == :document
      return Asciidoctor.convert input, (opts.merge safe: safe_mode, standalone: true)
    else
      Asciidoctor.convert input, (opts.merge safe: safe_mode, to_file: (pdf_io = StringIO.new), standalone: true)
    end
    File.write (File.join Dir.tmpdir, 'debug.pdf'), (Pathname === pdf_io ? pdf_io.read : pdf_io.string) if debug
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
      pdf_theme_extends = (pdf_theme = pdf_theme.dup).delete :extends if pdf_theme.key? :extends
      opts[:pdf_theme] = build_pdf_theme pdf_theme, pdf_theme_extends
    end
    opts = opts.merge backend: 'pdf' unless opts.key? :backend
    if Pathname === input
      Asciidoctor.convert_file input, (opts.merge safe: :safe)
    else
      Asciidoctor.convert input, (opts.merge safe: :safe, standalone: true)
    end
    to_file
  end

  def windows?
    RSpec::ExampleGroupHelpers.windows?
  end

  def with_content_spacer width, height, units = 'pt'
    contents = <<~EOS
    <svg width="#{width}#{units}" height="#{height}#{units}" viewBox="0 0 #{width} #{height}" version="1.0" xmlns="http://www.w3.org/2000/svg">
    <g>
    <rect style="fill:#999999" width="#{width}" height="#{height}" x="0" y="0"></rect>
    </g>
    </svg>
    EOS
    with_tmp_file '.svg', contents: contents do |spacer_file|
      yield spacer_file.path
    end
  end

  def with_local_webserver host = resolve_localhost, port = 9876
    base_dir = fixtures_dir
    server = TCPServer.new host, port
    server_thread = Thread.start do
      Thread.current[:requests] = requests = []
      while (session = server.accept)
        requests << (request = session.gets)
        if %r/^GET (\S+) HTTP\/1\.1$/ =~ request.chomp
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

  def with_pdf_theme_file data
    with_tmp_file '-theme.yml', contents: data do |theme_file|
      yield theme_file.path
    end
  end

  def with_tmp_file basename, contents: nil, tmpdir: tmp_dir
    basename = ['tmp-', basename] unless Array === basename
    Tempfile.create basename, tmpdir, encoding: 'UTF-8', newline: :universal do |tmp_file|
      if contents
        tmp_file.write contents
        tmp_file.close
      end
      yield tmp_file
    end
  end

  def with_svg_with_remote_image
    refname = 'main' if ((refname = %(v#{Asciidoctor::PDF::VERSION})).count '[a-z]') > 0
    image_url = "https://cdn.jsdelivr.net/gh/asciidoctor/asciidoctor-pdf@#{refname}/spec/fixtures/logo.png"
    svg_data = <<~EOS
    <svg width="1cm" height="1cm" version="1.1" viewBox="0 0 5 5" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <image x="0" y="0" width="5" height="5" xlink:href="#{image_url}"/>
    <rect x="0.25" y="0.25" width="4.5" height="4.5" fill-opacity="0" stroke="#000" stroke-width="0.5"/>
    </svg>
    EOS
    with_tmp_file '.svg', contents: svg_data do |tmp_file|
      yield tmp_file.path, image_url
    end
  end
end
