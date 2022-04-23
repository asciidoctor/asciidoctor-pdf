# frozen_string_literal: true

require 'time'

release_version = ENV['RELEASE_VERSION']
prerelease = (release_version.count '[a-z]') > 0 ? %(.#{(release_version.split '.', 3)[-1]}) : nil
release_date = Time.now.strftime '%Y-%m-%d'
release_user = ENV['RELEASE_USER']

version_file = Dir['lib/**/version.rb'].first
readme_file = 'README.adoc'
changelog_file = 'CHANGELOG.adoc'
antora_file = 'docs/antora.yml'

version_contents = (File.readlines version_file, mode: 'r:UTF-8').map do |l|
  (l.include? 'VERSION') ? (l.sub %r/'[^']+'/, %('#{release_version}')) : l
end

readme_contents = (File.readlines readme_file, mode: 'r:UTF-8').map do |l|
  (l.start_with? ':release-version:') ? %(:release-version: #{release_version}\n) : l
end
if readme_contents[2].start_with? 'v'
  readme_contents[2] = %(v#{release_version}, #{release_date}\n)
else
  readme_contents.insert 2, %(v#{release_version}, #{release_date}\n)
end

changelog_contents = File.readlines changelog_file, mode: 'r:UTF-8'
if (last_release_idx = changelog_contents.index {|l| (l.start_with? '== ') && (%r/^== \d/.match? l) })
  previous_release_version = (changelog_contents[last_release_idx].match %r/\d\S+/)[0]
else
  last_release_idx = changelog_contents.length
end
changelog_contents.insert last_release_idx, <<~END
=== Details

{url-repo}/releases/tag/v#{release_version}[git tag]#{previous_release_version ? %( | {url-repo}/compare/v#{previous_release_version}\\...v#{release_version}[full diff]) : ''}

END
if (unreleased_idx = changelog_contents.index {|l| (l.start_with? '== Unreleased') && l.rstrip == '== Unreleased' })
  changelog_contents[unreleased_idx] = %(== #{release_version} (#{release_date}) - @#{release_user}\n)
else
  changelog_contents.insert last_release_idx, <<~END
  == #{release_version} (#{release_date}) - @#{release_user}

  _No changes since previous release._

  END
end

antora_contents = (File.readlines antora_file, mode: 'r:UTF-8').map do |l|
  (l.start_with? 'prerelease:') ? %(prerelease: #{prerelease ? ?' + prerelease + ?' : 'false'}\n) : l
end

File.write version_file, version_contents.join, mode: 'w:UTF-8'
File.write readme_file, readme_contents.join, mode: 'w:UTF-8'
File.write changelog_file, changelog_contents.join, mode: 'w:UTF-8'
File.write antora_file, antora_contents.join, mode: 'w:UTF-8'
