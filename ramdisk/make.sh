#!/bin/sh

VERSION_FLAG=$1

VOLUME="kok3shird"

rm -rf $VOLUME/
rm -rf ramdisk.dmg
rm -rf build/

mkdir $VOLUME/
mkdir build/

cd $VOLUME

# create fs dir
mkdir fs/
mkdir fs/gen/
mkdir fs/orig/

mkdir dev/
mkdir sbin/
mkdir usr/
mkdir usr/lib/

chown root:wheel fs/
chown root:wheel fs/gen/
chown root:wheel fs/orig/

chmod 0755 fs/
chmod 0755 fs/gen/
chmod 0755 fs/orig/

chown root:wheel dev/
chown root:wheel sbin/
chown root:wheel usr/
chown root:wheel usr/lib/

chmod 0555 dev/
chmod 0755 sbin/
chmod 0755 usr/
chmod 0755 usr/lib/

cd ..

cd src/
rm -rf dropbear.h
xxd -i dropbear.plist > dropbear.h
cd ..


# fsutil
cp -a src/fsutil.sh build/fsutil.sh
chmod 0644 build/fsutil.sh

# inject rootless dylib for launchd
xcrun -sdk iphoneos clang -arch arm64 -shared src/libjbinit/libpayload.m -framework Foundation -DDEVBUILD=1 -o haxx.dylib
strip haxx.dylib
ldid -S haxx.dylib
xxd -i haxx.dylib > haxx_dylib.h
cd src/
rm -rf haxx_dylib.h
mv -v ../haxx_dylib.h ./
cd ..
mv haxx.dylib build/haxx.dylib
chmod 0644 build/haxx.dylib

# inject rootfull dylib for launchd
xcrun -sdk iphoneos clang -arch arm64 -shared src/libjbinit/libpayload.m -framework Foundation -DROOTFULL=1 -DDEVBUILD=1 -o haxz.dylib
strip haxz.dylib
ldid -S haxz.dylib
mv haxz.dylib build/haxz.dylib
chmod 0644 build/haxz.dylib

# payload
xcrun -sdk iphoneos clang -arch arm64 src/payload/payload.m src/payload/bakera1n.m src/payload/stage4.m src/payload/sysstatuscheck.m src/payload/utils.m -o com.apple.haxx -Isrc/include/ -framework IOKit -framework CoreFoundation -framework Foundation -DDEVBUILD=1 $VERSION_FLAG
strip com.apple.haxx
ldid -Ssrc/ent2.xml com.apple.haxx
mv -v com.apple.haxx haxx
xxd -i haxx > haxx.h
cd src/
rm -rf haxx.h
mv -v ../haxx.h ./
cd ..
mv haxx build/haxx
chmod 0644 build/haxx

# fakelaunchd
cp -a src/launchd $VOLUME/sbin/launchd
ldid -Ssrc/ent.xml $VOLUME/sbin/launchd
cp -a $VOLUME/sbin/launchd build/loaderd
chown root:wheel $VOLUME/sbin/launchd
chmod 0755 $VOLUME/sbin/launchd
chmod 0644 build/loaderd

# fake dyld for rootful
xcrun -sdk iphoneos clang -e__dyld_start -Wl,-dylinker -Wl,-dylinker_install_name,/usr/lib/dyld -nostdlib -static -Wl,-fatal_warnings -Wl,-dead_strip -Wl,-Z --target=arm64-apple-ios12.0 -std=gnu17 -flto -ffreestanding -U__nonnull -nostdlibinc -fno-stack-protector src/libjbinit/dyld_generic.c src/libjbinit/printf.c src/libjbinit/dyld_utils.c -Isrc/include/ -o com.apple.dyld -DDEVBUILD=1 -DROOTFULL=1 $VERSION_FLAG
strip com.apple.dyld
ldid -S com.apple.dyld
mv com.apple.dyld build/fakedyld
chmod 0644 build/fakedyld

# fake dyld
xcrun -sdk iphoneos clang -e__dyld_start -Wl,-dylinker -Wl,-dylinker_install_name,/usr/lib/dyld -nostdlib -static -Wl,-fatal_warnings -Wl,-dead_strip -Wl,-Z --target=arm64-apple-ios12.0 -std=gnu17 -flto -ffreestanding -U__nonnull -nostdlibinc -fno-stack-protector src/libjbinit/dyld_ramdisk.c src/libjbinit/printf.c src/libjbinit/dyld_utils.c -Isrc/include/ -o com.apple.dyld -DDEVBUILD=1 $VERSION_FLAG
strip com.apple.dyld
ldid -S com.apple.dyld
# use custom dyld with dyld_hook
mv com.apple.dyld $VOLUME/fs/gen/dyld
chown root:wheel $VOLUME/fs/gen/dyld
chmod 0755 $VOLUME/fs/gen/dyld

hdiutil create -size 1m -layout NONE -format UDRW -srcfolder ./$VOLUME -fs HFS+ ./ramdisk.dmg

rm -rf $VOLUME/

rm -f src/dropbear.h
rm -f src/haxx_dylib.h
rm -f src/haxx.h
