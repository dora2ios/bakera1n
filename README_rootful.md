## how to make rootfull mode  
*(ios 15.0 - 16.1.2 only)*   

### (1) 1st boot (rootless)
```
./checkra1n -pvEk Pongo.bin
./bakera1n_loader -ao
```

### (2) run iproxy (from libimobiledevice)
```
iproxy <port>:44
```

### (3) connect to iOS device via dropbear
```
ssh root@localhost -p <port>
```

### (4) create [full] writable partition [for 32GB+ devices] (iOS side)  
```
fsutil.sh -c
```

### (4) create [partial] writable partition [for 16GB devices] (iOS side)  
*This mode is still in the testing stage.*  
*If you have already created a full writable partition, skip this step.*  
*At your own risk!*  
```
fsutil.sh -p
```

### (5) install rootful stuff in writable partition (iOS side)  
```
fsutil.sh -u
```

### (6) check writable partition (iOS side)  
```
fsutil.sh -s
...
[+] Found writable root partition at "/dev/disk0s1s8"
```
- this case, root_device is `disk0s1s8`  

### (7) rootful boot (if root_device = `disk0s1s8`)
```
./checkra1n -pvEk Pongo.bin
./bakera1n_loader -au disk0s1s8
```

### (8) connect to iOS device via dropbear
```
ssh root@localhost -p <port>
```

### (9) install bootstrap (iOS side)  
```
curl -sLO https://dora2ios.github.io/ios15/bootstrap-ssh.tar
curl -sLO https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
curl -sLO https://dora2ios.github.io/ios15/deb/diskdev-cmds_697-1_iphoneos-arm.deb

tar --preserve-permissions -xvf bootstrap-ssh.tar -C /
cp -aRp /cores/binpack/bin/launchctl /bin/launchctl
/prep_bootstrap.sh
apt update
apt install org.coolstar.sileo
dpkg -i org.swift.libswift_5.0-electra2_iphoneos-arm.deb
dpkg -i diskdev-cmds_697-1_iphoneos-arm.deb
rm org.swift.libswift_5.0-electra2_iphoneos-arm.deb
rm diskdev-cmds_697-1_iphoneos-arm.deb
rm bootstrap-ssh.tar
```

### (option) install substitute (macOS/iOS side)  

### install ellekit  
ETA: SON
