require 'fileutils'

branch = ARGV[0] || 'main'
# NOTE it's necessary to hot patch the installed gem so that RubyGems can find it without Bundler
asciidoctor_spec = Gem::Specification.find_by_name 'asciidoctor'
FileUtils.rm_r asciidoctor_spec.gem_dir, secure: true if Dir.exist? asciidoctor_spec.gem_dir
Process.wait Process.spawn %(git clone -b #{branch} --depth=1 https://github.com/asciidoctor/asciidoctor #{File.basename asciidoctor_spec.gem_dir}), chdir: asciidoctor_spec.gems_dir

Dir.chdir asciidoctor_spec.gem_dir do
  new_asciidoctor_spec_contents = File.readlines 'asciidoctor.gemspec', mode: 'r:UTF-8'
  new_asciidoctor_spec = eval new_asciidoctor_spec_contents.join, nil, (File.join Dir.pwd, 'asciidoctor.gemspec')
  new_asciidoctor_spec.version = asciidoctor_spec.version
  File.write asciidoctor_spec.spec_file, new_asciidoctor_spec.to_ruby
end
