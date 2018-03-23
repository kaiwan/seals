#!/bin/bash
#
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Author and Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# kaiwan -dot- billimoria -at- gmail -dot- com
#
# Project URL:
# https://github.com/kaiwan/seals
#
#----------------------------------------------------------------------
# Important:
# To get started, pl read:
#  https://github.com/kaiwan/seals/wiki
# (and follow the links on the right panel of the Wiki page).
#----------------------------------------------------------------------
# A helper script designed to build:
# a custom kernel + root filesystem for an "embedded" QEMU/ARM Linux system.
# By default, this helper script uses the 'default config' found in the file
# 'build.config'.
# build.config, again by default, holds the configuration for building:
#  - a Linux kernel (+DTB) and root filesystem for:
#    - the ARM Versatile Express (Cortex-A9) platform (supported by Qemu).
# By tweaking build.config , you can use the SEALS project to build something else..
#----------------------------------------------------------------------
# Cmdline:
# ./build_seals.sh [-c]
#   -c : run in console mode only (no gui) [optional]
#
# Very good References (by 'Balau'): 
#  Kernel: 
#    http://balau82.wordpress.com/2012/03/31/compile-linux-kernel-3-2-for-arm-and-emulate-with-qemu/
# [OLDer LINK]: http://balau82.wordpress.com/2010/03/22/compiling-linux-kernel-for-qemu-arm-emulator/
#  Busybox: http://balau82.wordpress.com/2010/03/27/busybox-for-arm-on-qemu/
#
# (c) Kaiwan N Billimoria <kaiwan -at- kaiwantech -dot- com>
# (c) kaiwanTECH
#
# License: MIT
export name=$(basename $0)

#############################
# ${BUILD_CONFIG_FILE} : a configuration script that asks the user for and sets up
# folder locations, toolchain PATH, any other configs as required.
#############################
export BUILD_CONFIG_FILE=./build.config
source ${BUILD_CONFIG_FILE} || {
	echo "${name}: source failed! ${BUILD_CONFIG_FILE} missing or invalid?"
	exit 1
}
source ./common.sh || {
	echo "${name}: source failed! ./common.sh missing or invalid?"
	exit 1
}
color_reset

### "Globals"
export PRJ_TITLE="SEALS: Simple Embedded ARM Linux System"

# Message strings
export MSG_GIVE_PSWD_IF_REQD="If asked, please enter password"
export MSG_EXITING="
${name}: all done, exiting.
Thank you for using SEALS! We hope you like it.
There is much scope for improvement of course; would love to hear your feedback,
ideas, and contribution!
Please visit :
https://github.com/kaiwan/seals ."

STEPS=5
export CPU_CORES=$(getconf -a|grep _NPROCESSORS_ONLN|awk '{print $2}')
[ -z "${CPU_CORES}" ] && CPU_CORES=2

# Device Tree Blob (DTB) location
export DTB_BLOB_LOC=${KERNEL_FOLDER}/arch/arm/boot/dts/${DTB_BLOB} # gen within kernel src tree

# Signals
trap 'wecho "User Abort. ${MSG_EXITING}" ; dumpstack ; [ ${COLOR} -eq 1 ] && color_reset ; exit 2' HUP INT QUIT

##-------------------- Functions Start --------------------------------

#------------------ b u i l d _ k e r n e l ---------------------------
build_kernel()
{
 report_progress
cd ${KERNEL_FOLDER} || exit 1
ShowTitle "KERNEL: Configure and Build [kernel ver ${KERNELVER}] now ..."

if [ ${WIPE_KERNEL_CONFIG} -eq 1 ]; then
	ShowTitle "Setting default kernel config for ARM ${ARM_PLATFORM_STR} platform:"
	make ARCH=arm ${ARM_PLATFORM}_defconfig || {
	   FatalError "Kernel config for ARM ${ARM_PLATFORM_STR} platform failed.."
	}
fi

aecho "[Optional] Kernel Manual Configuration:
Edit the kernel config if required, Save & Exit...
 Tip: you can browse notes on this here: doc/kernel_config.txt"
Prompt ""

USE_QT=n   # make 'y' to use a GUI Qt configure environment
           #  if 'y', you'll require the Qt runtime installed..
if [ ${USE_QT} = "y" ]; then
	make ARCH=arm xconfig || {
	  FatalError "make xconfig failed.."
	}
else
	make ARCH=arm menuconfig || {
	  FatalError "make menuconfig failed.."
	}
fi

ShowTitle "Kernel Build:"

#iecho "--- # detected CPU cores is ${CPU_CORES}" ; read
CPU_OPT=$((${CPU_CORES}*2))

#Prompt
# make all => zImage, modules, dtbs (device-tree-blobs), ... - all will be built!
aecho "Doing: make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all"
time make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all || {
  FatalError "Kernel build failed! Aborting ..."
}

[ ! -f arch/arm/boot/zImage ] && {
  FatalError "Kernel build problem? image file zImage not existing!?? Aborting..."
}
ls -lh arch/arm/boot/zImage
cp -u ${KERNEL_FOLDER}/arch/arm/boot/zImage ${IMAGES_FOLDER}/
aecho "... and done."
cd ${TOPDIR}
} # end build_kernel()

