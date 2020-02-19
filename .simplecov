SimpleCov.start do
  add_filter %w(/.bundle/ /spec/ /lib/asciidoctor/pdf/formatted_text/parser.rb)
  coverage_dir 'coverage/report-simplecov'
end
