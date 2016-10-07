#!/bin/sh
# Part of the SEALs project
# (c) kaiwanTECH
STG_IMG=~/big/scratchpad/SEALS_staging/images
KERN=${STG_IMG}/zImage
ROOTFS=${STG_IMG}/rfs.img
[ $# -eq 1 ] && KERN=$1

qemu-system-arm -m 256 -M vexpress-a9 -kernel ${KERN} -drive file=${ROOTFS},if=sd,format=raw -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic
