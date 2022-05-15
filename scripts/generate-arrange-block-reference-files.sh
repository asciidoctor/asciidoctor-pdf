#!/bin/bash

rm -rf sandbox/gen
mkdir -p sandbox/gen
cd sandbox/gen
echo -e 'source "https://rubygems.org"\n\ngem "hexapdf"' > Gemfile
bundle --path=.bundle/gems
sed -i 's/update_fields: true/update_fields: false/' $(bundle exec gem which hexapdf/document)

cd -
for adoc in spec/fixtures/arrange-block-*.adoc; do
  base=${adoc##*/}
  pdf="${base%.*}.pdf"
  bundle exec asciidoctor-pdf -D sandbox/gen -a reproducible -a source-highlighter=rouge -a nofooter $adoc
  cd sandbox/gen
  bundle exec hexapdf optimize --force $pdf ../../spec/reference/$pdf
  cd -
done

adoc=spec/fixtures/arrange-block-below-top-does-not-fit.adoc
pdf=arrange-block-below-top-does-not-fit-prepress.pdf
bundle exec asciidoctor-pdf -o sandbox/gen/$pdf -a reproducible -a source-highlighter=rouge -a nofooter -d book -a media=prepress $adoc
cd sandbox/gen
bundle exec hexapdf optimize --force $pdf ../../spec/reference/$pdf
cd -

for file in spec/reference/arrange-block-*.pdf; do
  ruby -e "File.binwrite '$file', ((File.binread '$file').sub %r/\/ID\[.*\]\/Type/, '/ID[<9AA982E8DC3A53FE1E1E3D1BD0933F99><9AA982E8DC3A53FE1E1E3D1BD0933F99>]/Type')"
done
rm -rf sandbox/gen
