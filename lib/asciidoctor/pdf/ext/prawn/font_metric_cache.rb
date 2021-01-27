# frozen_string_literal: true

# TODO: remove when upgrading to prawn-2.5.0
class Prawn::FontMetricCache::CacheEntry
  def initialize font, options, size
    font = font.hash
    super
  end
end if Prawn::FontMetricCache::CacheEntry.members == [:font, :options, :string]
