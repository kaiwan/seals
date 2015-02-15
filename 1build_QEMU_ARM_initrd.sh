#!/bin/bash
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# Project URL:
# https://github.com/kaiwan/seals
#
# Ref: 
#  Kernel: http://balau82.wordpress.com/2012/03/31/compile-linux-kernel-3-2-for-arm-and-emulate-with-qemu/
#  Kernel [older]:  http://balau82.wordpress.com/2010/03/22/compiling-linux-kernel-for-qemu-arm-emulator/
#  Busybox: http://balau82.wordpress.com/2010/03/27/busybox-for-arm-on-qemu/
# 
# A first, simple, script.
# Generates an ARM Linux kernel for an ARMv7 arch (specifically, the ARM Versatile Express platform), 
# well supported by QEMU.
# It generates a static busybox and does not create any device nodes..
# 
# (c) Kaiwan N Billimoria <kaiwan -at- kaiwantech -dot- com>
# (c) kaiwanTECH
# GPL v2
# 

############################################## UPDATE as required
CXX=arm-none-linux-gnueabi-  # toolchain to use; expect that the PATH is setup..

#####
# Select the ARM platform (to build the kernel for). Choices:
# a. ARM Versatile PB, cpu arch v5 (older; ARM926EJ-S)
# b. ARM Versatile Express, cpu arch v7 (modern; Cortex-A9)
##

ARM_CPU_ARCH=v5   # if arch v5, build kernel for ARM VersatilePB platform, kernel ver 3.1.5 (or 2.6.28.10)
#ARM_CPU_ARCH=v7   # if arch v7, build kernel for ARM Versatile Express platform, kernel ver 3.2.11

if [ ${ARM_CPU_ARCH} = "v5" ]; then
	ARM_PLATFORM_STR="Versatile PB"
	ARM_PLATFORM=versatile
	ARM_PLATFORM_OPT=versatilepb
	KERNEL_FOLDER=~/DG-L3/linux-3.2.21/
elif [ ${ARM_CPU_ARCH} = "v7" ]; then
	ARM_PLATFORM_STR="Versatile Express (A9)"
	ARM_PLATFORM=vexpress
	ARM_PLATFORM_OPT=vexpress-a9
	KERNEL_FOLDER=~/DG-L3/linux-3.2.21
	#KERNEL_FOLDER=./linux-3.2.11
fi
#####

WIPE_PREV_KERNEL_CONFIG=y  # y/n. CAREFUL! If 'y' the kernel _will_ be rebuilt irrespective of changes

BB_FOLDER=./busybox-1.19.3
WIPE_PREV_BB_CONFIG=y  # y/n. CAREFUL! If 'y' BusyBox _will_ be rebuilt irrespective of changes

#CPU_CORES=$(find /sys/devices/system/cpu/ -type d |grep 'cpu[0-9]$' |wc -l)
CPU_CORES=$(getconf -a|grep _NPROCESSORS_ONLN|awk '{print $2}')
[ -z ${CPU_CORES} ] && CPU_CORES=2
##############################################

source ./common.sh || {
	echo "source failed! ../common.sh invalid?"
	exit 1
}


build_kernel()
{
SDIR=$(pwd)
cd ${KERNEL_FOLDER} || exit 1
if [ $WIPE_PREV_KERNEL_CONFIG = "y" ]; then
	ShowTitle "Kernel config for ARM ${ARM_PLATFORM_STR} platform:"
	make ARCH=arm ${ARM_PLATFORM}_defconfig
fi

ShowTitle "[Optional] Kernel manual Configuration:"
echo "Edit the kernel config if required, Save & Exit..."
echo
echo "Required kernel configs:
 Kernel Features
      [*] Use the ARM EABI to compile the kernel          [MANDATORY]
          [*]   Allow old ABI binaries to run with this kernel (EXPERIMENTAL) (NEW)   [MANDATORY]
"
echo "[Enter] to continue..."
read
make ARCH=arm menuconfig

ShowTitle "Kernel Build:"
CPU_OPT=$((${CPU_CORES}*2))
time make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all

ShowTitle "Done!"
ls -l arch/arm/boot/zImage
cd ${SDIR}
}

build_rootfs()
{
SDIR=$(pwd)
cd ${BB_FOLDER} || exit 1
if [ $WIPE_PREV_BB_CONFIG = "y" ]; then
	ShowTitle "BusyBox default config:"
	make ARCH=arm CROSS_COMPILE=${CXX} defconfig
fi

ShowTitle "[Optional] BusyBox manual Configuration:"
echo "Edit the BusyBox config if required, Save & Exit..."
echo
echo "!IMPORTANT!  For this simple case, set the STATIC build option under 
 Busybox Settings --> Build Options
  [*] Build BusyBox as a static binary (no shared libs)
"
echo
echo "[Enter] to continue..."
read
make ARCH=arm CROSS_COMPILE=${CXX} menuconfig

ShowTitle "BusyBox Build:"
make -j${CPU_CORES} ARCH=arm CROSS_COMPILE=${CXX} install

#---------Generate other necessary pieces for the rootfs
ShowTitle "BusyBox Build: Manually generating required /etc files..."
cd _install
mkdir -p dev proc sys etc/init.d

## Root Filesystem Content:
## Create minimal config files under etc/ 
# /etc/inittab
cat > etc/inittab << @MYMARKER@
::sysinit:/etc/init.d/rcS
#::respawn:/sbin/getty 115200 ttyS0
::askfirst:-/bin/sh
::restart:/sbin/init
::shutdown:/bin/umount -a -r
@MYMARKER@

# rcS master script
cat > etc/init.d/rcS << @MYMARKER@
echo "/etc/init.d/rcS running now ..."
mount -t proc none /proc
mount -t sysfs none /sys
@MYMARKER@

chmod +x etc/init.d/rcS

# etc/fstab
cat > etc/fstab << @MYMARKER@
# device     directory type  options
none         /proc     proc  nodev,noexec
none         /sys      sysfs nodev,noexec
@MYMARKER@

cd ..
#---------------------

ShowTitle "Done!"
ls -l _install/

#---------------------
ShowTitle "Generating INITRD image (cpio format) now:"
cd _install
find . | cpio -o --format=newc > ../rootfs.img
cd ..
gzip -c rootfs.img > rootfs.img.gz
ls -l rootfs.img.gz
cd ${SDIR}
}

### "main" here

# Toolchain in the PATH
# UPDATE this for your box!!
#export PATH=$PATH:/mnt/big1_200G/trg/linux/DG-L3/buildroot-qemu/buildroot-2011.08/output/host/usr/bin/
#export PATH=$PATH:/mnt/data_150G/CodeSourcery_toolchain/bin
export PATH=$PATH:/root/CodeSourcery/Sourcery_G++_Lite/bin

which ${CXX}gcc > /dev/null 2>&1 || {
  echo "Cross toolchain does not seem to be valid! Path issue? Aborting..."
  exit 1
}

build_kernel
build_rootfs

echo "----------------------------------------------------------------------"
echo "Build done. Press [Enter] to run QEMU-ARM-Linux system, ^C to abort..."
echo "----------------------------------------------------------------------"
read

# Run it!
qemu-system-arm -M ${ARM_PLATFORM_OPT} -kernel ${KERNEL_FOLDER}/arch/arm/boot/zImage -initrd ${BB_FOLDER}/rootfs.img.gz -append "console=ttyAMA0 root=/dev/ram rdinit=/sbin/init" -nographic

