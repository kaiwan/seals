#!/bin/bash
#
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# Project URL:
# https://github.com/kaiwan/seals
# (c) kaiwanTECH
#
# Loop Mount the QEMU ext4 fs so that one can easily update it..
# Pl ENSURE that the VM is Not running when you use this script!!
#  -the image will/might get corrupted!
#
IMG=/mnt/big/scratchpad/SEALS_staging/images/rfs.img  # @@@@@ Update as required
MNTPT=/mnt/tmp

name=$(basename $0)
[ $(id -u) -ne 0 ] && {
 echo "${name}: need to be root."
 exit 1
}
[ ! -f ${IMG} ] && {
 echo "${name}: need to be root."
 exit 1
}

echo "${name}: Rootfs image file: ${IMG}"
echo "${name}: Please wait... checking if rootfs image file above is currently in use ..."
lsof 2>/dev/null |grep ${IMG} && {
  echo "${name}: Rootfs image file \"${IMG}\" currently in use, aborting..." 
  echo " Is it being used by a QEMU instance perhaps? If so, shut it down and retry this."
  exit 1
}

echo "${name}: Okay, loop mounting rootfs image file now ..."
mount |grep -iq ${MNTPT} && {
  sync
  umount ${MNTPT}
}
mkdir -p ${MNTPT} 2>/dev/null
mount -o loop -t ext4 ${IMG} ${MNTPT} && {
 echo "${IMG} loop mounted at ${MNTPT}"
 mount |grep "${IMG}"
 echo
 echo "Update fs contents, then remember you MUST umount it ..."
 echo
 echo "ls ${MNTPT} :"
 ls ${MNTPT}
} || {
 echo "${name}: ${IMG} loop mounting failed! aborting..."
 exit 1
}
# Once done updating, just umount & run with QEMU via the build script
# (or the run-direct.sh script).
