DeepCover.configure do
  output 'coverage/report-deep-cover'
  paths %w(./lib)
  reporter :text if ENV['CI']
  reporter :istanbul if ENV['DEEP_COVER_REPORTER'] == 'istanbul'
end
