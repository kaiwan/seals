#!/bin/sh
# Part of the SEALs project
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# Project URL:
# https://github.com/kaiwan/seals

# (c) kaiwanTECH
# Using the "-smp n,sockets=n" QEMU options lets us emulate n processors!
# (can do this with n=2 for the ARM Cortex-A9)
#PFX=$(pwd)/staging   # change as appropriate
PFX=~/big/scratchpad/SEALS_staging

[ $# -ne 1 ] && {
  echo "
Usage: $0 opt=0|1
 0 => nographics mode
 1 => graphics mode"
  exit 1
}

# Rootfs is now a non-volatile image on an (emulated) SD card!
if [ $1 = "0" ]; then 
  qemu-system-arm -m 256 -M vexpress-a9 -kernel ${PFX}/images/zImage -drive file=${PFX}/images/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic
else
  qemu-system-arm -m 256 -M vexpress-a9 -kernel ${PFX}/images/zImage -drive file=${PFX}/images/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init"
fi

