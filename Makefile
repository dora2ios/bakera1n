
.PHONY: all clean

VERSION ?= 2.2.1-$(shell git rev-parse HEAD | cut -c1-8)

all:
	-$(RM) -r build/
	mkdir build/
	cd PongoOS && make
	cd ramdisk && make 'VERSIONFLAGS=-DVERSION=\"$(VERSION)\"'
	cd overlay && make
	cp -a PongoOS/build/checkra1n-kpf-pongo build/kpf
	cp -a ramdisk/ramdisk.dmg build/ramdisk.dmg
	cp -a overlay/binpack.dmg build/overlay.dmg
	#cd build && ../bin/lzfse -encode -v -i kpf -o kpf.lzfse
	#cd build && ../bin/lzfse -encode -v -i ramdisk.dmg -o ramdisk.dmg.lzfse
	#cd build && ../bin/lzfse -encode -v -i overlay.dmg -o overlay.dmg.lzfse
	cd build && xxd -i kpf > kpf.h
	cd build && xxd -i ramdisk.dmg > ramdisk.h
	cd build && xxd -i overlay.dmg > overlay.h
	-$(RM) -r term/bakera1n_loader
	cd term && make
	cd build && rm -f kpf.h
	cd build && rm -f ramdisk.h
	cd build && rm -f overlay.h
	
	-$(RM) -r builtin/
	-$(RM) -r bakera1n_v*.tar.xz
	-$(RM) -r bakera1n_v*.tar
	mkdir builtin/
	cp -a PongoOS/build/Pongo.bin term/Pongo.bin
	cp -a PongoOS/build/Pongo.bin builtin/Pongo.bin
	cp -a term/bakera1n_loader builtin/bakera1n_loader
	cp -a term/README.md builtin/README_loader.md
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
