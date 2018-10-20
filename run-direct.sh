#!/bin/sh
# Part of the SEALs project
# (c) kaiwanTECH
STG_IMG=~/scratchpad/SEALS_staging/SEALS_staging_vexpress/images #~/scratchpad/SEALS_staging/images
   # ! UPDATE the STG_IMG var for your system !

[ ! -d ${STG_IMG} ] && {
  echo "${name}: SEALS staging folder \"${STG_IMG}\" invalid, pl correct and retry..."
  exit 1
}

KERN=${STG_IMG}/zImage
ROOTFS=${STG_IMG}/rfs.img
#ROOTFS=~/scratchpad/buildroot-2017.02.3/output/images/rootfs.ext4
[ $# -eq 1 ] && KERN=$1
DTB=${STG_IMG}/vexpress-v2p-ca9.dtb

K_CMDLINE_BASE="console=ttyAMA0 rootfstype=ext4 root=/dev/mmcblk0 init=/sbin/init"
#K_CMDLINE_XTRA="initcall_debug ignore_loglevel debug crashkernel=16M"
K_CMDLINE="${K_CMDLINE_BASE} ${K_CMDLINE_XTRA}"

RAM=512
RUNCMD="qemu-system-arm -m ${RAM} -M vexpress-a9 -kernel ${KERN} \
	-drive file=${ROOTFS},if=sd,format=raw \
	-append \"${K_CMDLINE}\" \
	-nographic -no-reboot"
[ -f ${DTB} ] && RUNCMD="${RUNCMD} -dtb ${DTB}"
echo
echo "${RUNCMD}"
echo
eval ${RUNCMD}
