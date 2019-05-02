# NOTE these are either candidates for inclusion in Asciidoctor core or backports
require_relative 'asciidoctor_ext/abstract_block'
require_relative 'asciidoctor_ext/document'
require_relative 'asciidoctor_ext/section'
require_relative 'asciidoctor_ext/list'
require_relative 'asciidoctor_ext/list_item'
require_relative 'asciidoctor_ext/logging_shim' unless defined? Asciidoctor::Logging
require_relative 'asciidoctor_ext/image'
