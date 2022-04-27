#!/bin/bash

rm -rf sandbox/gen
mkdir -p sandbox/gen
cd sandbox/gen
echo -e 'source "https://rubygems.org"\n\ngem "hexapdf"' > Gemfile
bundle --path=.bundle/gems
cd -
for adoc in spec/fixtures/arrange-block-*.adoc; do
  base=${adoc##*/}
  pdf="${base%.*}.pdf"
  bundle exec asciidoctor-pdf -D sandbox/gen -a source-highlighter=rouge -a nofooter $adoc
  cd sandbox/gen
  bundle exec hexapdf optimize --force $pdf ../../spec/reference/$pdf
  cd -
done

adoc=spec/fixtures/arrange-block-below-top-does-not-fit.adoc
pdf=arrange-block-below-top-does-not-fit-prepress.pdf
bundle exec asciidoctor-pdf -o sandbox/gen/$pdf -a source-highlighter=rouge -a nofooter -d book -a media=prepress $adoc
cd sandbox/gen
bundle exec hexapdf optimize --force $pdf ../../spec/reference/$pdf
cd -

rm -rf sandbox/gen
