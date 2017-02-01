#!/bin/sh
# Part of the SEALs project
# (c) kaiwanTECH
STG_IMG=~/big/scratchpad/SEALS_staging/images
KERN=${STG_IMG}/zImage
ROOTFS=${STG_IMG}/rfs.img
[ $# -eq 1 ] && KERN=$1

#K_CMDLINE="console=ttyAMA0 rootfstype=ext4 root=/dev/mmcblk0 init=/sbin/init initcall_debug ignore_loglevel"
K_CMDLINE_BASE="console=ttyAMA0 rootfstype=ext4 root=/dev/mmcblk0 init=/sbin/init"
K_CMDLINE_XTRA="initcall_debug ignore_loglevel debug"
K_CMDLINE="${K_CMDLINE_BASE} ${K_CMDLINE_XTRA}"

qemu-system-arm -m 256 -M vexpress-a9 -kernel ${KERN} \
	-drive file=${ROOTFS},if=sd,format=raw \
	-append "${K_CMDLINE}" \
	-nographic
