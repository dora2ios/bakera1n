#!/bin/sh

rm -rf binpack/
rm -rf binpack.dmg

mkdir binpack/
tar -xf binpack-iphoneos-arm64.tar -C binpack/

cp -a bash binpack/bin/bash
chmod 0755 binpack/bin/bash
chown 0:0 binpack/bin/bash
touch binpack/.installed_overlay


mkdir binpack/usr/share/bakera1n
cp -a ../ramdisk/build/fakedyld binpack/usr/share/bakera1n/fakedyld
cp -a ../ramdisk/build/haxx binpack/usr/share/bakera1n/haxx
cp -a ../ramdisk/build/haxz.dylib binpack/usr/share/bakera1n/haxz.dylib
cp -a ../ramdisk/build/loaderd binpack/usr/share/bakera1n/loaderd
cp -a ../ramdisk/build/fsutil.sh binpack/usr/bin/fsutil.sh

chmod 0755 binpack/usr/share/bakera1n/fakedyld
chmod 0755 binpack/usr/share/bakera1n/haxx
chmod 0755 binpack/usr/share/bakera1n/haxz.dylib
chmod 0755 binpack/usr/share/bakera1n/loaderd
chmod 0755 binpack/usr/bin/fsutil.sh

chown 0:0 binpack/usr/share/bakera1n/fakedyld
chown 0:0 binpack/usr/share/bakera1n/haxx
chown 0:0 binpack/usr/share/bakera1n/haxz.dylib
chown 0:0 binpack/usr/share/bakera1n/loaderd
chown 0:0 binpack/usr/bin/fsutil.sh

hdiutil create -size 7.5m -layout NONE -format ULFO -srcfolder ./binpack -fs HFS+ ./binpack.dmg