#--------------- b u i l d _ c o p y _ b u s y b o x ------------------
build_copy_busybox()
{
 report_progress
cd ${BB_FOLDER} || exit 1

ShowTitle "BUSYBOX: Configure and Build Busybox now ... [$(basename ${BB_FOLDER})]"
iecho " [sanity chk: ROOTFS=${ROOTFS}]"
# safety check!
if [ -z "${ROOTFS}" ]; then
	FatalError "SEALS: ROOTFS has dangerous value of null or '/'. Aborting..."
fi

if [ ${WIPE_BUSYBOX_CONFIG} -eq 1 ]; then
	ShowTitle "BusyBox default config:"
	make ARCH=arm CROSS_COMPILE=${CXX} defconfig
fi

aecho "Edit the BusyBox config if required, Save & Exit..."
Prompt " " ${MSG_EXITING}

USE_QT=n   # make 'y' to use a GUI Qt configure environment
if [ ${USE_QT} = "y" ]; then
	make ARCH=arm CROSS_COMPILE=${CXX} xconfig
else
	make ARCH=arm CROSS_COMPILE=${CXX} menuconfig
fi

ShowTitle "BusyBox Build:"
make -j${CPU_CORES} ARCH=arm CROSS_COMPILE=${CXX} install || {
  FatalError "Building and/or Installing busybox failed!"
}

mysudo "SEALS Build:Step 1 of ${STEPS}: Copying of required busybox files. ${MSG_GIVE_PSWD_IF_REQD}" \
 cp -af ${BB_FOLDER}/_install/* ${ROOTFS}/ || {
  FatalError "Copying required folders from busybox _install/ failed! 
 [Tip: Ensure busybox has been successfully built]. Aborting..."
}
aecho "SEALS Build: busybox files copied across successfully ..."
} # end build_copy_busybox()

#---------- s e t u p _ e t c _ i n _ r o o t f s ---------------------
setup_etc_in_rootfs()
{
 report_progress
aecho "SEALS Build: Manually generating required SEALS rootfs /etc files ..."
cd ${ROOTFS}
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
echo "SEALS: /etc/init.d/rcS running now ..."
/bin/mount -a
# remount / as rw; requires CONFIG_LBDAF !
/bin/mount -o remount,rw /

# networking
ifconfig eth0 192.168.2.100 netmask 255.255.255.0 up

# Misc
if [ $(id -u) -eq 0 ]; then
   # guarantee all printk's appear on console device
   echo "7 4 1 7" > /proc/sys/kernel/printk
   # better core-file pathname
   echo "core_%h_%E_%p_%s_%u" > /proc/sys/kernel/core_pattern
   # Kexec (for kdump/crashkernel facility)
   if [ -x /kx.sh ]; then
       /kx.sh
   fi
fi
@MYMARKER@

chmod +x etc/init.d/rcS

# etc/fstab
# Ensure that procfs and sysfs are mounted.
cat > etc/fstab << @MYMARKER@
# device     directory type options
none         /proc     proc nodev,noexec
none         /sys      sysfs noexec
none         /sys/kernel/debug debugfs
@MYMARKER@
} # end setup_etc_in_rootfs

#-------- s e t u p _ l i b _ i n _ r o o t f s -----------------------
setup_lib_in_rootfs()
{
 report_progress
aecho "SEALS Build: copying across shared objects, etc to SEALS /lib /sbin /usr ..."

# TODO / FIXME !! lib loc ??
#  - /usr/arm-none-eabi/lib/ i.e. /usr/${CXX}/lib ?
# old:
# ARMLIBS=${CXX_LOC}/arm-none-linux-gnueabi/libc
GCC_SYSROOT=$(${CXX}gcc --print-sysroot)
SYSROOT=${GCC_SYSROOT}/  #lib/
if [ ! -d ${SYSROOT} ]; then
	cd ${TOPDIR}
	FatalError "Toolchain shared library locations invalid? Aborting..."
fi

# Quick solution: just copy _all_ the shared libraries, etc from the toolchain
# into the rfs/lib.
mysudo "SEALS Build:Step 2 of ${STEPS}: [SEALS rootfs]:setup of library objects. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/lib/* ${ROOTFS}/lib || {
   FatalError "Copying required libs [/lib] from toolchain failed!"
}
mysudo "SEALS Build:Step 3 of ${STEPS}: [SEALS rootfs]:setup of /sbin. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/sbin/* ${ROOTFS}/sbin || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
}
mysudo "SEALS Build:Step 4 of ${STEPS}: [SEALS rootfs]:setup of /usr. ${MSG_GIVE_PSWD_IF_REQD}" \
  cp -a ${SYSROOT}/usr/* ${ROOTFS}/usr || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
}
  # RELOOK: 
  # $ ls rootfs/usr/
  # bin/  include/  lib/  libexec/  sbin/  share/
  # $ 
  # usr/include - not really required?

# /lib/modules/`uname -r` required for rmmod to function
# FIXME - when kernel ver has '-extra' it doesn't take it into account..
local KDIR=$(echo ${KERNELVER} | cut -d'-' -f2)
# for 'rmmod'
mkdir -p ${ROOTFS}/lib/modules/${KDIR} || FatalError "rmmod setup failure!"
} # end setup_lib_in_rootfs

#------ s e t u p _ d e v _ i n _ r o o t f s -------------------------
setup_dev_in_rootfs()
{
 report_progress
#---------- Device Nodes [static only]
aecho "SEALS Build: Manually generating required Device Nodes in /dev ..."
cd ${ROOTFS}/dev

cat > mkdevtmp.sh << @MYMARKER@
#!/bin/sh
rm -f *

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
mknod -m 660 fb0 c 29 0

mknod -m 660 ram b 1 0
mknod -m 660 loop b 7 0
mknod -m 640 mmcblk0 b 179 0

mknod -m 660 hda b 3 0
mknod -m 660 sda b 8 0

# FIXME / TODO :: FAILS
## recommended slinks
#ln -s /proc/self/fd fd
#ln -s /proc/self/fd/0 stdin
#ln -s /proc/self/fd/1 stdout
#ln -s /proc/self/fd/2 stderr
@MYMARKER@

chmod u+x ${ROOTFS}/dev/mkdevtmp.sh
mysudo "SEALS Build:Step 5 of ${STEPS}: [SEALS rootfs]:setup of device nodes. ${MSG_GIVE_PSWD_IF_REQD}" \
  ${ROOTFS}/dev/mkdevtmp.sh || {
   rm -f mkdevtmp.sh
   FatalError "Setup of device nodes failed!"
}
rm -f mkdevtmp.sh
} # end setup_dev_in_rootfs

#---------- r o o t f s _ x t r a s -----------------------------------
rootfs_xtras()
{
 report_progress
# To be copied into the RFS..any special cases
# strace, tcpdump, gdb[server], misc scripts (strace, gdb copied from buildroot build)
if [ -d ${TOPDIR}/xtras ]; then
	aecho "SEALS Build: Copying 'xtras' (goodies!) into the root filesystem..."
	cd ${TOPDIR}/xtras

	[ -f strace ] && cp strace ${ROOTFS}/usr/bin
	[ -f tcpdump ] && cp tcpdump ${ROOTFS}/usr/sbin

	# for gdb on-board, we need libncurses* & libz* (for gdb v7.1)
	mkdir -p ${ROOTFS}/usr/lib
	cp -a libncurses* libz* ${ROOTFS}/usr/lib
	[ -f gdb ] && cp gdb ${ROOTFS}/usr/bin

	# misc
	[ -f 0setup ] && cp 0setup ${ROOTFS}/
	[ -f procshow.sh ] && chmod +x procshow.sh
	#cp common.sh procshow.sh pidshow.sh ${ROOTFS}/${MYPRJ}

	# useful for k debug stuff
	cp ${KERNEL_FOLDER}/System.map ${ROOTFS}/
fi
} # end rootfs_xtras

#------------------ b u i l d _ r o o t f s ---------------------------
#
# NOTE: The root filesystem is now populated in the ${ROOTFS} folder under ${TOPDIR}
#
build_rootfs()
{
 report_progress
# First reset the 'rootfs' staging area so that regular user can update
mysudo "SEALS Build: reset SEALS root fs. ${MSG_GIVE_PSWD_IF_REQD}" \
 chown -R ${LOGNAME}:${LOGNAME} ${ROOTFS}/*

#---------Generate necessary pieces for the rootfs
build_copy_busybox
setup_etc_in_rootfs
setup_lib_in_rootfs
setup_dev_in_rootfs
rootfs_xtras

mysudo "SEALS Build: enable final setup of SEALS root fs. ${MSG_GIVE_PSWD_IF_REQD}" \
  chown -R root:root ${ROOTFS}/* || {
   FatalError "SEALS Build: chown on rootfs/ failed!"
}

cd ${TOPDIR}/
ShowTitle "Done!"
ls -l ${ROOTFS}/
local RFS_ACTUAL_SZ_MB=$(du -ms ${ROOTFS}/ |awk '{print $1}')
aecho "SEALS root fs: actual size = ${RFS_ACTUAL_SZ_MB} MB"
} # end build_rootfs()

#------- g e n e r a t e _ r o o t f s _ i m g _ e x t 4 --------------
generate_rootfs_img_ext4()
{
 report_progress
cd ${ROOTFS} || exit 1

ShowTitle "SEALS ROOT FS: Generating ext4 image for root fs now:"

# RFS should be the final one ie the one in images/
local RFS=${IMAGES_FOLDER}/rfs.img
local MNTPT=/mnt/tmp
# Size of the rootfs 'file' is in the build.config file
local COUNT=$((${RFS_SZ_MB}*256))  # for given blocksize (bs) of 4096

[ ! -d ${MNTPT} ] && {
  mysudo "SEALS Build: root fs image generation: enable mount dir creation. ${MSG_GIVE_PSWD_IF_REQD}" \
   mkdir -p ${MNTPT}
}
# If config option RFS_FORCE_REBUILD is set -OR- the RootFS file does not exist,
# create from scratch. If it does exist, just loop mount and update.
if [ ${RFS_FORCE_REBUILD} -eq 1 -o ! -f ${RFS} ]; then
  aecho "SEALS Build: *** Re-creating raw RFS image file now *** [dd, mkfs.ext4]"
  dd if=/dev/zero of=${RFS} bs=4096 count=${COUNT}
  mysudo "SEALS Build: root fs image generation: enable mkfs. ${MSG_GIVE_PSWD_IF_REQD}" \
   mkfs.ext4 -F -L qemu_rootfs_SEALS ${RFS} || FatalError "mkfs failed!"
fi

# Keep FORCE_RECREATE_RFS to 0 by default!!
# Alter at your Own Risk!!
local FORCE_RECREATE_RFS=0

sync
mysudo "SEALS Build: root fs image generation: enable umount. ${MSG_GIVE_PSWD_IF_REQD}" \
 umount ${MNTPT} 2> /dev/null
mysudo "SEALS Build: root fs image generation: enable mount. ${MSG_GIVE_PSWD_IF_REQD}" \
 mount -o loop ${RFS} ${MNTPT} || {
  wecho "### $name: !WARNING! Loop mounting rootfs image file Failed! ###"
  if [ ${FORCE_RECREATE_RFS} -eq 0 ]; then
    aecho "-- Aborting this function! --"
	aecho "To *force* root filesystem creation by deleting current RFS, set"
	aecho "the FORCE_RECREATE_RFS in the script to 1."
	return
  else
    wecho "
### $name: !WARNING! FORCE_RECREATE_RFS flag is non-zero! Now *deleting* current RFS image and re-creating it...
"
    rm -f ${RFS} 2>/dev/null
    #dd if=/dev/zero of=${RFS} bs=4096 count=16384
    dd if=/dev/zero of=${RFS} bs=4096 count=${COUNT}
    mysudo "SEALS Build: root fs image generation: enable mkfs (in force_recreate_rfs). ${MSG_GIVE_PSWD_IF_REQD}" \
     mkfs.ext4 -F -L qemu_rootfs_SEALS ${RFS} || exit 1
    mysudo "SEALS Build: root fs image generation: enable mount (in force_recreate_rfs). ${MSG_GIVE_PSWD_IF_REQD}" \
     mount -o loop ${RFS} ${MNTPT} || {
	  FatalError " !!! The loop mount RFS failed Again !!! Wow. Too bad. See ya :-/"
	}
  fi
 }

aecho " Now copying across rootfs data to ${RFS} ..."
mysudo "SEALS Build: root fs image generation: enable copying into SEALS root fs image. ${MSG_GIVE_PSWD_IF_REQD}" \
 cp -au ${ROOTFS}/* ${MNTPT}
mysudo "SEALS Build: root fs image generation: enable unmount. ${MSG_GIVE_PSWD_IF_REQD}" \
 umount ${MNTPT}
sync
ls -lh ${RFS}
aecho "... and done."
cd ${TOPDIR}
} # end generate_rootfs_img_ext4()

#-------- s a v e _ i m a g e s _ c o n f i g s -----------------------
# fn to place final images in images/ and save imp config files as well...
save_images_configs()
{
 report_progress
ShowTitle "BACKUP: kernel, busybox images and config files now (as necessary) ..."
cd ${TOPDIR}
unalias cp 2>/dev/null
cp -afu ${IMAGES_FOLDER}/ ${IMAGES_BKP_FOLDER} # backup!
cp -u ${KERNEL_FOLDER}/arch/arm/boot/zImage ${IMAGES_FOLDER}/
[ -f ${DTB_BLOB_LOC} ] && cp -u ${DTB_BLOB_LOC} ${IMAGES_FOLDER}/
cp ${KERNEL_FOLDER}/.config ${CONFIGS_FOLDER}/kernel_config
cp ${BB_FOLDER}/.config ${CONFIGS_FOLDER}/busybox_config
aecho " ... and done."
} # end save_images_configs()

#-------------- r u n _ q e m u _ S E A L S ---------------------------
run_qemu_SEALS()
{
 report_progress
cd ${TOPDIR} || exit 1

if [ ${SMP_EMU_MODE} -eq 1 ]; then
    # Using the "-smp n,sockets=n" QEMU options lets us emulate n processors!
    # (can do this with n=2 for the ARM Cortex-A9)
     SMP_EMU="-smp 2,sockets=2"
fi

ShowTitle "
RUN: Running qemu-system-arm now ..."
local RUNCMD="qemu-system-arm -m ${SEALS_RAM} -M ${ARM_PLATFORM_OPT} ${SMP_EMU} -kernel ${IMAGES_FOLDER}/zImage -drive file=${IMAGES_FOLDER}/rfs.img,if=sd,format=raw -append \"${SEALS_K_CMDLINE}\" -nographic -no-reboot"
[ -f ${DTB_BLOB_LOC} ] && RUNCMD="${RUNCMD} -dtb ${DTB_BLOB_LOC}"

# Run it!
if [ ${KGDB_MODE} -eq 1 ]; then
	# KGDB/QEMU cmdline
	ShowTitle "Running qemu-system-arm in KGDB mode now ..."
	RUNCMD="${RUNCMD} -s -S"
	# qemu-system-xxx(1) :
	#  -S  Do not start CPU at startup (you must type 'c' in the monitor).
	#  -s  Shorthand for -gdb tcp::1234, i.e. open a gdbserver on TCP port 1234.
	aecho "
@@@@@@@@@@@@ NOTE NOTE NOTE @@@@@@@@@@@@
REMEMBER this qemu instance is run w/ the -S : it *waits* for a gdb client to connect to it...

You are expected to run (in another terminal window):
$ ${CXX}gdb <path-to-ARM-built-kernel-src-tree>/vmlinux  <-- built w/ -g
...
and then have gdb connect to the target kernel using
(gdb) target remote :1234
...
@@@@@@@@@@@@ NOTE NOTE NOTE @@@@@@@@@@@@"
fi

aecho "${RUNCMD}
"
Prompt "Ok?"
eval ${RUNCMD}

aecho "
... and done."
} # end run_qemu_SEALS()

#------ s e a l s _ m e n u _ c o n s o l e m o d e -------------------
seals_menu_consolemode()
{
 report_progress
becho "SEALS :: Console Menu
"

get_yn_reply "1. Build Linux kernel? : " y
[ $? -eq 0 ] && BUILD_KERNEL=1
get_yn_reply " a) Wipe Linux kernel current configuration clean? : " n
[ $? -eq 0 ] && WIPE_KERNEL_CONFIG=1
get_yn_reply "2. Build Root Filesystem? : " y
[ $? -eq 0 ] && BUILD_ROOTFS=1
get_yn_reply " a) Wipe Busybox current configuration clean? [y/n] : " n
[ $? -eq 0 ] && WIPE_BUSYBOX_CONFIG=1
get_yn_reply " b) Generate Root Filesystem ext4 image? [y/n] : " y
[ $? -eq 0 ] && GEN_EXT4_ROOTFS_IMAGE=1
get_yn_reply "3. Backup kernel & busybox images & configs? [y/n] : " y
[ $? -eq 0 ] && SAVE_BACKUP_IMG_CONFIGS=1
get_yn_reply "4. Run emulated system with Qemu? [y/n] : " y
[ $? -eq 0 ] && RUN_QEMU=1

} # end seals_menu_consolemode()

display_current_config()
{
 report_progress
  echo -n " Build kernel                          :: "
  [ ${BUILD_KERNEL} -eq 1 ] && {
	fg_green ; echo "Yes" ; color_reset
  } || {
	fg_red ; echo " No" ; color_reset
  }
  echo -n "  Wipe kernel config clean             :: "
  [ ${WIPE_KERNEL_CONFIG} -eq 1 ] && {
	fg_green ; echo "Yes" ; color_reset
  } || {
	fg_red ; echo " No" ; color_reset
  }
  echo -n " Build Root Filesystem                 :: "
  [ ${BUILD_ROOTFS} -eq 1 ] && {
	fg_green ; echo "Yes" ; color_reset
  } || {
	fg_red ; echo " No" ; color_reset
  }
  echo -n "  Wipe busybox config clean            :: "
  [ ${WIPE_BUSYBOX_CONFIG} -eq 1 ] && {
	fg_green ; echo "Yes" ; color_reset
  } || {
	fg_red ; echo " No" ; color_reset
  }
  echo -n " Generate rootfs ext4 image            :: "
  [ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && {
	fg_green ; echo "Yes" ; color_reset
  } || {
	fg_red ; echo " No" ; color_reset
  }
  echo -n " Backup kernel & rootfs images/configs :: "
  [ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && {
	fg_green ; echo "Yes" ; color_reset
  } || {
	fg_red ; echo " No" ; color_reset
  }
  echo -n " Run the Qemu emulator                 :: "
  [ ${RUN_QEMU} -eq 1 ] && {
	fg_green ; echo "Yes" ; color_reset
  } || {
	fg_red ; echo " No" ; color_reset
  }
}

#---------- c o n f i g _ s e t u p -----------------------------------
# config_setup
# Based on values in the build.config file,
# display the current configurables, and,
# allow the end-user to _change_ what is done by the script now.
# The change applies ONLY for this run, i.e., it is volatile and NOT
# written into the build.config file.
# Parameters:
# -none-
config_setup()
{
 local msg1=""
 local gccver=$(${CXX}gcc --version |head -n1 |cut -f2- -d" ")

 report_progress

 msg1="
Config file : ${BUILD_CONFIG_FILE}   [edit it to change any settings shown below]
Config name : ${CONFIG_NAME_STR}

Toolchain prefix : ${CXX}
Toolchain version: ${gccver}
Staging folder   : ${STG}

ARM Platform : ${ARM_PLATFORM_STR}
Platform RAM : ${SEALS_RAM} MB

RootFS force rebuild : ${RFS_FORCE_REBUILD}
RootFS size  : ${RFS_SZ_MB} MB [note: new size applied only on 'RootFS force rebuild']

Linux kernel to use : ${KERNELVER}
Linux kernel codebase location : ${KERNEL_FOLDER}
Kernel command-line : \"${SEALS_K_CMDLINE}\"

Busybox: Busybox to use: ${BB_VER} | Busybox location: ${BB_FOLDER}

Qemu: KGDB mode: ${KGDB_MODE} | SMP mode: ${SMP_EMU_MODE}

Diplay:
 Terminal Colors mode: ${COLOR} | DEBUG mode: ${DEBUG} | VERBOSE mode: ${VERBOSE_MSG}
Log file            : ${LOGFILE_COMMON}"

local msg1_2="
-------------------------------------------------------------
To change any of the above configs, abort now and edit the
config file: ${BUILD_CONFIG_FILE}
-------------------------------------------------------------- "

 # Same message text for the yad GUI display - font attributes are added on...
 # !NOTE!   !Keep them - msg1 and msg1_yad - in SYNC!
 local msg1_yad="<b><i><span foreground='Crimson'>\
SEALS Config :: Please Review Carefully\
</span></i></b>
<span foreground='blue'>
Config file : ${BUILD_CONFIG_FILE}\
      <span foreground='red'><i>[edit it to change any settings shown below]</i></span>
Config name : ${CONFIG_NAME_STR}\
</span>
Staging folder   : ${STG}
<span foreground='blue'>\
Toolchain prefix : ${CXX}
Toolchain version: ${gccver}
</span>\
ARM Platform : ${ARM_PLATFORM_STR}
Platform RAM : ${SEALS_RAM} MB
<span foreground='blue'>\
RootFS force rebuild : ${RFS_FORCE_REBUILD}
RootFS size  : ${RFS_SZ_MB} MB     [note: new size applied only on 'RootFS force rebuild']
</span>\
Linux kernel to use : ${KERNELVER}
Linux kernel codebase location : ${KERNEL_FOLDER}
Kernel command-line : \"${SEALS_K_CMDLINE}\"
<span foreground='blue'>\
Busybox: Busybox to use: ${BB_VER} | Busybox location: ${BB_FOLDER}
</span>\
Qemu: KGDB mode: ${KGDB_MODE} | SMP mode: ${SMP_EMU_MODE}
<span foreground='blue'>\
Diplay:
 Terminal Colors mode: ${COLOR} | DEBUG mode: ${DEBUG} | VERBOSE mode: ${VERBOSE_MSG}
</span>\
Log file            : ${LOGFILE_COMMON}
<span foreground='red'><b>
To change any of these, please abort now, edit the config file ${BUILD_CONFIG_FILE} \
appropriately, and rerun.\
</b></span>
<span foreground='crimson'><i>\
Press 'Yes' (or Enter) to proceed, 'No' (or Esc) to abort
</i></span>"


 [ ${GUI_MODE} -eq 0 ] && {
        becho "
[[ SEALS Config :: Please Review Carefully ]]"
	iecho "${msg1}"
	aecho "${msg1_2}"
	Prompt ""
 } || {
   #wecho "WIDTHxHT=$CAL_WIDTH x ${CAL_HT} "
   yad --image "dialog-question" --title "${PRJ_TITLE}" --center \
         --button=gtk-yes:0 --button=gtk-no:1 \
	 --width=${CAL_WIDTH} --height=${CAL_HT} \
	 --text "${msg1_yad}"
   [ $? -ne 0 ] && {
     aecho "Aborting. Edit the config file ${BUILD_CONFIG_FILE} as required and re-run."
     exit 1
   }
 }

 local s1="Build kernel?                                    N"
 [ ${BUILD_KERNEL} -eq 1 ] && s1="Build kernel?                                    Y"
 local s1_2=" Wipe kernel config?                             N"
 [ ${WIPE_KERNEL_CONFIG} -eq 1 ] && s1_2=" Wipe kernel config?                     Y"
 local s2="Build root filesystem?                           N"
 [ ${BUILD_ROOTFS} -eq 1 ] && s2="Build root filesystem?                           Y"
 local s2_2=" Wipe busybox config?                            N"
 [ ${WIPE_BUSYBOX_CONFIG} -eq 1 ] && s2_2=" Wipe busybox config?                   Y"
 local s3="Generate ext4 rootfs image?                      N"
 [ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && s3="Generate ext4 rootfs image?             Y"
 local s4="Backup kernel/busybox images and config files?   N"
 [ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && s4="Save/Backup kernel/busybox images and config files?   Y"
 local s5="Run QEMU ARM emulator?                           N"
 [ ${RUN_QEMU} -eq 1 ] && s5="Run QEMU ARM emulator?                         Y"

# msg2="--------------------- Preset Script Build Options ----------------------
#${s1}
#${s1_2}
#${s2}
#${s2_2}
#${s3}
#${s4}
#${s5}
#"
# iecho "${msg2}"

[ ${GUI_MODE} -eq 1 ] && {
 #--- YAD
 local disp_kernel="FALSE"
 [ ${BUILD_KERNEL} -eq 1 ] && disp_kernel="TRUE"

 local disp_kwipe="FALSE"
 [ ${WIPE_KERNEL_CONFIG} -eq 1 ] && disp_kwipe="TRUE"

 local disp_rootfs="FALSE"
 [ ${BUILD_ROOTFS} -eq 1 ] && disp_rootfs="TRUE"

 local disp_bbwipe="FALSE"
 [ ${WIPE_BUSYBOX_CONFIG} -eq 1 ] && disp_bbwipe="TRUE"

 local disp_genrfsimg="FALSE"
 [ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && disp_genrfsimg="TRUE"

 local disp_bkp="FALSE"
 [ "${SAVE_BACKUP_IMG_CONFIGS}" -eq 1 ] && disp_bkp="TRUE"

 local disp_run="FALSE"
 [ ${RUN_QEMU} -eq 1 ] && disp_run="TRUE"

 local MSG_CONFIG_VOLATILE="The settings you make now are volatile, i.e., they will take
effect for ONLY this run. Once completed, the default (build.config) settings resume.
To change settings permenantly, please edit the build.config file.

* Wiping out the kernel / busybox config:
- only has an effect when the corresponding build option is selected
- if selected and wipe, implies that you will lose your existing config, of course.
"

 local yad_dothis=$(yad --form \
   --field="Build Kernel (ver ${KERNELVER})":CHK \
   --field=" Wipe kernel config (Careful!*)":CHK \
   --field="Build Root Filesystem":CHK \
   --field=" Wipe busybox config (Careful!*)":CHK \
   --field="Generate Root Filesystem EXT4 image file":CHK \
   --field="Backup the kernel and root fs images and configs":CHK \
   --field="Run QEMU":CHK \
   ${disp_kernel} ${disp_kwipe} ${disp_rootfs} ${disp_bbwipe} \
   ${disp_genrfsimg} ${disp_bkp} ${disp_run} \
   --title="${PRJ_TITLE} : Configure this Run" \
   --center --width=${CAL_WIDTH} --on-top --no-escape \
   --text="<span foreground='blue'><i>${MSG_CONFIG_VOLATILE}</i></span>")

 BUILD_KERNEL=$(echo "${yad_dothis}" |awk -F"|" '{print $1}')
 #echo "gui :: BUILD_KERNEL = ${BUILD_KERNEL}"
 WIPE_KERNEL_CONFIG=$(echo "${yad_dothis}" |awk -F"|" '{print $2}')
 BUILD_ROOTFS=$(echo "${yad_dothis}" |awk -F"|" '{print $3}')
 WIPE_BUSYBOX_CONFIG=$(echo "${yad_dothis}" |awk -F"|" '{print $4}')
 GEN_EXT4_ROOTFS_IMAGE=$(echo "${yad_dothis}" |awk -F"|" '{print $5}')
 SAVE_BACKUP_IMG_CONFIGS=$(echo "${yad_dothis}" |awk -F"|" '{print $6}')
 RUN_QEMU=$(echo "${yad_dothis}" |awk -F"|" '{print $7}')

 # yad has the (rather unpleasant) side-effect of changing our build
 # variables to the strings "TRUE" or "FALSE"; we'd like it to be integer
 # values 1 or 0.
 # Rationalize the 'build variables' to integer values
 [ "${BUILD_KERNEL}" = "TRUE" ] && BUILD_KERNEL=1 || BUILD_KERNEL=0
 [ "${WIPE_KERNEL_CONFIG}" = "TRUE" ] && WIPE_KERNEL_CONFIG=1 || WIPE_KERNEL_CONFIG=0
 [ "${BUILD_ROOTFS}" = "TRUE" ] && BUILD_ROOTFS=1 || BUILD_ROOTFS=0
 [ "${WIPE_BUSYBOX_CONFIG}" = "TRUE" ] && WIPE_BUSYBOX_CONFIG=1 || WIPE_BUSYBOX_CONFIG=0
 [ "${GEN_EXT4_ROOTFS_IMAGE}" = "TRUE" ] && GEN_EXT4_ROOTFS_IMAGE=1 || GEN_EXT4_ROOTFS_IMAGE=0
 [ "${SAVE_BACKUP_IMG_CONFIGS}" = "TRUE" ] && SAVE_BACKUP_IMG_CONFIGS=1 || SAVE_BACKUP_IMG_CONFIGS=0
 [ "${RUN_QEMU}" = "TRUE" ] && RUN_QEMU=1 || RUN_QEMU=0

 display_current_config

} || {

  seals_menu_consolemode
  becho "
  Confirm your choices pl ::
"
  display_current_config

  echo
  get_yn_reply "Proceed? (if you say No, you can reenter choices)" y
  [ $? -eq 1 ] && seals_menu_consolemode
}

} # end config_setup()

#--------- c h e c k _ i n s t a l l e d _ p k g ----------------------
# TODO
#  + use superior checking func (fr CQuATS code)
#  - gather and install required packages
#  -
check_installed_pkg()
{
 report_progress

 which ${CXX}gcc > /dev/null 2>&1 || {
   FatalError "Cross toolchain does not seem to be valid! PATH issue? 
Tip: Install the cross toolchain first, update the build.config to reflect it and rerun.
Tip: (Less likely) This error can be thrown when you run the script with sudo (the
env vars are not setup. So run from a root shell where the PATH is correctly setup).
Aborting..."
 }

 check_deps_fatal "make qemu-system-arm mkfs.ext4"
 [ ${GUI_MODE} -eq 1 ] && check_deps_fatal "yad xrandr"

## TODO : the dpkg & rpm -qa are very time consuming!
## so do this only on 'first-time'.

 # For libncurses lib: have to take into account whether running on Ubuntu/Deb
 # or Fedora/RHEL/CentOS
 which dpkg > /dev/null 2>&1
 if [ $? -eq 0 ] ; then
  # Ubuntu/Debian
   dpkg -l |grep -q libncurses5-dev 2>/dev/null || {
     FatalError "The 'libncurses5-dev' package does not seem to be installed.
(Required for kernel config UI).
Pl install the package (with apt-get) & re-run.  Aborting..."
   }
 else
  if [ -f /etc/fedora-release ] || [ -f /etc/fedora ] ; then
  # Fedora/RHEL/CentOS - probably :)
  rpm -qa |grep -q ncurses-devel 2>/dev/null || {
     FatalError "The 'ncurses-devel' package does not seem to be installed.
(Required for kernel config UI).
Pl install the package (with dnf/yum/rpm) & re-run.  Aborting..."
   }
  fi
 fi

 # Terminal 'color' support?
 which tput > /dev/null 2>&1 || {
   COLOR=0
   wecho "tput does not seem to be installed, no color support..."
 } && {
   local numcolor=$(tput colors)
   [ ${numcolor} -ge 8 ] && COLOR=1
 }
} # end check_installed_pkg()
##----------------------------- Functions End -------------------------

testColor()
{
  ShowTitle "testing... KERNEL: Configure and Build [kernel ver ${KERNELVER}] now ..."
  #FatalError
  FatalError "Testing ; the libncurses5-dev dev library and headers does not seem to be installed."
  Echo "Echo : a quick test ..."
  decho "decho : a quick test ..."
  iecho "cecho : a quick test ..."
  aecho "aecho : a quick test ..."
  wecho "wecho : a quick test ..."
  fecho "wecho : a quick test ..."
  color_reset
}


### "main" here

is_gui_supported
[ $? -eq 1 ] && GUI_MODE=1 || GUI_MODE=0
# testing... if we pass '-c' on cmdline, force console mode
if [ $# -ge 1 -a "$1" = "-c" ] ; then
	GUI_MODE=0
fi
[ ${GUI_MODE} -eq 1 ] && echo "[+] Running in GUI mode.. (use '-c' option switch to run in console-only mode)" || echo "[+] Running in console mode.."
echo "[+] ${name}: initializing, pl wait ..."

#testColor
#exit 0

which tput >/dev/null 2>&1 && color_reset
unalias cp 2>/dev/null

TESTMODE=0
[ ${TESTMODE} -eq 1 ] && {
  FatalError "some issue blah ..."
  #config_setup
  exit 0
}

check_installed_pkg
[ ${GUI_MODE} -eq 1 ] && gui_init
#exit 0

###
# !NOTE!
# The script expects that these folders are pre-populated with 
# appropriate content, i.e., the source code for their resp projects:
# KERNEL_FOLDER  : kernel source tree
# BB_FOLDER      : busybox source tree
###
report_progress

check_folder_AIA ${STG}
check_folder_createIA ${ROOTFS}
check_folder_createIA ${IMAGES_FOLDER}
check_folder_createIA ${IMAGES_BKP_FOLDER}
check_folder_createIA ${CONFIGS_FOLDER}

config_setup

### Which of the functions below run depends on the
# config specified in the Build Config file!
# So just set it there man ...
###
[ ${BUILD_KERNEL} -eq 1 ] && {
  check_folder_AIA ${KERNEL_FOLDER}
  build_kernel
}
[ ${BUILD_ROOTFS} -eq 1 ] && {
  check_folder_AIA ${BB_FOLDER}
  build_rootfs
}
[ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && generate_rootfs_img_ext4
[ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && save_images_configs
[ ${RUN_QEMU} -eq 1 ] && run_qemu_SEALS

aecho "${MSG_EXITING}"
color_reset
exit 0
