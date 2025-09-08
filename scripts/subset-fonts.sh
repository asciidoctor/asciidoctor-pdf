#!/usr/bin/bash

# READ ME FIRST!
# To run this script, you must first build the podman/docker image using the command found at top of Dockerfile.fontforge.
# This script will use that image to execute the subset-fonts.pe script with fontforge in a container.
# By default, this script will use podman to run the subset script in a container.
# Prefix the script with CONTAINERIZER=docker to use docker instead.
# Additionally, you may prefix the script with IMAGE=<name-of-image> to use a different image.

# NOTE only update when fonts are being changed
export SOURCE_DATE_EPOCH=$(date -d 2025-09-08T00:00:00 +%s)

MPLUS_VERSION=TESTFLIGHT-063a
NOTO_VERSION=86b2e553c3e3e4d6614dadd1fa0a7a6dafd74552
EMOJI_VERSION=16151a2312a1f8a7d79e91789d3cfe24559d61f7
FONT_AWESOME_VERSION=4.7.0
SOURCE_DIR=fonts
BUILD_DIR=../data/fonts

mkdir -p $SOURCE_DIR
rm -f $SOURCE_DIR/*.ttf
mkdir -p $BUILD_DIR

cd $SOURCE_DIR

if [ ! -d mplus-$MPLUS_VERSION ]; then
  curl -LOs https://osdn.net/dl/mplus-fonts/mplus-$MPLUS_VERSION.tar.xz
  tar xf mplus-$MPLUS_VERSION.tar.xz
fi

if [ ! -d noto-$NOTO_VERSION ]; then
  mkdir noto-$NOTO_VERSION
  cd noto-$NOTO_VERSION
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSerif-Regular.ttf
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSerif-Bold.ttf
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSerif-Italic.ttf
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSerif-BoldItalic.ttf
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSans-Regular.ttf
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSans-Bold.ttf
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSans-Italic.ttf
  curl -LOs https://github.com/googlefonts/noto-fonts/raw/$NOTO_VERSION/hinted/NotoSans-BoldItalic.ttf
  cd ..
fi

if [ ! -d emoji-$EMOJI_VERSION ]; then
  mkdir emoji-$EMOJI_VERSION
  cd emoji-$EMOJI_VERSION
  curl -Ls -o NotoEmoji.ttf https://github.com/googlefonts/noto-emoji/raw/$EMOJI_VERSION/fonts/NotoEmoji-Regular.ttf
  cd ..
fi

if [ ! -d font-awesome-$FONT_AWESOME_VERSION ]; then
  mkdir font-awesome-$FONT_AWESOME_VERSION
  cd font-awesome-$FONT_AWESOME_VERSION
  curl -LOs https://cdnjs.cloudflare.com/ajax/libs/font-awesome/$FONT_AWESOME_VERSION/fonts/fontawesome-webfont.ttf
  cd ..
fi

cp mplus-$MPLUS_VERSION/mplus-1mn*ttf .
cp mplus-$MPLUS_VERSION/mplus-1p-regular.ttf .
cp noto-$NOTO_VERSION/*.ttf .
cp emoji-$EMOJI_VERSION/*.ttf .
cp font-awesome-$FONT_AWESOME_VERSION/*.ttf .

cd ..

if [ "$CONTAINERIZER" == "docker" ]; then
  IMAGE=${IMAGE:=fontforge:latest}
  RUN="docker run --rm -t -u $(id -u)"
else
  IMAGE=${IMAGE:=localhost/fontforge:latest}
  RUN='podman run --rm -t -u 0:0'
fi

$RUN \
  -e "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}" \
  -v `pwd`:/home/fontforge/scripts:Z \
  -v `pwd`/$BUILD_DIR:/home/fontforge/scripts/build:Z \
  -w /home/fontforge/scripts \
  $IMAGE -script subset-fonts.pe $SOURCE_DIR build > /tmp/subset-fonts.log 2>&1

exitcode=$?

rm -f $SOURCE_DIR/*.ttf
if [ -d build ]; then
  rmdir build
fi

if [ $exitcode -gt 0 ]; then
  echo 'Process did not complete successfully. See log at /tmp/subset-fonts.log for details.'
fi

exit $exitcode
