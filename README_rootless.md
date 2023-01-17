## how to make rootless mode  

### (1) 1st boot
```
./checkra1n -pvE
./bakera1n_loader -a
```

### (2) run iproxy (from libimobiledevice)
```
iproxy <port>:44
```

### (3) connect to iOS device via dropbear
```
ssh root@localhost -p <port>
```


### (stable-1) create [full] writable partition [for 32GB+ devices] (iOS side)  
```
fsutil.sh -c
```

### ~~(stable-1) create [partial] writable partition [for 16GB devices] (iOS side)~~  
*iOS 15 may cause SpringBoard hangs, dont use this mode*
*At your own risk!*  
```
fsutil.sh -p
```

### (stable-2) install rootless stuff in writable partition (iOS side)  
```
fsutil.sh -r
```


### (stable-3) check writable partition (iOS side)  
```
fsutil.sh -s
...
[+] Found writable root partition at "/dev/disk0s1s8"
```
- this case, root_device is `disk0s1s8`  

### (stable-4) rootful boot (if root_device = `disk0s1s8`)
```
./checkra1n -pvE
./bakera1n_loader -a -r disk0s1s8
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

