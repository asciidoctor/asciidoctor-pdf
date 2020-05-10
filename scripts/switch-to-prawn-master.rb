require 'fileutils'

# NOTE it's necessary to hot patch the installed gem so that RubyGems can find it without Bundler
prawn_spec = Gem::Specification.find_by_name 'prawn'
File.write prawn_spec.spec_file, (prawn_spec.to_ruby.gsub %r/(pdf-core.+?)~> 0\.7\.0/, '\1~> 0.8.1')
FileUtils.rm_r prawn_spec.gem_dir, secure: true if Dir.exist? prawn_spec.gem_dir
Process.wait Process.spawn %(git clone --depth=1 https://github.com/prawnpdf/prawn #{File.basename prawn_spec.gem_dir}), chdir: prawn_spec.gems_dir
