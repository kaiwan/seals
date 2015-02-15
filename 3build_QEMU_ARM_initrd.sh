#!/bin/bash
#
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# Project URL:
# https://github.com/kaiwan/seals
#
# Ref: 
#  Kernel: 
#    http://balau82.wordpress.com/2012/03/31/compile-linux-kernel-3-2-for-arm-and-emulate-with-qemu/
# [OLD LINK]: http://balau82.wordpress.com/2010/03/22/compiling-linux-kernel-for-qemu-arm-emulator/
#  Busybox: http://balau82.wordpress.com/2010/03/27/busybox-for-arm-on-qemu/
# 
# Custom kernel + root filesystem for an "embedded" QEMU/ARM Linux system.
#
# According to the ARM platform selected, it builds a:
# a) Linux 3.1.5 (or 2.6.28.10) kernel for ARM platform Versatile PB platform, cpu arch ARM v5  -OR-
# b) Linux 3.2.11 kernel for ARM platform Versatile Express (A9) platform, cpu arch ARM v7.
#
# This version (3build), in addition to what 2build does, also:
#  - Populates the root filesystem with a fully built 'valgrind' for ARMv7.
#    This increases space usage by the initrd image by ~85 MB!
#    Note that valgrind will only work when you use the ARM v7 cpu variant.
# 
# (c) Kaiwan N Billimoria <kaiwan -at- kaiwantech -dot- com>
# (c) kaiwanTECH
# GPL v2
# 

##################### UPDATE as required
CXX=arm-none-linux-gnueabi-  # toolchain to use; expect that the PATH is setup..
#CXX=arm-linux-  # toolchain to use; expect that the PATH is setup..
###------###
CXX_LOC=/CodeSourcery/Sourcery_G++_Lite/ ### UPDATE ### on your system!
#CXX_LOC=/mnt/data_150G/CodeSourcery_toolchain ### UPDATE ### on your system!
###------###

export TOPDIR=$(pwd)
export BB_FOLDER=${TOPDIR}/busybox-1.19.3
export INSTALLDIR=${BB_FOLDER}/_install
export IMAGES_FOLDER=${TOPDIR}/images
export IMAGES_BKP_FOLDER=${TOPDIR}/images_bkp
export CONFIGS_FOLDER=${TOPDIR}/configs

#####
# Select the ARM platform (to build the kernel for). Choices:
# a. ARM Versatile PB, cpu arch v5 (older; ARM926EJ-S)
# b. ARM Versatile Express, cpu arch v7 (modern; Cortex-A9)
##

#ARM_CPU_ARCH=v5   # if arch v5, build kernel for ARM VersatilePB platform, kernel ver 3.1.5 (or 2.6.28.10)
ARM_CPU_ARCH=v7   # if arch v7, build kernel for ARM Versatile Express platform, kernel ver 3.2.11

if [ ${ARM_CPU_ARCH} = "v5" ]; then
	ARM_PLATFORM_STR="Versatile PB"
	ARM_PLATFORM=versatile
	ARM_PLATFORM_OPT=versatilepb
	KERNEL_FOLDER=${TOPDIR}/linux-3.1.5
	KERNELVER=3.1.5
elif [ ${ARM_CPU_ARCH} = "v7" ]; then
	ARM_PLATFORM_STR="Versatile Express (A9)"
	ARM_PLATFORM=vexpress
	ARM_PLATFORM_OPT=vexpress-a9
	KERNEL_FOLDER=~/DG-L3/linux-3.2.21
	KERNELVER=3.2.21
fi
#####

WIPE_PREV_KERNEL_CONFIG=y  # y/n. CAREFUL! If 'y' the kernel _will_ be rebuilt irrespective of changes
WIPE_PREV_BB_CONFIG=n      # y/n. CAREFUL! If 'y' BusyBox _will_ be rebuilt irrespective of changes

#CPU_CORES=$(find /sys/devices/system/cpu/ -type d |grep 'cpu[0-9]$' |wc -l)
CPU_CORES=$(getconf -a|grep _NPROCESSORS_ONLN|awk '{print $2}')
[ -z ${CPU_CORES} ] && CPU_CORES=2
KGDB_MODE=0  # make '1' to have qemu run w/ the '-S' switch (waits for gdb to 'connect')
#####################

