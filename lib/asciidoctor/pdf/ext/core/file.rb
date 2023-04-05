# frozen_string_literal: true

File.singleton_class.prepend (Module.new do
  # NOTE: JRuby < 9.4 doesn't implement this method; JRuby 9.4 implements it incorrectly
  def absolute_path? path
    (::Pathname.new path).absolute? && ((path.chr == '/' && File::SEPARATOR == '/') || !(URI.split path)[2])
  end
end) if RUBY_ENGINE == 'jruby'
