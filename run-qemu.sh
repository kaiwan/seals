#!/bin/bash
# Part of the SEALs project
# https://github.com/kaiwan/seals
# (c) kaiwanTECH
name=$(basename $0)
# Fetch the SEALs env
source ./build.config || {
	echo "${name}: source failed! ./build.config file missing or invalid?"
	exit 1
}

[ -z "${STG}" -o ! -d "${STG}" ] && {
  echo "${name}: SEALS staging folder \"${STG}\" invalid, pl correct and retry..."
  echo "Tip: edit the build.config file"
  exit 1
}

KERN=${STG}/images/zImage
ROOTFS=${STG}/images/rfs.img
[ $# -eq 1 ] && KERN=$1
DTB=${STG}/images/vexpress-v2p-ca9.dtb

K_CMDLINE_BASE="console=ttyAMA0 rootfstype=ext4 root=/dev/mmcblk0 init=/sbin/init"
#K_CMDLINE_DBG="initcall_debug ignore_loglevel debug crashkernel=16M"
K_CMDLINE="${K_CMDLINE_BASE} ${K_CMDLINE_DBG}"

RAM=512
RUNCMD="qemu-system-arm -m ${RAM} -M vexpress-a9 -kernel ${KERN} \
	-drive file=${ROOTFS},if=sd,format=raw \
	-append \"${K_CMDLINE}\" \
	-nographic -no-reboot"
[ -f ${DTB} ] && RUNCMD="${RUNCMD} -dtb ${DTB}"
echo

echo "Tip: after the emulated Qemu system runs and you 'halt' it, type Ctrl-a+x to exit from Qemu
Press [Enter] to continue, ^C to abort ..."
read x

echo "${RUNCMD}"
echo
eval ${RUNCMD}
