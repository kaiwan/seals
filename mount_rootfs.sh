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
[ ! -f ${IMG} ] && {
 echo "${name}: root filesystem image file \"${IMG}\" unavailable, pl fix & rerun."
 exit 1
}
echo "${name}: Rootfs image file: ${IMG}"
echo "${name}: Please wait... checking if rootfs image file above is currently in use ..."
sudo lsof 2>/dev/null |grep ${IMG} && {
  echo "${name}: Rootfs image file \"${IMG}\" currently in use, aborting..." 
  echo " Is it being used by a QEMU instance perhaps? If so, shut it down and retry this."
  exit 1
}

echo "${name}: Okay, loop mounting rootfs image file now ..."
sudo mount |grep -iq ${MNTPT} && {
  sync
  sudo umount ${MNTPT}
}
sudo mkdir -p ${MNTPT} 2>/dev/null
sudo mount -o loop -t ext4 ${IMG} ${MNTPT} && {
 echo "${IMG} loop mounted at ${MNTPT}"
 mount |grep "${IMG}"
 echo
 echo "Update fs contents, then remember you MUST umount it ..."
 echo
 echo "ls ${MNTPT} :"
 sudo ls ${MNTPT}
} || {
 echo "${name}: ${IMG} loop mounting failed! aborting..."
 exit 1
}
# Once done updating, just umount & run with QEMU via the build script
# (or the run-direct.sh script).
