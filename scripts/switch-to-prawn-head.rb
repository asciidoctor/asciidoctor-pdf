require 'fileutils'

# NOTE it's necessary to hot patch the installed gem so that RubyGems can find it without Bundler
prawn_spec = Gem::Specification.find_by_name 'prawn'
old_requirements = prawn_spec.runtime_dependencies.map {|it| [it.name, it.requirements_list[0]] }.to_h
new_requirements = nil
FileUtils.rm_r prawn_spec.gem_dir, secure: true if Dir.exist? prawn_spec.gem_dir
Process.wait Process.spawn %(git clone --depth=1 https://github.com/prawnpdf/prawn #{File.basename prawn_spec.gem_dir}), chdir: prawn_spec.gems_dir

prawn_spec_replacement = nil

# Option A: patch dependency versions
#new_prawn_spec_contents = File.read (File.join prawn_spec.gem_dir, 'prawn.gemspec'), mode: 'r:UTF-8'
#ttfunk_version_spec = (%r/'ttfunk', *'(.+?)'/.match new_prawn_spec_contents)[1]
#pdf_core_version_spec = (%r/'pdf-core', *'(.+?)'/.match new_prawn_spec_contents)[1]
#prawn_spec_replacement = prawn_spec
#  .to_ruby
#  .gsub(%r/(ttfunk.+?)"[^"]+"/, %(\\1"#{ttfunk_version_spec}"))
#  .gsub(%r/(pdf-core.+?)"[^"]+"/, %(\\1"#{pdf_core_version_spec}"))

# Option B: regenerate spec file
Dir.chdir prawn_spec.gem_dir do
  new_prawn_spec_contents = File.readlines 'prawn.gemspec', mode: 'r:UTF-8'
  new_prawn_spec = eval new_prawn_spec_contents.join, nil, (File.join prawn_spec.gem_dir, 'prawn.gemspec')
  new_requirements = new_prawn_spec
    .runtime_dependencies
    .map {|it| [it.name, it.requirements_list[0]] }.to_h
    .delete_if {|name| old_requirements.key? name }
  new_prawn_spec.version = prawn_spec.version
  prawn_spec_replacement = new_prawn_spec.to_ruby
end

File.write prawn_spec.spec_file, prawn_spec_replacement
new_requirements.each do |name, requirement|
  File.write 'Gemfile', %(gem '#{name}', '#{requirement}', require: false), mode: 'a'
end unless new_requirements.empty?
