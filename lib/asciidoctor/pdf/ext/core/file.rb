# frozen_string_literal: true

class File
  # NOTE: remove once minimum JRuby version is fully 2.7 compliant
  def self.absolute_path? path
    (::Pathname.new path).absolute?
  end unless respond_to? :absolute_path?
end
