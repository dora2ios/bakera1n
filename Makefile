
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
	
	cd build && xxd -i kpf > ../ra1npoc15/headers/kpf.h
	cd build && xxd -i ramdisk.dmg > ../ra1npoc15/headers/ramdisk.h
	cd build && xxd -i overlay.dmg > ../ra1npoc15/headers/overlay.h
	
	-$(RM) -r ra1npoc15/ra1npoc15
	cd ra1npoc15 && make
	
	#cd ra1npoc15 && rm -f headers/kpf.h
	#cd ra1npoc15 && rm -f headers/ramdisk.h
	#cd ra1npoc15 && rm -f headers/overlay.h
	
	-$(RM) -r builtin/
	-$(RM) -r bakera1n_v*.tar.xz
	-$(RM) -r bakera1n_v*.tar
	mkdir builtin/
	cp -a PongoOS/build/Pongo.bin ra1npoc15/Pongo.bin
	cp -a PongoOS/build/Pongo.bin builtin/Pongo.bin
	cp -a ra1npoc15/ra1npoc15 builtin/bakera1n_loader
	cp -a ra1npoc15/README.md builtin/README_loader.md
	cp -a README.md builtin/README.md
	cp -a README_rootful.md builtin/README_rootful.md
	cp -a README_rootless.md builtin/README_rootless.md
	tar -cvf bakera1n_v$(VERSION).tar builtin/bakera1n_loader builtin/README.md builtin/README_loader.md builtin/README_rootful.md builtin/README_rootless.md builtin/Pongo.bin
	xz -z9k bakera1n_v$(VERSION).tar
	-$(RM) -r builtin/
	openssl sha256 bakera1n_v$(VERSION).tar.xz

clean:
	-$(RM) -r build/
	cd ramdisk && make clean
	cd overlay && make clean
	cd term && make clean
