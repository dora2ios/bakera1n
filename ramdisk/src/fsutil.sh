#!/binpack/bin/bash

iOS=0
disk=NULL
found=0

echo '#================'
echo '#'
echo '# bakera1n fsutil'
echo '#'
echo '# (c) 2023 bakera1n developeｒ' # not typo
echo '#'
echo '#====  Made by  ==='
echo '# bakera1n developeｒ' # again, NOT typo
echo '#================'

if [ $# != 1 ]; then
 echo 'usage: '$0' [-csu]'
 echo '   -c: create writable fs'
 echo '   -s: show location of writable fs'
 echo '   -u: update utils for writable fs'
 exit
fi

if [ $1 == "-c" ]; then
 echo "[*] Create Mode"
 ######## start ########
 if stat /dev/disk1s1 >/dev/null 2>&1; then
  iOS=16
  disk="/dev/disk1"
 elif stat /dev/disk0s1s1 >/dev/null 2>&1; then
  iOS=15
  disk="/dev/disk0s1"
 else
  echo '[-] who are you?!'
  exit
 fi

 for i in `seq 1 32`; do
  #echo checking $disk's'${i}
  if [[ $(/System/Library/Filesystems/apfs.fs/apfs.util -p $disk's'${i}) == 'Xystem' ]]; then
   echo '[+] Found writable root partition at "'$disk's'${i}'"'
   found=1
   exit
  fi
 done

 if [ $found != 1 ]; then
  echo '[!] writable root partition is not found.'
  echo '[*] creating writable root partition...'
  read -p "[!] really ok? (y/n): " yn
  case "$yn" in [yY]*) ;; *) echo "exit." ; exit ;; esac
  /sbin/newfs_apfs -A -D -o role=r -v Xystem $disk
 fi

 for i in `seq 1 32`; do
  #echo checking $disk's'${i}
  if [[ $(/System/Library/Filesystems/apfs.fs/apfs.util -p $disk's'${i}) == 'Xystem' ]]; then
   echo '[+] Found writable root partition at "'$disk's'${i}'"'
   found=1
   break
  fi
 done

 if [ $found != 1 ]; then
  echo '[-] writable root partition is not found.'
  echo '[-] WTF!?'
  exit
 fi
 
 newroot=$disk's'${i}

 mkdir /tmp/mnt0
 mkdir /tmp/mnt1

 /binpack/usr/bin/snaputil -s $(snaputil -o) / /tmp/mnt0
 /sbin/mount_apfs $newroot /tmp/mnt1

 if !stat /tmp/mnt0/bin >/dev/null 2>&1; then
  echo '[-] snapshot is not mounted correctly.'
  echo '[-] WTF!?'
  exit
 fi

 ayyy=$(mount | grep $newroot | cut -d ' ' -f1)
 if [ $ayyy != $newroot ]; then
  echo '[-] new fs is not mounted correctly.'
  echo '[-] WTF!?'
  exit
 fi

 echo '[*] copying fs...'
 echo '[!] !!! Do not touch the device !!!!'
 /binpack/bin/cp -aRp /tmp/mnt0/. /tmp/mnt1
 # TODO
 #/binpack/bin/cp -aRp /tmp/mnt0/.ba /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/.file /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/.mb /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/Applications /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/Developer /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/Library /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/bin /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/cores /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/dev /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/private /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/sbin /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/usr /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/etc /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/tmp /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/var /tmp/mnt1/
 #/binpack/bin/cp -aRp /tmp/mnt0/System /tmp/mnt1/

 /binpack/bin/mkdir /tmp/mnt1/fs
 /binpack/bin/mkdir /tmp/mnt1/fs/gen
 /binpack/bin/mkdir /tmp/mnt1/fs/fake
 /binpack/bin/mkdir /tmp/mnt1/fs/orig
 /binpack/bin/mkdir /tmp/mnt1/binpack
 /binpack/bin/mkdir /tmp/mnt1/fake

 #rootless lib
 /binpack/bin/cp -aRp /.haxz.dylib /tmp/mnt1/haxz.dylib

 #generic payload
 /binpack/bin/cp -aRp /haxx /tmp/mnt1/haxx

 #fake dyld
 /binpack/bin/cp -aRp /.rootfull.dyld /tmp/mnt1/fs/gen/dyld

 #fake launchd (for give some ent)
 /binpack/bin/cp -aRp /.fakelaunchd /tmp/mnt1/fake/loaderd

 sleep 1
 
 /binpack/bin/sync
 /binpack/bin/sync
 /binpack/bin/sync
 /sbin/umount -f /tmp/mnt0
 /sbin/umount -f /tmp/mnt1
 /binpack/bin/sync
 /binpack/bin/sync
 /binpack/bin/sync
 echo '[+] done!?'
 ######## end ########
 exit
