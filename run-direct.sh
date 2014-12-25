#!/bin/sh
[ $# -ne 1 ] && {
 echo "Usage: $0 path-to-kernel-srctree for ARM/Linux kernel"
 exit 1
}
[ ! -d $1 ] && {
 echo "$0: kernel path $1 invalid? Aborting..."
 exit 1
}
KERN=$1
qemu-system-arm -m 256 -M vexpress-a9 -kernel ${KERN}/arch/arm/boot/zImage -drive file=./images/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic
