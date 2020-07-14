# frozen_string_literal: true

class File
  class << self
    # NOTE: remove once minimum required Ruby version is at least 2.7
    def absolute_path? path
      (path.start_with? '/') || (ALT_SEPARATOR && (path.start_with? (absolute_path path).slice 0, 3))
    end unless method_defined? :absolute_path?
  end
end