fi

if [ $1 == "-s" ]; then
 echo "[*] Show Mode"
 ######## start ########
 if stat /dev/disk1s1 >/dev/null 2>&1; then
  iOS=16
  disk="/dev/disk1"
 elif stat /dev/disk0s1s1 >/dev/null 2>&1; then
  iOS=15
  disk="/dev/disk0s1"
 else
  echo '[-] who are you?!'
  exit
 fi

 for i in `seq 1 32`; do
  #echo checking $disk's'${i}
  if [[ $(/System/Library/Filesystems/apfs.fs/apfs.util -p $disk's'${i}) == 'Xystem' ]]; then
   echo '[+] Found writable root partition at "'$disk's'${i}'"'
   found=1
   exit
  fi
 done

 if [ $found != 1 ]; then
  echo '[!] writable root partition is not found.'
  exit
 fi
  exit
 fi

if [ $1 == "-u" ]; then
 echo "[*] Update Mode"
 ######## start ########
 if stat /dev/disk1s1 >/dev/null 2>&1; then
  iOS=16
  disk="/dev/disk1"
 elif stat /dev/disk0s1s1 >/dev/null 2>&1; then
  iOS=15
  disk="/dev/disk0s1"
 else
  echo '[-] who are you?!'
  exit
 fi

 for i in `seq 1 32`; do
  #echo checking $disk's'${i}
  if [[ $(/System/Library/Filesystems/apfs.fs/apfs.util -p $disk's'${i}) == 'Xystem' ]]; then
   echo '[+] Found writable root partition at "'$disk's'${i}'"'
   found=1
   break
  fi
 done

 if [ $found != 1 ]; then
  echo '[!] writable root partition is not found.'
  echo '[-] WTF!?'
  exit
 fi
 
 echo 'This will now update the writable rootfs basesystem.'
 read -p "[!] really ok? (y/n): " yn
 case "$yn" in [yY]*) ;; *) echo "exit." ; exit ;; esac
 
 newroot=$disk's'${i}

 mkdir /tmp/mnt0
 mkdir /tmp/mnt1

 /binpack/usr/bin/snaputil -s $(snaputil -o) / /tmp/mnt0
 /sbin/mount_apfs $newroot /tmp/mnt1

 if !stat /tmp/mnt0/bin >/dev/null 2>&1; then
  echo '[-] snapshot is not mounted correctly.'
  echo '[-] WTF!?'
 fi

 ayyy=$(mount | grep $newroot | cut -d ' ' -f1)
 if [ $ayyy != $newroot ]; then
  echo '[-] new fs is not mounted correctly.'
  echo '[-] WTF!?'
 fi
 
 echo '[!] updating utils...'
 #rootless lib
 /binpack/bin/rm -rf /tmp/mnt1/haxz.dylib
 /binpack/bin/sync
 /binpack/bin/cp -aRp /.haxz.dylib /tmp/mnt1/haxz.dylib

 #generic payload
 /binpack/bin/rm -rf /tmp/mnt1/haxx
 /binpack/bin/sync
 /binpack/bin/cp -aRp /haxx /tmp/mnt1/haxx

 #fake dyld
 /binpack/bin/rm -rf /tmp/mnt1/fs/gen/dyld
 /binpack/bin/sync
 /binpack/bin/cp -aRp /.rootfull.dyld /tmp/mnt1/fs/gen/dyld

 #fake launchd (for give some ent)
 /binpack/bin/rm -rf /tmp/mnt1/fake/loaderd
 /binpack/bin/sync
 /binpack/bin/cp -aRp /.fakelaunchd /tmp/mnt1/fake/loaderd

 sleep 1
 
 /binpack/bin/sync
 /binpack/bin/sync
 /binpack/bin/sync
 /sbin/umount -f /tmp/mnt0
 /sbin/umount -f /tmp/mnt1
 /binpack/bin/sync
 /binpack/bin/sync
 /binpack/bin/sync
 echo '[+] done!?'
 ######## end ########
 exit
fi

echo "[-] Invalid argument"