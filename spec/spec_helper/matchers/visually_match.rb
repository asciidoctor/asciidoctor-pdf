# frozen_string_literal: true

require 'chunky_png'

module RSpec::Matchers
  REFERENCE_DIR = File.absolute_path (File.join '..', '..', 'reference'), __dir__

  def compute_image_differences reference, actual, difference = nil
    diff = []
    if reference
      reference_image = ::ChunkyPNG::Image.from_file reference
      if actual
        actual_image = ::ChunkyPNG::Image.from_file actual
      else
        actual_image = ::ChunkyPNG::Image.new reference_image.width, reference_image.height
      end
    else
      actual_image = ::ChunkyPNG::Image.from_file actual
      reference_image = ::ChunkyPNG::Image.new actual_image.width, actual_image.height
    end

    actual_image.height.times do |y|
      actual_image.row(y).each_with_index do |pixel, x|
        diff << [x, y] unless pixel == reference_image[x, y]
      end
    end

    if !diff.empty? && difference
      x = diff.map {|xy| xy[0] }
      y = diff.map {|xy| xy[1] }
      actual_image.rect x.min, y.min, x.max, y.max, (ChunkyPNG::Color.rgb 0, 255, 0)
      actual_image.save difference
    end

    diff.length
  end
end

RSpec::Matchers.define :visually_match do |reference_filename, skip_pages: nil|
  reference_path = (Pathname.new reference_filename).absolute? ?
    reference_filename :
    (File.join RSpec::Matchers::REFERENCE_DIR, reference_filename)
  match do |actual_path|
    warn %(#{RSpec.current_example.location} uses visual comparison but is not tagged with visual: true) unless RSpec.current_example.metadata[:visual]
    return false unless File.exist? reference_path
    images_output_dir = output_file 'visual-comparison-workdir'
    Dir.mkdir images_output_dir unless Dir.exist? images_output_dir
    output_basename = File.join images_output_dir, (File.basename actual_path, '.pdf')
    pdftocairo_result = system 'pdftocairo', '-png', actual_path, %(#{output_basename}-actual)
    raise Errno::ENOENT, 'pdftocairo' if pdftocairo_result.nil?
    system 'pdftocairo', '-png', reference_path, %(#{output_basename}-reference)

    pixels = 0
    tmp_files = [actual_path]

    files = Dir[%(#{output_basename}-{actual,reference}-*.png)].map {|filename| (/-(?:actual|reference)-(\d+)\.png$/.match filename)[1] }.sort.uniq
    return false if files.empty?
    files.each do |idx|
      next if skip_pages&.include? idx.to_i
      reference_page_filename = %(#{output_basename}-reference-#{idx}.png)
      reference_page_filename = nil unless File.exist? reference_page_filename
      tmp_files << reference_page_filename if reference_page_filename
      actual_page_filename = %(#{output_basename}-actual-#{idx}.png)
      actual_page_filename = nil unless File.exist? actual_page_filename
      tmp_files << actual_page_filename if actual_page_filename
      next if reference_page_filename && actual_page_filename && (FileUtils.compare_file reference_page_filename, actual_page_filename)
      pixels += compute_image_differences reference_page_filename, actual_page_filename, %(#{output_basename}-diff-#{idx}.png)
    end

    if pixels > 0
      false
    else
      tmp_files.each {|it| File.unlink it } unless ENV.key? 'DEBUG'
      true
    end
  end

  failure_message {|actual_path| %(expected #{actual_path} to be visually identical to #{reference_path}) }
end
