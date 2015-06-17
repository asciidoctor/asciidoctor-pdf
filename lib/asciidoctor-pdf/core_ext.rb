require_relative 'core_ext/array'
require_relative 'core_ext/numeric'
if RUBY_ENGINE == 'rbx'
  require_relative 'core_ext/ostruct'
end
