require 'hexapdf/cli'

class OptimizerHexaPDF < Asciidoctor::PDF::Optimizer::Base
  register_for 'hexapdf'

  def initialize *_args
    super
    app = HexaPDF::CLI::Application.new
    app.instance_variable_set :@force, true
    @optimize = app.main_command.commands['optimize']
    @optimize.singleton_class.attr_reader :out_options
    options = @optimize.out_options
    options.compress_pages = true
    #options.object_streams = :preserve
    #options.xref_streams = :preserve
    #options.streams = :preserve # or :uncompress
  end

  def optimize_file path
    @optimize.execute path, path
    nil
  rescue
    # retry without page compression, which can sometimes fail
    @optimize.out_options.compress_pages = false
    @optimize.execute path, path
    nil
  ensure
    @optimize.out_options.compress_pages = false
  end
end
