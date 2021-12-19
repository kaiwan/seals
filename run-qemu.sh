#!/bin/bash
# Part of the SEALs project
# https://github.com/kaiwan/seals
# (c) kaiwanTECH
name=$(basename $0)
# Fetch the SEALs env
source ./build.config || {
	echo "${name}: ./build.config file missing or invalid? using defaults if they exist..."
	if [ -d ./images ]; then
		STG=./
	else
		echo "No ./images/ dir, aborting..."
		exit 1
	fi
}
[ -z "${STG}" -o ! -d "${STG}" ] && {
  echo "${name}: SEALS staging folder \"${STG}\" invalid, pl correct and retry..."
  echo "Tip: check/edit the build.config file"
  exit 1
}

KERN=${STG}/images/zImage
ROOTFS=${STG}/images/rfs.img
[ $# -eq 1 ] && KERN=$1
DTB=${STG}/images/vexpress-v2p-ca9.dtb

K_CMDLINE_BASE="console=ttyAMA0 rootfstype=ext4 root=/dev/mmcblk0 init=/sbin/init"
# uncomment the below line for 'debug'
#K_CMDLINE_DBG="initcall_debug ignore_loglevel debug crashkernel=16M"
K_CMDLINE="${K_CMDLINE_BASE} ${K_CMDLINE_DBG}"

RAM=512
RUNCMD="qemu-system-arm -m ${RAM} -M vexpress-a9 -kernel ${KERN} \
	-drive file=${ROOTFS},if=sd,format=raw \
	-append \"${K_CMDLINE}\" \
	-nographic -no-reboot \
	-audiodev id=none,driver=none"
[ -f ${DTB} ] && RUNCMD="${RUNCMD} -dtb ${DTB}"
echo

echo "Tips:
1. Qemu won't run properly if any other hypervisor is already running ! (like VirtualBox)!

2. after the emulated Qemu system runs and you 'halt' it (you should see the message 'reboot: System halted'), type Ctrl-a+x to exit from Qemu

Now press [Enter] to continue or ^C to abort ..."
read x

echo "${RUNCMD}"
echo
eval ${RUNCMD}
