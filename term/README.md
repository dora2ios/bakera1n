## bakera1n_loader  

### usage  
```
./bakera1n_loader -h
Usage: ./bakera1n_loader [-abhn] [-e <boot-args>] [-r <root_device>]
-h, --help                  : show usage
-a, --autoboot              : enable bakera1n boot mode
-n, --noBlockIO             : noBlockIO
-e, --extra-bootargs <args> : replace bootargs (default: 'rootdev=md0 serial=3')
-b, --bindfs                : use bindfs
-r, --rootful <root_device> : use rootful
```

## how to boot  

- ... for rootful

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

### create writable partition
```
/fsutil.sh -c
```

### check writable partition
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

enjoy :)  

