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

cp ${MPLUS_TESTFLIGHT}/mplus-1mn*ttf .
cp ${MPLUS_TESTFLIGHT}/mplus-1p-regular.ttf .

cd ..

podman run --rm -it --privileged \
  -e "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}" \
  -v `pwd`:/home/fontforge/scripts \
  -v `pwd`/$BUILD_DIR:/home/fontforge/scripts/build \
  -w /home/fontforge/scripts \
  localhost/fontforge:latest -script subset-fonts.pe $SOURCE_DIR build > /tmp/subset-fonts.log 2>&1

exitcode=$?

rm -f $SOURCE_DIR/*.ttf
rmdir build

exit $exitcode
