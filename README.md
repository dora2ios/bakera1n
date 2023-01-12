# ~~kok3shi16 (rootless) with pongoOS~~
# bakera1n

A rootless/rootful jailbreak toolkit for A8 - A11 / iOS 15.0 - 16(.1.2) for *developers*


## 警告  
- このツールは概念実証ツールです。  
- このツールを悪用することや、悪用目的で使用することを固く禁じます。いかなる場合において、製作者および配布者がこれらのツールに対しての責任を負うことは一切無いものとします。  
- このツールの使用は全て自己責任であり、これらのツールをダウンロードした時点で全てあなた自身の責任となります。これに同意できない場合、ツールのダウンロード、使用を一切禁じます。  
- このツールを再配布することを禁じます。  


## warn
rootless mode (with bindfs edition) may cause bootloop.  
Also, this should never be done on anything other than a research device.  
At your own risk!  


## how to use?
You need to turn on developer mode to do this for iOS 16.  
Also, never set a passcode for A11. If you set a passcode, you will not be able to use this tool until you initialize the device.  
In other words, device security is severely compromised for the use of this tool, and it is recommended that it not be run on anything other than research devices.  


## how to make rootfull mode  
*(ios 15.0 - 16.1.2 only)*  

### warn  
*!! Never update diskev-cmds.!! *  

### 1st boot
```
./checkra1n -pvE
./bakera1n_loader -a
```

### connect to iOS device via dropbear
```
iproxy <port>:44
ssh root@localhost -p <port>
```

### create writable partition (iOS side)  
```
/fsutil.sh -c
```

### check writable partition (iOS side)  
```
/fsutil.sh -s
...
[+] Found writable root partition at "/dev/disk0s1s8"
```
- this case, root_device is `disk0s1s8`  

### rootful boot (if root_device = `disk0s1s8`)
```
./checkra1n -pvE
./bakera1n_loader -a -r disk0s1s8
```

### connect to iOS device via dropbear
```
iproxy <port>:44
ssh root@localhost -p <port>
```

### install bootstrap (iOS side)  
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

### install substitute (iOS 15.0-16.1.2) (iOS side)  
```
/binpack/usr/bin/curl -sLO https://apt.bingner.com/debs/1443.00/com.ex.substitute_2.3.1_iphoneos-arm.deb
/binpack/usr/bin/curl -sLO https://apt.bingner.com/debs/1443.00/com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb
dpkg -i *.deb
rm *.deb
/binpack/bin/launchctl reboot userspace
```

### install ellekit (iOS 16.2+) (iOS side)  
ETA: SON


## credit
binpack: procursus  
libirecovery: libimobiledevice  
checkm8 exploit: axi0mx  
checkra1n, pongo-kpf: checkra1n  
asdfugil: rootdev_module, techniques to prevent haxx.dylib from interfering with device power-off
