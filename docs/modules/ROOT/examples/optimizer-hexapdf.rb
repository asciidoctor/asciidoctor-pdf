require 'hexapdf/cli'

class OptimizerHexaPDF < Asciidoctor::PDF::Optimizer::Base
  register_for 'hexapdf'

  def initialize *_args
    super
    app = HexaPDF::CLI::Application.new
    app.instance_variable_set :@force, true
    @optimize = app.main_command.commands['optimize']
    @optimize.singleton_class.attr_reader :out_options
    @optimize.out_options[:compress_pages] = true
    #@optimize.out_options[:object_streams] = :preserve
    #@optimize.out_options[:xref_streams] = :preserve
    #@optimize.out_options[:streams] = :preserve # or :uncompress
  end

  def optimize_file path
    @optimize.execute path, path
    @optimize.out_options[:compress_pages] = false
    nil
  rescue
    # retry without page compression, which can sometimes fail
    @optimize.out_options[:compress_pages] = false
    @optimize.execute path, path
    nil
  end
end