source ./common.sh || {
	echo "source failed! common.sh invalid?"
	exit 1
}


build_kernel()
{
cd ${KERNEL_FOLDER} || exit 1
ShowTitle "Building kernel ver ${KERNELVER} now ..."

if [ $WIPE_PREV_KERNEL_CONFIG = "y" ]; then
	ShowTitle "Kernel config for ARM ${ARM_PLATFORM_STR} platform:"
	make ARCH=arm ${ARM_PLATFORM}_defconfig
fi

ShowTitle "[Optional] Kernel manual Configuration:"
echo "Edit the kernel config if required, Save & Exit..."
echo
echo "Recommended & Required kernel configs:
 General Setup:
      [*] Kernel .config support
      [*]   Enable access to .config through /proc/config.gz
      [*] KProbes
 Kernel Features
      [ ] Tickless System (Dynamic Ticks)                 [RECOMMENDED]
      [*] Use the ARM EABI to compile the kernel          [MANDATORY]
          [*]   Allow old ABI binaries to run with this kernel (EXPERIMENTAL) (NEW)   [MANDATORY]
 Kernel Hacking
      [*] Show timing information on printks
      [*] Debug Filesystem
      [*] Sleep inside atomic section checking
      [*] Compile the kernel with debug info           <Optional>
          [ ]   Reduce debugging information               <Turning this ON causes build to fail! ??>
      [*] Tracers  --->
          [*]   Kernel Function Tracer
          [*]     Kernel Function Graph Tracer (NEW)
          [*]   Interrupts-off Latency Tracer
          [*]   Scheduling Latency Tracer
          Branch Profiling (No branch profiling)  --->
          [ ]   Trace max stack
          [ ]   Support for tracing block IO actions
          [*]   Enable kprobes-based dynamic events (NEW)
          [*]   enable/disable ftrace tracepoints dynamically (NEW)
          [*]   Kernel function profiler
          [ ]   Perform a startup test on ftrace (NEW)
          < >   Ring buffer benchmark stress tester (NEW)
      [*] KGDB: kernel debugger  --->
          <*>   KGDB: use kgdb over the serial console (NEW)
          [ ]   KGDB: internal test suite (NEW)
          [ ]   KGDB_KDB: include kdb frontend for kgdb (NEW)
"
echo "<< A suggestion: The above help screen will disappear once the kernel menu config 
menu comes up.
So, if you'd like to, copy/paste it into an editor... >>
"
echo "[Enter] to continue..."
read
make ARCH=arm menuconfig

ShowTitle "Kernel Build:"
CPU_OPT=$((${CPU_CORES}*2))
time make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all || {
  echo "Kernel build failed! Aborting ..."
  exit 1
}

ShowTitle "Done!"
ls -l arch/arm/boot/zImage
cd ${TOPDIR}
}

