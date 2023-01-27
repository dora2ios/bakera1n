#!/cores/binpack/bin/bash

iOS=0
disk=NULL
found=0

echo '#================'
echo '#'
echo '# bakera1n fsutil.sh'
echo '#'
echo '# (c) 2023 bakera1n developeｒ' # not typo
echo '#'
echo '#====  Made by  ==='
echo '# bakera1n developeｒ' # again, NOT typo
echo '#================'


if [ $# != 1 ]; then
 echo 'usage: '$0' [-cpsu]'
 echo '   -c: create writable fs with full copy mode'
 echo '   -p: create writable fs with partial copy mode [beta]'
 echo '   -s: show location of writable fs'
 echo '   -u: install or update rootfull stuff for writable fs'
 exit
fi


if [ $1 == "-c" ] || [ $1 == "-p" ]; then
 echo "[*] Create Mode"
 ######## start ########
 
 # check ios
 if /cores/binpack/usr/bin/stat /dev/disk1s1 >/dev/null 2>&1; then
  iOS=16
  disk="/dev/disk1"
 elif /cores/binpack/usr/bin/stat /dev/disk0s1s1 >/dev/null 2>&1; then
  iOS=15
  disk="/dev/disk0s1"
 else
  echo '[-] who are you?!'
  exit
 fi
 
 # check "/"
 if /cores/binpack/usr/bin/stat /var/jb >/dev/null 2>&1; then
  echo '[-] already installed rootless bootstrap'
  exit
 fi
 
 if ! /cores/binpack/usr/bin/stat /dev/md0 >/dev/null 2>&1; then
  echo '[-] not ramdisk boot'
  exit
 fi
 
 ROOTFS_STATUS=$(/sbin/mount | grep $disk's'1 | cut -d ' ' -f1)
 if [ $ROOTFS_STATUS != $disk's'1 ]; then
 echo '[-] not no snapshot boot'
  exit
 fi
 
# check apfs
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
  echo '[*] creating writable root partition...'
  read -p "[!] really ok? (y/n): " yn
  case "$yn" in [yY]*) ;; *) echo "exit." ; exit ;; esac
  /sbin/newfs_apfs -A -D -o role=r -v Xystem $disk
  sleep 1
  for i in `seq 1 32`; do
   #echo checking $disk's'${i}
   if [[ $(/System/Library/Filesystems/apfs.fs/apfs.util -p $disk's'${i}) == 'Xystem' ]]; then
    echo '[+] Found writable root partition at "'$disk's'${i}'"'
    found=1
    break
   fi
  done
 fi

 if [ $found != 1 ]; then
  echo '[-] writable root partition is not found.'
  echo '[-] WTF!?'
  exit
 fi
 
 newroot=$disk's'${i}

 /cores/binpack/bin/mkdir /tmp/mnt0
 /cores/binpack/bin/mkdir /tmp/mnt1

 /cores/binpack/usr/bin/snaputil -s $(/cores/binpack/usr/bin/snaputil -o) / /tmp/mnt0
 /sbin/mount_apfs $newroot /tmp/mnt1

 if ! /cores/binpack/usr/bin/stat /tmp/mnt0/Applications >/dev/null 2>&1; then
  echo '[-] snapshot is not mounted correctly.'
  echo '[-] WTF!?'
  exit
 fi

 ayyy=$(/sbin/mount | grep $newroot | cut -d ' ' -f1)
 if [ $ayyy != $newroot ]; then
  echo '[-] new fs is not mounted correctly.'
  echo '[-] WTF!?'
  exit
 fi

 echo '[*] copying fs...'
 echo '[!] !!! Do not touch the device !!!!'
 
 /cores/binpack/bin/mkdir /tmp/mnt1/fs
 /cores/binpack/bin/mkdir /tmp/mnt1/fs/gen
 /cores/binpack/bin/mkdir /tmp/mnt1/fs/fake
 /cores/binpack/bin/mkdir /tmp/mnt1/fs/orig
 #/cores/binpack/bin/mkdir /tmp/mnt1/binpack
 /cores/binpack/bin/mkdir /tmp/mnt1/fake
 
  echo '[*] copying /.ba'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/.ba /tmp/mnt1/
  echo '[*] copying /.file'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/.file /tmp/mnt1/
  echo '[*] copying /.mb'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/.mb /tmp/mnt1/
  echo '[*] copying /Applications'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/Applications /tmp/mnt1/
  echo '[*] copying /Developer'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/Developer /tmp/mnt1/
  echo '[*] copying /Library'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/Library /tmp/mnt1/
  echo '[*] copying /bin'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/bin /tmp/mnt1/
  echo '[*] copying /cores'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/cores /tmp/mnt1/
  echo '[*] copying /dev'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/dev /tmp/mnt1/
  echo '[*] copying /private'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/private /tmp/mnt1/
  echo '[*] copying /sbin'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/sbin /tmp/mnt1/
  echo '[*] copying /usr'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/usr /tmp/mnt1/
  echo '[*] copying /etc'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/etc /tmp/mnt1/
  echo '[*] copying /tmp'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/tmp /tmp/mnt1/
  echo '[*] copying /var'
  /cores/binpack/bin/cp -aRp /tmp/mnt0/var /tmp/mnt1/
  if [ $1 == "-c" ]; then
   echo '[*] copying /System'
   /cores/binpack/bin/cp -aRp /tmp/mnt0/System /tmp/mnt1/
  fi
  
  if [ $1 == "-p" ]; then
   echo '[*] cleaning standalone'
   /cores/binpack/bin/rm -rf /tmp/mnt1/usr/standalone/update
   /cores/binpack/bin/mkdir /tmp/mnt1/usr/standalone/update
   
   echo '[*] copying /System'
   /cores/binpack/bin/mkdir /tmp/mnt1/System/
   /cores/binpack/bin/mkdir /tmp/mnt1/System/Library/
   
   if [ $iOS == 15 ]; then
    #/cores/binpack/bin/cp -aRp /tmp/mnt0/System/Applications /tmp/mnt1/System/
    #/cores/binpack/bin/cp -aRp /tmp/mnt0/System/Cryptexes /tmp/mnt1/System/
    /cores/binpack/bin/cp -aRp /tmp/mnt0/System/Developer /tmp/mnt1/System/
    /cores/binpack/bin/cp -aRp /tmp/mnt0/System/DriverKit /tmp/mnt1/System/
    dir="/tmp/mnt0/System/Library/*"
    for filepath in $dir; do
     if [ -d "$filepath" ]; then
      if [ "$filepath" == "/tmp/mnt0/System/Library/Frameworks" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/AccessibilityBundles" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Assistant" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Audio" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Caches" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Fonts" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Health" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/LinguisticData" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/OnBoardingBundles" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Photos" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/PreferenceBundles" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/PreinstalledAssetsV2" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/PrivateFrameworks" ]; then
       echo 'SKIP: '$filepath''
       newpath=$(echo $filepath | sed 's/\/tmp\/mnt0/\/tmp\/mnt1/g')
       /cores/binpack/bin/mkdir $newpath
      else
       echo 'do: '$filepath''
       /cores/binpack/bin/cp -aRp "$filepath" /tmp/mnt1/System/Library/
      fi
     fi
    done
   fi # iOS=15
   
   if [ $iOS == 16 ]; then
    /cores/binpack/bin/cp -aRp /tmp/mnt0/System/Applications /tmp/mnt1/System/
    /cores/binpack/bin/cp -aRp /tmp/mnt0/System/Cryptexes /tmp/mnt1/System/
    /cores/binpack/bin/cp -aRp /tmp/mnt0/System/Developer /tmp/mnt1/System/
    /cores/binpack/bin/cp -aRp /tmp/mnt0/System/DriverKit /tmp/mnt1/System/
    dir="/tmp/mnt0/System/Library/*"
    for filepath in $dir; do
     if [ -d "$filepath" ]; then
      if [ "$filepath" == "/tmp/mnt0/System/Library/Frameworks" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/AccessibilityBundles" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Assistant" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Audio" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Fonts" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Health" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/LinguisticData" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/OnBoardingBundles" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/Photos" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/PreferenceBundles" ] ||
         [ "$filepath" == "/tmp/mnt0/System/Library/PreinstalledAssetsV2" ]; then
       echo 'SKIP: '$filepath''
       newpath=$(echo $filepath | sed 's/\/tmp\/mnt0/\/tmp\/mnt1/g')
       /cores/binpack/bin/mkdir $newpath
      else
       echo 'do: '$filepath''
       /cores/binpack/bin/cp -aRp "$filepath" /tmp/mnt1/System/Library/
      fi
     fi
    done
   fi # iOS=16
   
  fi # -p
  
 
 /cores/binpack/bin/mkdir /tmp/mnt1/cores/binpack
 
 sleep 1
 
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 /sbin/umount -f /tmp/mnt0
 /sbin/umount -f /tmp/mnt1
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 echo '[+] done!?'
 ######## end ########
 exit
fi

if [ $1 == "-s" ]; then
 echo "[*] Show Mode"
 ######## start ########
 if /cores/binpack/usr/bin/stat /dev/disk1s1 >/dev/null 2>&1; then
  iOS=16
  disk="/dev/disk1"
 elif /cores/binpack/usr/bin/stat /dev/disk0s1s1 >/dev/null 2>&1; then
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
 echo "[*] Update rootfull stuff Mode"

 ######## start ########
 if /cores/binpack/usr/bin/stat /dev/disk1s1 >/dev/null 2>&1; then
  iOS=16
  disk="/dev/disk1"
 elif /cores/binpack/usr/bin/stat /dev/disk0s1s1 >/dev/null 2>&1; then
  iOS=15
  disk="/dev/disk0s1"
 else
  echo '[-] who are you?!'
  exit
 fi

 if ! /cores/binpack/usr/bin/stat /dev/md0 >/dev/null 2>&1; then
  echo '[-] not ramdisk boot'
  exit
 fi
 
 ROOTFS_STATUS=$(/sbin/mount | grep $disk's'1 | cut -d ' ' -f1)
 if [ $ROOTFS_STATUS != $disk's'1 ]; then
 echo '[-] not no snapshot boot'
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
 
 echo '[!] This will now update the writable rootfs basesystem.'
 read -p "[!] really ok? (y/n): " yn
 case "$yn" in [yY]*) ;; *) echo "exit." ; exit ;; esac
 
 newroot=$disk's'${i}

 /cores/binpack/bin/mkdir /tmp/mnt0
 /cores/binpack/bin/mkdir /tmp/mnt1

 /cores/binpack/usr/bin/snaputil -s $(/cores/binpack/usr/bin/snaputil -o) / /tmp/mnt0
 /sbin/mount_apfs $newroot /tmp/mnt1

 if ! /cores/binpack/usr/bin/stat /tmp/mnt0/Applications >/dev/null 2>&1; then
  echo '[-] snapshot is not mounted correctly.'
  echo '[-] WTF!?'
  exit
 fi

 ayyy=$(/sbin/mount | grep $newroot | cut -d ' ' -f1)
 if [ $ayyy != $newroot ]; then
  echo '[-] new fs is not mounted correctly.'
  echo '[-] WTF!?'
 fi
 
 if ! /cores/binpack/usr/bin/stat /tmp/mnt1/bin >/dev/null 2>&1; then
  echo '[-] new fs is not mounted correctly.'
  echo '[-] WTF!?'
  exit
 fi
 
 echo '[!] updating utils...'
 
 #generic payload
 /cores/binpack/bin/rm -rf /tmp/mnt1/cores/haxx
 /cores/binpack/bin/sync
 /cores/binpack/bin/cp -aRp /cores/binpack/usr/share/bakera1n/haxx /tmp/mnt1/cores/haxx
 
 #fake launchd (for give some ent)
 /cores/binpack/bin/rm -rf /tmp/mnt1/fake/loaderd
 /cores/binpack/bin/sync
 /cores/binpack/bin/cp -aRp /cores/binpack/usr/share/bakera1n/loaderd /tmp/mnt1/fake/loaderd
 
  #rootful fake dyld
 /cores/binpack/bin/rm -rf /tmp/mnt1/fs/gen/dyld
 /cores/binpack/bin/sync
 /cores/binpack/bin/cp -aRp /cores/binpack/usr/share/bakera1n/fakedyld /tmp/mnt1/fs/gen/dyld
 #rootful lib
 /cores/binpack/bin/rm -rf /tmp/mnt1/cores/haxz.dylib
 /cores/binpack/bin/rm -rf /tmp/mnt1/cores/haxx.dylib
 /cores/binpack/bin/sync
 /cores/binpack/bin/cp -aRp /cores/binpack/usr/share/bakera1n/haxz.dylib /tmp/mnt1/cores/haxz.dylib
 
 sleep 1
 
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 /sbin/umount -f /tmp/mnt0
 /sbin/umount -f /tmp/mnt1
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 /cores/binpack/bin/sync
 echo '[+] done!?'
 ######## end ########
 exit
fi

echo "[-] Invalid argument"
