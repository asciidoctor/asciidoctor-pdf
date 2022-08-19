# frozen_string_literal: true

# TODO update value of release-line attribute in antora.yml
# TODO update Antora playbook in docs.asciidoctor.org
# TODO create v2.2.x milestone in issue tracker

old_release_line, new_release_line = ARGV
unless old_release_line && new_release_line
  warn 'Please specify both an old release line and a new release line.'
  exit 1
end
new_prerelease = '.0-alpha.0'
release_version = [new_release_line, new_prerelease].join
old_release_line_branch = %(v#{old_release_line}.x)

version_file = Dir['lib/**/version.rb'].first
readme_file = 'README.adoc'
antora_file = 'docs/antora.yml'

%x(git checkout -b #{old_release_line_branch})
%x(git push origin #{old_release_line_branch})
%x(git switch -)
%x(git worktree add ../#{old_release_line_branch} #{old_release_line_branch})

version_contents = (File.readlines version_file, mode: 'r:UTF-8').map do |l|
  (l.include? 'VERSION') ? (l.sub %r/'[^']+'/, %('#{release_version}')) : l
end

readme_contents = File.readlines readme_file, mode: 'r:UTF-8'
readme_contents.delete_at 2 if readme_contents[2].start_with? 'v'

antora_contents = (File.readlines antora_file, mode: 'r:UTF-8').map do |l|
  if l.start_with? 'prerelease: '
    %(prerelease: #{new_prerelease}\n)
  elsif l.start_with? 'version: '
    %(version: '#{new_release_line}'\n)
  else
    l
  end
end

File.write version_file, version_contents.join, mode: 'w:UTF-8'
File.write readme_file, readme_contents.join, mode: 'w:UTF-8'
File.write antora_file, antora_contents.join, mode: 'w:UTF-8'

%x(git add #{version_file} #{readme_file} #{antora_file})
%x(git commit -m 'set up main branch for #{new_release_line}.x development [no ci]')
%x(git push origin main)