#
# NOTE: The root filesystem is populated "in-tree" under:
#  ${BB_FOLDER}/_install
#
# TODO- move the rootfs out-of-tree
# 
build_rootfs()
{
cd ${BB_FOLDER} || exit 1
if [ $WIPE_PREV_BB_CONFIG = "y" ]; then
	ShowTitle "BusyBox default config:"
	make ARCH=arm CROSS_COMPILE=${CXX} defconfig

	ShowTitle "[Optional] BusyBox manual Configuration:"
	echo "Edit the BusyBox config if required, Save & Exit..."
	echo
	echo "[Enter] to continue..."
	read
	make ARCH=arm CROSS_COMPILE=${CXX} menuconfig

	ShowTitle "BusyBox Build:"
	make -j${CPU_CORES} ARCH=arm CROSS_COMPILE=${CXX} install
fi

#---------Generate other necessary pieces for the rootfs
ShowTitle "BusyBox Build: Manually generating required /etc files..."
cd ${INSTALLDIR}
MYPRJ=myprj
mkdir -p dev etc/init.d lib ${MYPRJ} proc sys tmp
chmod 1777 tmp

# /etc/inittab
cat > etc/inittab << @MYMARKER@
::sysinit:/etc/init.d/rcS
#::respawn:/sbin/getty 115200 ttyS0

::respawn:env PS1='ARM \w \$ ' /bin/sh
#::askfirst:env PS1='ARM \w \$ ' /bin/sh
#::askfirst:/bin/sh
#::askfirst:-/bin/sh

::restart:/sbin/init
::shutdown:/bin/umount -a -r
@MYMARKER@

# rcS master script
cat > etc/init.d/rcS << @MYMARKER@
echo "/etc/init.d/rcS running now ..."

/bin/mount -a
#/bin/mount

# networking
ifconfig eth0 192.168.2.100 netmask 255.255.255.0 up
# misc
# guarantee all printk's appear on console device
echo "8 4 1 7" > /proc/sys/kernel/printk

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/myprj:/valgrind
@MYMARKER@

chmod +x etc/init.d/rcS

# etc/fstab
cat > etc/fstab << @MYMARKER@
# device     directory type options
none         /proc     proc nodev,noexec
none         /sys      sysfs noexec
none         /sys/kernel/debug debugfs
@MYMARKER@
echo "Done.."

#------------- Shlibs..
ShowTitle "BusyBox Build: Manually copying across shared objects /lib files..."

ARMLIBS=${CXX_LOC}/arm-none-linux-gnueabi/libc/lib/
if [ ! -d ${ARMLIBS} ]; then
	echo "Fatal: Toolchain shared library location invalid? Aborting..."
	cd ${TOPDIR}
	exit 1
fi

echo "INSTALLDIR=$INSTALLDIR"
# safety check!
if [ -z ${INSTALLDIR} ]; then
	echo "INSTALLDIR has dangerous value of null or '/'. Aborting..."
	exit 1
fi

# just copy _all_ the shared libraries from the toolchain into the rfs/lib
cp -a ${ARMLIBS}/* ${INSTALLDIR}/lib

# /lib/modules/`uname -r` required for rmmod to function
KDIR=$(echo $KERNELVER | cut -d'-' -f2)
mkdir -p ${INSTALLDIR}/lib/modules/${KDIR}  # for 'rmmod'

#---------- Device Nodes
ShowTitle "BusyBox Build: Manually generating required Device Nodes in /dev ..."
cd ${INSTALLDIR}/dev
mknod -m 600 mem c 1 1
mknod -m 600 kmem c 1 2
mknod -m 666 null c 1 3
mknod -m 666 zero c 1 5
mknod -m 644 random c 1 8
mknod -m 644 urandom c 1 9

mknod -m 666 tty c 5 0
mknod -m 666 tty0 c 4 0
mknod -m 666 tty1 c 4 1
mknod -m 666 tty2 c 4 2
mknod -m 666 tty3 c 4 3
mknod -m 666 tty4 c 4 4
mknod -m 666 console c 5 1
mknod -m 666 ttyS0 c 4 64

mknod -m 660 ram b 1 0
mknod -m 660 loop b 7 0

mknod -m 660 hda b 3 0
mknod -m 660 sda b 8 0

ln -s /proc/self/fd fd
ln -s /proc/self/fd/0 stdin
ln -s /proc/self/fd/1 stdout
ln -s /proc/self/fd/2 stderr
#---------------------

#----------------------------------------------------------------
# To be copied into the RFS..any special cases
# strace, gdb[server] copied from buildroot build..
if [ -d ${TOPDIR}/xtras ]; then
	ShowTitle "Copying 'xtras' (goodies!) into the root filesystem..."
	cd ${TOPDIR}/xtras
	cp strace ${INSTALLDIR}/usr/bin
	cp tcpdump ${INSTALLDIR}/usr/sbin

	# for gdb on-board, we need libncurses* & libz* (for gdb v7.1)
	mkdir -p ${INSTALLDIR}/usr/lib
	cp -a libncurses* libz* ${INSTALLDIR}/usr/lib
	cp gdb* ${INSTALLDIR}/usr/bin

	# misc
	cp 0setup ${INSTALLDIR}/
	chmod +x procshow.sh
	cp common.sh procshow.sh pidshow.sh ${INSTALLDIR}/${MYPRJ}

	#-------------- Valgrind
    # Of course, we assume valgrind has been correctly cross-compiled for the ARMv7.
	VALGRIND_INSTALL=~/ARM_Balau/valgrind/install
	mkdir -p ${INSTALLDIR}/valgrind
	cp -a ${VALGRIND_INSTALL}/* ${INSTALLDIR}/valgrind/

	# 'prefix' is /home/kaiwan/ARM_Balau/valgrind/install/
	# So setup a script to move all valgrind installed files there on the RFS...
	# This script must be executed on the target (as ". valgrind_setup.sh') prior to using valgrind.
cat > ${INSTALLDIR}/valgrind_setup.sh << @MYMARKER@
	mkdir -p /home/kaiwan/ARM_Balau/valgrind/install/
	mv valgrind/* /home/kaiwan/ARM_Balau/valgrind/install/
	export PATH=/home/kaiwan/ARM_Balau/valgrind/install/bin:/bin:/sbin:/usr/bin:/usr/sbin:/myprj
@MYMARKER@
	chmod +x ${INSTALLDIR}/valgrind_setup.sh
	#---------------
fi
#----------------------------------------------------------------

cd ${TOPDIR}/
ShowTitle "Done!"
ls -l ${INSTALLDIR}/
}

generate_initrd()
{
cd ${INSTALLDIR} || exit 1

ShowTitle "Generating INITRD image (cpio format) now:"
find . | cpio -o --format=newc > ../rootfs.img
cd ..
gzip -c rootfs.img > rootfs.img.gz
#ls -l rootfs.img.gz
rm -f rootfs.img # not reqd (& very big!)
cd ${TOPDIR}
}

# fn to place final images in images/ and save imp config files as well...
save_images_configs()
{
cd ${TOPDIR}
unalias cp 2>/dev/null
cp -af ${IMAGES_FOLDER}/ ${IMAGES_BKP_FOLDER} # backup!

cp ${KERNEL_FOLDER}/arch/arm/boot/zImage ${IMAGES_FOLDER}/
cp ${BB_FOLDER}/rootfs.img* ${IMAGES_FOLDER}/
ls -lt ${IMAGES_FOLDER}/
cp ${KERNEL_FOLDER}/.config ${CONFIGS_FOLDER}/kernel_config
cp ${BB_FOLDER}/.config ${CONFIGS_FOLDER}/busybox_config
}

run_it()
{
cd ${TOPDIR} || exit 1

echo "----------------------------------------------------------------------"
echo "Build done. Press [Enter] to run QEMU-ARM-Linux system, ^C to abort..."
echo "----------------------------------------------------------------------"
read

# Run it!
if [ ${KGDB_MODE} -eq 0 ]; then
	qemu-system-arm -m 256 -M ${ARM_PLATFORM_OPT} -kernel ${IMAGES_FOLDER}/zImage -initrd ${IMAGES_FOLDER}/rootfs.img.gz -append "console=ttyAMA0 root=/dev/ram rdinit=/sbin/init" -nographic #-gdb tcp::1234 -s
else
	# KGDB/QEMU cmdline
	#  -just add the '-S' option [freeze CPU at startup (use 'c' to start execution)] to qemu cmdline
	ShowTitle "Running qmeu-system-arm in KGDB mode now!"
	echo "REMEMBER this kernel is run w/ the -s : it *waits* for a gdb client to connect to it..."
	echo
	echo "You are expected to run (in another terminal window):
$ arm-none-linux-gnueabi-gdb <path-to-ARM-built-kernel-src-tree>/vmlinux  <-- built w/ -g
...
and then have gdb connect to the target kernel using
(gdb) target remote :1234
...
"
	echo

	qemu-system-arm -M ${ARM_PLATFORM_OPT} -kernel ${IMAGES_FOLDER}/zImage -initrd ${IMAGES_FOLDER}/rootfs.img.gz -append "console=ttyAMA0 root=/dev/ram rdinit=/sbin/init" -nographic -gdb tcp::1234 -s -S
fi
}


### "main" here

check_root_AIA

# Toolchain in the PATH
# UPDATE this for your box!!
export PATH=$PATH:/root/CodeSourcery/Sourcery_G++_Lite/bin

which ${CXX}gcc > /dev/null 2>&1 || {
  echo "Cross toolchain does not seem to be valid! Path issue? Aborting..."
  exit 1
}

check_folder_AIA ${TOPDIR}
check_folder_AIA ${KERNEL_FOLDER}
check_folder_AIA ${BB_FOLDER}
check_folder_AIA ${IMAGES_FOLDER}
check_folder_AIA ${IMAGES_BKP_FOLDER}
check_folder_AIA ${CONFIGS_FOLDER}

build_kernel
build_rootfs
generate_initrd
save_images_configs
run_it

