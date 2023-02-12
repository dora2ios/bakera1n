## how to make rootless mode  

### (0) make
```
make
```

### (1) 1st boot
```
cd term
./checkra1n -pvEk Pongo.bin
./bakera1n_loader -p
```

### (2) run iproxy (from libimobiledevice)
```
iproxy <port>:44
```

### (3) connect to iOS device via dropbear
```
ssh root@localhost -p <port>
```

### (4) install bootstrap (iOS 15 side)  
```
cd /var/root
curl -sLOOOOO https://apt.procurs.us/bootstraps/1800/bootstrap-ssh-iphoneos-arm64.tar.zst
curl -sLOOOOO https://raw.githubusercontent.com/elihwyma/Pogo/1724d2864ca55bc598fa96bee62acad875fe5990/Pogo/Required/org.coolstar.sileonightly_2.4_iphoneos-arm64.deb

zstd -d bootstrap-ssh-iphoneos-arm64.tar.zst

mount -uw /private/preboot
mkdir /private/preboot/tempdir
tar --preserve-permissions -xkf bootstrap-ssh-iphoneos-arm64.tar -C /private/preboot/tempdir
mv -v /private/preboot/tempdir/var/jb /private/preboot/$(cat /private/preboot/active)/procursus
rm -rf /private/preboot/tempdir

ln -s /private/preboot/$(cat /private/preboot/active)/procursus /var/jb

/var/jb/prep_bootstrap.sh
/var/jb/usr/libexec/firmware

dpkg -i org.coolstar.sileonightly_2.4_iphoneos-arm64.deb > /dev/null
uicache -p /var/jb/Applications/Sileo-Nightly.app

apt-get update -o Acquire::AllowInsecureRepositories=true
apt-get dist-upgrade -y --allow-downgrades --allow-unauthenticated

rm org.coolstar.sileonightly_2.4_iphoneos-arm64.deb
rm bootstrap-ssh-iphoneos-arm64.tar
rm bootstrap-ssh-iphoneos-arm64.tar.zst
```

