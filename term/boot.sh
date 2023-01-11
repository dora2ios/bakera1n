#!/bin/sh

useCustomArgs=0

usage()
{
echo 'usage: '$0' [-e <boot-args>]'
exit
}

if ! stat checkra1n >/dev/null 2>&1; then
echo 'ERROR: checkra1n not found. please put the v0.1337.0 build here.'
exit
fi

if [ $# != 0 ]; then
 if [ $# != 2 ]; then
  usage
 fi
 if [ $1 != "-e" ]; then
  usage
 else
  echo 'set custom xargs: '$2''
  useCustomArgs=1
 fi
fi

# checkra1n v0.1337.0
echo '#=========================='
./checkra1n -pvE
sleep 1
# autoboot
if [ $useCustomArgs == 0 ]; then
 ./kok3shi_pongoloader -ab
else
 ./kok3shi_pongoloader -ab -e $2
fi
