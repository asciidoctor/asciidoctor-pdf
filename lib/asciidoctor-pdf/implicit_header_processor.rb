require 'asciidoctor'
require 'asciidoctor/extensions'

module Asciidoctor
module Pdf
# An include processor that skips the implicit author line below
# the document title in documents which are included.
class ImplicitHeaderProcessor < ::Asciidoctor::Extensions::IncludeProcessor
  def initialize document
    @document = document
  end

  def process doc, reader, target, attributes
    return reader unless File.exist? target
    ::File.open target, 'r' do |fd|
      # FIXME handle case where doc id is specified above title
      if (first_line = fd.readline) && (first_line.start_with? '= ')
        # HACK reset counters for each article for Asciidoctor Editions
        if (doc = @document).attr? 'env-editions'
          doc.counters.each do |(counter_key, counter_val)|
            doc.attributes.delete counter_key
          end
          doc.counters.clear
        end
        if (second_line = fd.readline)
          if AuthorInfoLineRx =~ second_line
            # FIXME temporary hack to set author and e-mail attributes; this should handle all attributes in header!
            author = [$1, $2, $3].compact * ' '
            email = $4
            reader.push_include fd.readlines, target, target, 3, attributes unless fd.eof?
            reader.push_include first_line, target, target, 1, attributes
            lines = [%(:author: #{author})]
            lines << %(:email: #{email}) if email
            reader.push_include lines, target, target, 2, attributes
          else
            lines = [second_line]
            lines += fd.readlines unless fd.eof?
            reader.push_include lines, target, target, 2, attributes
            reader.push_include first_line, target, target, 1, attributes
          end
        else
          reader.push_include first_line, target, target, 1, attributes
        end
      else
        lines = [first_line]
        lines += fd.readlines unless fd.eof?
        reader.push_include lines, target, target, 1, attributes
      end
    end
    reader
  end

  def handles? target
    # FIXME should not require this hack to skip processing bio
    !(target.end_with? 'bio.adoc') && ((target.end_with? '.adoc') || (target.end_with? '.asciidoc'))
  end

  # FIXME this method shouldn't be required
  def update_config config
    (@config ||= {}).update config
  end
end
end
end
