
.PHONY: all clean

all:
	-$(RM) -r build/
	mkdir build/
	cd PongoOS && make
	cd ramdisk && make
	cp -a PongoOS/build/checkra1n-kpf-pongo build/kpf
	cp -a ramdisk/ramdisk.dmg build/ramdisk.dmg
	cp -a binpack.dmg build/overlay.dmg
	cd build && xxd -i kpf > kpf.h
	cd build && xxd -i ramdisk.dmg > ramdisk.h
	cd build && xxd -i overlay.dmg > overlay.h
	-$(RM) -r term/kok3shi_pongoloader
	cd term && make
	
	-$(RM) -r builtin/
	-$(RM) -r kok3shi15_rootless-ssh.tar.xz
	-$(RM) -r kok3shi15_rootless-ssh.tar
	mkdir builtin/
	cp -a term/kok3shi_pongoloader builtin/kok3shi_pongoloader
	cp -a term/boot.sh builtin/boot.sh
	tar -cvf kok3shi15_rootless-ssh.tar builtin/kok3shi_pongoloader builtin/boot.sh
	xz -z9k kok3shi15_rootless-ssh.tar
	-$(RM) -r builtin/
	openssl sha256 kok3shi15_rootless-ssh.tar.xz

clean:
	-$(RM) -r build/
	cd ramdisk && make clean
	cd term && make clean
