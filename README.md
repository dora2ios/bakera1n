# kok3shi16 (rootless)
A rootless jailbreak toolkit for (A11) iOS 16.x for *developers*


## 警告  
- このツールは概念実証ツールです。  
- このツールを悪用することや、悪用目的で使用することを固く禁じます。いかなる場合において、製作者および配布者がこれらのツールに対しての責任を負うことは一切無いものとします。  
- このツールの使用は全て自己責任であり、これらのツールをダウンロードした時点で全てあなた自身の責任となります。これに同意できない場合、ツールのダウンロード、使用を一切禁じます。  
- このツールを再配布することを禁じます。  

## dependence
- [libirecovery](https://github.com/libimobiledevice/libirecovery)  
```
git clone https://github.com/libimobiledevice/libirecovery.git
cd libirecovery
./autogen.sh
make
sudo make install
```


## how to use?
You need to turn on developer mode to do this.  
Also, never set a passcode. If you set a passcode, you will not be able to use this tool until you initialize the device.  
In other words, device security is severely compromised for the use of this tool, and it is recommended that it not be run on anything other than research devices.  

```
Usage: ./kokeshi16-rootless [option]
  -h, --help			show usage
  -l, --list			show list of supported devices
  -c, --cleandfu		use cleandfu
  -d, --debug			enable debug log
```


## about specifications
- It use checkm8 exploit to boot pwn recovery mode, send payload and hook jump, run fsboot, apply kernel patch using pongo-kpf. then, boot with `rootdev=md0 serial=3 wdt=-1`.  
- If `/var/jb/.installed_kok3shi` exists, it will attempt to start the jailbreak service automatically (execute `/var/jb/etc/rc.d/*`, and load daemons under `/var/jb/Library/LaunchDaemons`).    


## install procursus rootless bootstrap
- Connect the jailbroken device using kokeshi16-rootless to USB and then execute the following command on macos.  
```
git clone https://github.com/dora2-iOS/kok3shi16-rootless.git && cd kok3shi16-rootless
./deploy.sh
```


# Re-enable rootless environment after reboot
execute the following command on ios. (via SSH)  
```
#/var/jb/etc/rc.d/*
launchctl load /var/jb/Library/LaunchDaemons
uicache -a
sbreload
```


## Ensure that the package is set up automatically the next time boot
execute the following command on ios. (via SSH)  
```
touch /var/jb/.installed_kok3shi
```

## connect to SSH
```
iproxy <port>:44 &
ssh root@localhost -p <port>
```


## known issues
- Rarely panic when turning off power.  


## support for chips other than A11?
- eta son.  


## what about user support?
- no, it's for developoers.  


## credit
binpack: procursus  
libirecovery: libimobiledevice  
checkm8 exploit: axi0mx  
pongo-kpf: checkra1n  
