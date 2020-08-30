# frozen_string_literal: true

class File
  # NOTE: remove once minimum required Ruby version is at least 2.7
  def self.absolute_path? path
    (path.start_with? '/') || (ALT_SEPARATOR && (path.start_with? (absolute_path path).slice 0, 3))
  end unless respond_to? :absolute_path?
end
