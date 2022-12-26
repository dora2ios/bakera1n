# kok3shi16 (rootless)
A rootless jailbreak toolkit for (A11) iOS 16.x for developer

## dependence
- [libirecovery](https://github.com/libimobiledevice/libirecovery)  

## how to use?
You need to turn on developer mode to do this.  
```
Usage: ./kokeshi16-rootless [option]
  -h, --help			show usage
  -l, --list			show list of supported devices
  -c, --cleandfu		use cleandfu
  -d, --debug			enable debug log
```

## about specifications
it use checkm8 exploit to boot pwn recovery mode, send payload and hook jump, run fsboot, apply kernel patch using pongo-kpf. then, boot with `rootdev=md0 serial=3 wdt=-1`.  
If /var/jb/.installed_kok3si exists, it will attempt to start the jailbreak service automatically(execute `/var/jb/etc/rc.d/*`, and load daemons under `/var/jb/Library/LaunchDaemons`).    


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
