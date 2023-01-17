## how to make rootfull mode  
*(ios 15.0 - 16.1.2 only)*  

### warn  
*!! Never update diskev-cmds.!!*  

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

### (4) create [full] writable partition [for 32GB+ devices] (iOS side)  
```
fsutil.sh -c
```

### (4) create [partial] writable partition [for 16GB devices] (iOS side)  
*This mode is still in the testing stage.*  
*If you have already created a full writable partition, skip this step.*  
*No writing to /System under this mode.*  
*iOS 15 may cause SpringBoard hangs, dont use this mode*
*At your own risk!*  
```
fsutil.sh -p
```

### (6) install rootful stuff in writable partition (iOS side)  
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
./checkra1n -pvE
./bakera1n_loader -a -u disk0s1s8
```

### (8) connect to iOS device via dropbear
```
ssh root@localhost -p <port>
```

### (9) install bootstrap (iOS side)  
```
/binpack/usr/bin/curl -sLO https://cdn.discordapp.com/attachments/1017153024768081921/1026161261077090365/bootstrap-ssh.tar
/binpack/usr/bin/curl -sLO https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
tar --preserve-permissions -xvf bootstrap-ssh.tar -C /
cp -aRp /binpack/bin/launchctl /bin/launchctl
/prep_bootstrap.sh
apt update
apt install org.coolstar.sileo
dpkg -i org.swift.libswift_5.0-electra2_iphoneos-arm.deb
rm org.swift.libswift_5.0-electra2_iphoneos-arm.deb
rm bootstrap-ssh.tar
```

### (option) install substitute (iOS 15.0-16.1.2) (iOS side)  
```
/binpack/usr/bin/curl -sLO https://apt.bingner.com/debs/1443.00/com.ex.substitute_2.3.1_iphoneos-arm.deb
/binpack/usr/bin/curl -sLO https://apt.bingner.com/debs/1443.00/com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb
dpkg -i *.deb
rm *.deb
/binpack/bin/launchctl reboot userspace
```

### install ellekit (iOS 16.2+) (iOS side)  
ETA: SON
