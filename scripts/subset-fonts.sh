#!/usr/bin/bash

export SOURCE_DATE_EPOCH=$(date -d 2019-07-15T00:00:00 +%s)

MPLUS_TESTFLIGHT=mplus-TESTFLIGHT-063a
SOURCE_DIR=fonts
BUILD_DIR=../data/fonts

mkdir -p $SOURCE_DIR
rm -f $SOURCE_DIR/*.ttf

cd $SOURCE_DIR

if [ ! -d $MPLUS_TESTFLIGHT ]; then
  curl -LOs https://osdn.net/dl/mplus-fonts/${MPLUS_TESTFLIGHT}.tar.xz
  tar xf ${MPLUS_TESTFLIGHT}.tar.xz
fi

# NOTE assume use of /usr/share/fonts/google-noto from Fedora package
#if [ ! -d NotoSerif ]; then
#  # from https://www.google.com/get/noto/#serif-lgc
#  curl -LOs https://noto-website-2.storage.googleapis.com/pkgs/NotoSerif-hinted.zip
#  unzip -q -d NotoSerif NotoSerif-hinted.zip
#fi

if [ ! -f fontawesome-webfont.ttf ]; then
  curl -LOs https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/fonts/fontawesome-webfont.ttf
fi  

cp ${MPLUS_TESTFLIGHT}/mplus-1mn*ttf .
cp ${MPLUS_TESTFLIGHT}/mplus-1p-regular.ttf .
# FIXME use fonts from google-noto-serif-fonts RPM
cp /usr/share/fonts/google-noto/NotoSerif-{Regular,Italic,Bold,BoldItalic}.ttf .

cd ..

# NOTE build image using command found at top of Dockerfile.fontforge
podman run --rm -t -u 0:0 --privileged \
  -e "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}" \
  -v `pwd`:/home/fontforge/scripts \
  -v `pwd`/$BUILD_DIR:/home/fontforge/scripts/build \
  -w /home/fontforge/scripts \
  localhost/fontforge:latest -script subset-fonts.pe $SOURCE_DIR build > /tmp/subset-fonts.log 2>&1

exitcode=$?

rm -f $SOURCE_DIR/*.ttf
if [ -d build ]; then
  rmdir build
fi

exit $exitcode
