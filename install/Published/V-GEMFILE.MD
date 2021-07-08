Gemfile
source 'https://rubygems.org'

gem 'asciidoctor-pdf'
gem 'prawn-table', github: 'prawnpdf/prawn-table', branch: 'HEAD'
You can then install the gems into your project using the bundle command:

$ bundle config set --local path .bundle/gems && bundle
Since you’re using Bundler to manage the gems, you’ll need to prefix all commands with bundle exec. For example:

$ bundle exec asciidoctor-pdf -v
Thus, to any command present in the following sections, be sure to include this prefix.

Run the Application
Assuming all the required gems install properly, verify you can run the asciidoctor-pdf script:

$ asciidoctor-pdf -v
