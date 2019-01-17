require 'tempfile'

# The purpose of this code is strictly to backport the Tempfile.create method
# from Ruby, which became available in the 2.1.0 version of the language. This
# backport does not introduce any new functionality.
#
# The code in this file has been adapted from the lib/tempfile.rb and
# lib/tmpdir.rb source files in the C Ruby implementation, which is licensed
# under the terms of the 2-clause BSD license. You can obtain the original
# source from the C Ruby 2.5 distribution or
# https://github.com/ruby/ruby/blob/ruby_2_5/lib/tempfile.rb and
# https://github.com/ruby/ruby/blob/ruby_2_5/lib/tmpdir.rb, respectively.

if RUBY_VERSION < '2.1.0'
  class Tempfile
    FILE_SEPARATORS = %(#{::File::SEPARATOR}#{::File::ALT_SEPARATOR})

    def self.create basename = '', tmpdir = nil, options = {}
      tmpfile = nil
      mode = (options.delete :mode) || 0
      create_tmpname basename, tmpdir, options do |tmppath, n, opts|
        tmpfile = ::File.open tmppath, (mode |= ::File::RDWR | ::File::CREAT | ::File::EXCL), (opts.merge perm: 0600)
      end
      tmpfile
    end unless respond_to? :create

    def self.create_tmpname basename, tmpdir = nil, options = {}
      tmpdir ||= ::Dir.tmpdir
      max_try = options.delete :max_try
      n = nil
      prefix, suffix = basename
      prefix = prefix.delete FILE_SEPARATORS
      suffix = suffix ? (suffix.delete FILE_SEPARATORS) : ''
      now = ::Time.now.strftime '%Y%m%d'
      begin
        path = ::File.join tmpdir, %(#{prefix}#{now}-#{$$}-#{(rand 0x100000000).to_s 36}#{n ? "-#{n}" : ''}#{suffix})
        yield path, n, options
      rescue ::Errno::EEXIST
        n = (n || 0) + 1
        retry if !max_try or n < max_try
        raise %(cannot generate temporary name using `#{basename}' under `#{tmpdir}')
      end
      path
    end
  end
end
