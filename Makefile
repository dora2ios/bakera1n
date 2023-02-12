
.PHONY: all clean

VERSION ?= 2.3.0-$(shell git rev-parse HEAD | cut -c1-8)

all:
	-$(RM) -r build/
	mkdir build/
	cd PongoOS && make
	cd ramdisk && make 'VERSIONFLAGS=-DVERSION=\"$(VERSION)\"'
	cd overlay && make
	cp -a PongoOS/build/checkra1n-kpf-pongo build/kpf
	cp -a ramdisk/ramdisk.dmg build/ramdisk.dmg
	cp -a overlay/binpack.dmg build/overlay.dmg
	cp -a PongoOS/build/Pongo.bin build/Pongo.bin
	
	cd build && xxd -i kpf > ../ra1npoc15/headers/kpf.h
	cd build && xxd -i ramdisk.dmg > ../ra1npoc15/headers/ramdisk.h
	cd build && xxd -i overlay.dmg > ../ra1npoc15/headers/overlay.h
	cd build && xxd -i Pongo.bin > ../ra1npoc15/headers/Pongo_bin.h
	
	-$(RM) -r ra1npoc15/ra1npoc15
	cd ra1npoc15 && make ra1npoc15_release
	
	#cd ra1npoc15 && rm -f headers/kpf.h
	#cd ra1npoc15 && rm -f headers/ramdisk.h
	#cd ra1npoc15 && rm -f headers/overlay.h
	
	-$(RM) -r builtin/
	-$(RM) -r bakera1n_v*.tar.xz
	-$(RM) -r bakera1n_v*.tar
	mkdir builtin/
	cp -a PongoOS/build/Pongo.bin ra1npoc15/Pongo.bin
	cp -a PongoOS/build/Pongo.bin builtin/Pongo.bin
	cp -a ra1npoc15/ra1npoc15_release_macosx builtin/bakera1n_loader
	cp -a ra1npoc15/README.md builtin/README_loader.md
	cp -a README.md builtin/README.md
	cp -a README_rootful.md builtin/README_rootful.md
	cp -a README_rootless.md builtin/README_rootless.md
	tar -cvf bakera1n_v$(VERSION).tar builtin/bakera1n_loader builtin/README.md builtin/README_loader.md builtin/README_rootful.md builtin/README_rootless.md builtin/Pongo.bin
	xz -z9k bakera1n_v$(VERSION).tar
	-$(RM) -r builtin/
	mkdir builtin/
	mkdir builtin/DEBIAN
	mkdir builtin/usr/
	mkdir builtin/usr/bin/
	cp -a ra1npoc15/ra1npoc15_release_iphoneos builtin/usr/bin/ra1npoc15
	cp -a iphoneos-arm/control builtin/DEBIAN/control
	-$(RM) builtin/.DS_Store
	-$(RM) builtin/*/.DS_Store
	-$(RM) builtin/*/*/.DS_Store
	chmod 755 builtin/usr/bin/ra1npoc15
	sudo chown 0:0 builtin/usr/
	sudo chown 0:0 builtin/usr/bin/
	sudo chown 0:0 builtin/usr/bin/ra1npoc15
	dpkg-deb --build -Zgzip builtin iphoneos-arm/
	sudo rm -rf builtin/usr/
	-$(RM) -r builtin/
	
	openssl sha256 bakera1n_v$(VERSION).tar.xz
	
clean:
	-$(RM) -r build/
	cd ramdisk && make clean
	cd overlay && make clean
	cd term && make clean
