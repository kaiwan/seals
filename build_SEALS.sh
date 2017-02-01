#!/bin/bash
#
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Author and Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# kaiwan -dot- billimoria -at- gmail -dot- com
# Project URL:
# https://github.com/kaiwan/seals
#
# A helper script designed to build:
# a custom kernel + root filesystem for an "embedded" QEMU/ARM Linux system.
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
# License: GPL v2

name=$(basename $0)

#############################
# ${BUILD_CONFIG_FILE} : a configuration script that asks the user for and sets up
# folder locations, toolchain PATH, any other configs as required.
#############################
BUILD_CONFIG_FILE=./build.config
source ${BUILD_CONFIG_FILE} || {
	echo "$name: source failed! ${BUILD_CONFIG_FILE} missing or invalid?"
	exit 1
}
source ./common.sh || {
	echo "$name: source failed! ./common.sh missing or invalid?"
	exit 1
}

### "Globals"
PRJ_TITLE="SEALS: Simple Embedded ARM Linux System"
PSWD_IF_REQD="If asked, please enter password"
STEPS=5
CPU_CORES=$(getconf -a|grep _NPROCESSORS_ONLN|awk '{print $2}')
[ -z ${CPU_CORES} ] && CPU_CORES=2

TESTMODE=0
[ ${TESTMODE} -eq 1 ] && {
  mysudo "desc of mysudo ..." "/bin/cp build.config /"
  exit 0
}


##-------------------- Functions Start --------------------------------

#------------------ b u i l d _ k e r n e l ---------------------------
build_kernel()
{
cd ${KERNEL_FOLDER} || exit 1
ShowTitle "Building kernel ver ${KERNELVER} now ..."

if [ "${WIPE_KERNEL_CONFIG}" = "y" ]; then
	ShowTitle "Kernel config for ARM ${ARM_PLATFORM_STR} platform:"
	make ARCH=arm ${ARM_PLATFORM}_defconfig || {
	   FatalError "Kernel config for ARM ${ARM_PLATFORM_STR} platform failed.."
	}
fi

echo "[Optional] Kernel Manual Configuration:
Edit the kernel config if required, Save & Exit...
 Tip: you can browse notes on this here: doc/kernel_config.txt"
Prompt " "

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

#echo "--- # detected CPU cores is ${CPU_CORES}" ; read
CPU_OPT=$((${CPU_CORES}*2))

#Prompt
echo "Doing: make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all"
time make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all || {
  FatalError "Kernel build failed! Aborting ..."
}

[ ! -f arch/arm/boot/zImage ] && {
  FatalError "Kernel build problem? image file zImage not existing!?? Aborting..."
}
ls -lh arch/arm/boot/zImage
cp -u ${KERNEL_FOLDER}/arch/arm/boot/zImage ${IMAGES_FOLDER}/
echo "... and done."
cd ${TOPDIR}
} # end build_kernel()

#--------------- b u i l d _ c o p y _ b u s y b o x ------------------
build_copy_busybox()
{
cd ${BB_FOLDER} || exit 1

ShowTitle "Building Busybox now ... [$(basename ${BB_FOLDER})]"
echo " [sanity chk: ROOTFS=${ROOTFS}]"
# safety check!
if [ -z "${ROOTFS}" ]; then
	FatalError "SEALS: ROOTFS has dangerous value of null or '/'. Aborting..."
fi

if [ "${WIPE_BUSYBOX_CONFIG}" = "y" ]; then
	ShowTitle "BusyBox default config:"
	make ARCH=arm CROSS_COMPILE=${CXX} defconfig
fi

echo "Edit the BusyBox config if required, Save & Exit..."
Prompt " "

USE_QT=n   # make 'y' to use a GUI Qt configure environment
if [ ${USE_QT} = "y" ]; then
	make ARCH=arm CROSS_COMPILE=${CXX} xconfig
else
	make ARCH=arm CROSS_COMPILE=${CXX} menuconfig
fi

ShowTitle "BusyBox Build:"
make -j${CPU_CORES} ARCH=arm CROSS_COMPILE=${CXX} install

mysudo "SEALS Build:Step 1 of ${STEPS}: Copying of required busybox files. ${PSWD_IF_REQD}" \
 cp -af ${BB_FOLDER}/_install/* ${ROOTFS}/ || {
  FatalError "Copying required folders from busybox _install/ failed! 
 [Tip: Ensure busybox has been successfully built]. Aborting..."
}
echo "SEALS Build: busybox files copied across successfully ..."
} # end build_copy_busybox()

#---------- s e t u p _ e t c _ i n _ r o o t f s ---------------------
setup_etc_in_rootfs()
{
echo "SEALS Build: Manually generating required SEALS rootfs /etc files ..."
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
echo "/etc/init.d/rcS running now ..."

/bin/mount -a
/bin/mount -o remount,rw /    # remount / as rw

# networking
ifconfig eth0 192.168.2.100 netmask 255.255.255.0 up
# misc
# guarantee all printk's appear on console device
echo "8 4 1 7" > /proc/sys/kernel/printk
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
#------------- Shlibs..
echo "SEALS Build: copying across shared objects, etc to SEALS /lib /sbin /usr ..."

#ARMLIBS=${CXX_LOC}/arm-none-linux-gnueabi/libc/lib/
ARMLIBS=${CXX_LOC}/arm-none-linux-gnueabi/libc
if [ ! -d ${ARMLIBS} ]; then
	cd ${TOPDIR}
	FatalError "Toolchain shared library locations invalid? Aborting..."
fi

# Quick solution: just copy _all_ the shared libraries, etc from the toolchain into the rfs/lib

mysudo "SEALS Build:Step 2 of ${STEPS}: [SEALS rootfs]:setup of library objects. ${PSWD_IF_REQD}" \
  cp -a ${ARMLIBS}/lib/* ${ROOTFS}/lib || {
   FatalError "Copying required libs [/lib] from toolchain failed!"
}
mysudo "SEALS Build:Step 3 of ${STEPS}: [SEALS rootfs]:setup of /sbin. ${PSWD_IF_REQD}" \
  cp -a ${ARMLIBS}/sbin/* ${ROOTFS}/sbin || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
}
mysudo "SEALS Build:Step 4 of ${STEPS}: [SEALS rootfs]:setup of /usr. ${PSWD_IF_REQD}" \
  cp -a ${ARMLIBS}/usr/* ${ROOTFS}/usr || {
   FatalError "Copying required libs [/sbin] from toolchain failed!"
}
  # RELOOK: 
  # $ ls rootfs/usr/
  # bin/  include/  lib/  libexec/  sbin/  share/
  # $ 
  # usr/include - not really required?

# /lib/modules/`uname -r` required for rmmod to function
local KDIR=$(echo ${KERNELVER} | cut -d'-' -f2)
# for 'rmmod'
mkdir -p ${ROOTFS}/lib/modules/${KDIR} || FatalError "rmmod setup failure!"
} # end setup_lib_in_rootfs

#------ s e t u p _ d e v _ i n _ r o o t f s -------------------------
setup_dev_in_rootfs()
{
#---------- Device Nodes [static only]
echo "SEALS Build: Manually generating required Device Nodes in /dev ..."
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
mysudo "SEALS Build:Step 5 of ${STEPS}: [SEALS rootfs]:setup of device nodes. ${PSWD_IF_REQD}" \
  ${ROOTFS}/dev/mkdevtmp.sh || {
   rm -f mkdevtmp.sh
   FatalError "Setup of device nodes failed!"
}
rm -f mkdevtmp.sh
} # end setup_dev_in_rootfs

#---------- r o o t f s _ x t r a s -----------------------------------
rootfs_xtras()
{
# To be copied into the RFS..any special cases
# strace, tcpdump, gdb[server], misc scripts (strace, gdb copied from buildroot build)
if [ -d ${TOPDIR}/xtras ]; then
	echo "SEALS Build: Copying 'xtras' (goodies!) into the root filesystem..."
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
# First reset the 'rootfs' staging area so that regular user can update
mysudo "SEALS Build: reset SEALS root fs. ${PSWD_IF_REQD}" \
 chown -R ${LOGNAME}:${LOGNAME} ${ROOTFS}/*

#---------Generate necessary pieces for the rootfs
build_copy_busybox
setup_etc_in_rootfs
setup_lib_in_rootfs
setup_dev_in_rootfs
rootfs_xtras

mysudo "SEALS Build: enable final setup of SEALS root fs. ${PSWD_IF_REQD}" \
  chown -R root:root ${ROOTFS}/* || {
   FatalError "SEALS Build: chown on rootfs/ failed!"
}

cd ${TOPDIR}/
ShowTitle "Done!"
ls -l ${ROOTFS}/
local RFS_ACTUAL_SZ_MB=$(du -ms ${ROOTFS}/ |awk '{print $1}')
echo "SEALS root fs: actual size = ${RFS_ACTUAL_SZ_MB} MB"
} # end build_rootfs()

generate_rootfs_img_ext4()
{
cd ${ROOTFS} || exit 1

ShowTitle "SEALS Build: Generating ext4 image for root fs now:"

# RFS should be the final one ie the one in images/
local RFS=${IMAGES_FOLDER}/rfs.img
local MNTPT=/mnt/tmp
local RFS_SZ_MB=256  #64
local COUNT=$((${RFS_SZ_MB}*256))  # for given blocksize (bs) of 4096

[ ! -d ${MNTPT} ] && {
  mysudo "SEALS Build: root fs image generation: enable mount dir creation. ${PSWD_IF_REQD}" \
   mkdir -p ${MNTPT}
}
# If RFS does not exist, create from scratch.
# If it does exist, just loop mount and update.
if [ ! -f ${RFS} ]; then
  echo "SEALS Build: *** Re-creating raw RFS image file now *** [dd, mkfs.ext4]"
  dd if=/dev/zero of=${RFS} bs=4096 count=${COUNT}
  mysudo "SEALS Build: root fs image generation: enable mkfs. ${PSWD_IF_REQD}" \
   mkfs.ext4 -F -L qemu_rootfs_SEALS ${RFS} || FatalError "mkfs failed!"
fi

# Keep FORCE_RECREATE_RFS to 0 by default!!
# Alter at your Own Risk!!
local FORCE_RECREATE_RFS=0

sync
mysudo "SEALS Build: root fs image generation: enable umount. ${PSWD_IF_REQD}" \
umount ${MNTPT} 2> /dev/null
mysudo "SEALS Build: root fs image generation: enable mount. ${PSWD_IF_REQD}" \
 mount -o loop ${RFS} ${MNTPT} || {
  echo "### $name: !WARNING! Loop mounting rootfs image file Failed! ###"
  if [ ${FORCE_RECREATE_RFS} -eq 0 ]; then
    echo "-- Aborting this function! --"
	echo "To *force* root filesystem creation by deleting current RFS, set"
	echo "the FORCE_RECREATE_RFS in the script to 1."
	return
  else
    echo
    echo "### $name: !WARNING! FORCE_RECREATE_RFS flag is non-zero! Now *deleting* current RFS image and re-creating it..."
    echo
    rm -f ${RFS} 2>/dev/null
    #dd if=/dev/zero of=${RFS} bs=4096 count=16384
    dd if=/dev/zero of=${RFS} bs=4096 count=${COUNT}
    mysudo "SEALS Build: root fs image generation: enable mkfs (in force_recreate_rfs). ${PSWD_IF_REQD}" \
     mkfs.ext4 -F -L qemu_rootfs_SEALS ${RFS} || exit 1
    mysudo "SEALS Build: root fs image generation: enable mount (in force_recreate_rfs). ${PSWD_IF_REQD}" \
     mount -o loop ${RFS} ${MNTPT} || {
	  FatalError " !!! The loop mount RFS failed Again !!! Wow. Too bad. See ya :-/"
	}
  fi
 }

echo " Now copying across rootfs data to ${RFS} ..."
mysudo "SEALS Build: root fs image generation: enable copying into SEALS root fs image. ${PSWD_IF_REQD}" \
 cp -au ${ROOTFS}/* ${MNTPT}
mysudo "SEALS Build: root fs image generation: enable unmount. ${PSWD_IF_REQD}" \
 umount ${MNTPT}
sync
ls -lh ${RFS}
echo "... and done."
cd ${TOPDIR}
}

# fn to place final images in images/ and save imp config files as well...
save_images_configs()
{
ShowTitle "Backing up kernel and busybox images and config files now (as necessary) ..."
cd ${TOPDIR}
unalias cp 2>/dev/null
cp -afu ${IMAGES_FOLDER}/ ${IMAGES_BKP_FOLDER} # backup!
cp -u ${KERNEL_FOLDER}/arch/arm/boot/zImage ${IMAGES_FOLDER}/
cp ${KERNEL_FOLDER}/.config ${CONFIGS_FOLDER}/kernel_config
cp ${BB_FOLDER}/.config ${CONFIGS_FOLDER}/busybox_config
echo " ... and done."
}

report_config()
{
 local msg1=""
 local msg2=""
 local gccver=$(arm-none-linux-gnueabi-gcc --version |head -n1 |cut -f2- -d" ")

 msg1="Config file : ${BUILD_CONFIG_FILE}
Config name : ${CONFIG_NAME_STR}

Toolchain prefix : ${CXX}
Toolchain version: ${gccver}

Staging folder   : ${STG}

ARM CPU arch : ${ARM_CPU_ARCH}
ARM Platform : ${ARM_PLATFORM_STR}

Linux kernel to use            : ${KERNELVER}
Linux kernel codebase location : ${KERNEL_FOLDER}

Busybox to use            : ${BB_VER}
Busybox codebase location : ${BB_FOLDER}
"
 echo "${msg1}"
 zenity --question --title="${PRJ_TITLE}" --text="${msg1}" \
        --ok-label="Confirm" --cancel-label="Abort" 2>/dev/null
 [ $? -ne 0 ] && {
   echo "Aborting. Edit the config file ${BUILD_CONFIG_FILE} as required and re-run."
   exit 1
 }

 local s1="Build kernel?                                    N"
 [ ${BUILD_KERNEL} -eq 1 ] && s1="Build kernel?                                    Y"
 local s1_2=" Wipe kernel config?                             N"
 [ "${WIPE_KERNEL_CONFIG}" = "y" ] && s1_2=" Wipe kernel config?                     Y"
 local s2="Build root filesystem?                           N"
 [ ${BUILD_ROOTFS} -eq 1 ] && s2="Build root filesystem?                           Y"
 local s2_2=" Wipe busybox config?                            N"
 [ "${WIPE_BUSYBOX_CONFIG}" = "y" ] && s2_2=" Wipe busybox config?                   Y"
 local s3="Generate ext4 rootfs image?                      N"
 [ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && s3="Generate ext4 rootfs image?             Y"
 local s4="Save/Backup kernel/busybox images and config files? N"
 [ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && s4="Save/Backup kernel/busybox images and config files? Y"
 local s5="Run QEMU ARM emulator?                           N"
 [ ${RUN_QEMU} -eq 1 ] && s5="Run QEMU ARM emulator?                         Y"

 msg2="--------------------- Script Build Options ----------------------------
${s1}
${s1_2}
${s2}
${s2_2}
${s3}
${s4}
${s5}
"
 echo "${msg2}"
 zenity --question --title="${PRJ_TITLE}" --text="${msg2}" \
        --ok-label="Confirm" --cancel-label="Abort" 2>/dev/null
 [ $? -ne 0 ] && {
   echo "Aborting. Edit the config file ${BUILD_CONFIG_FILE} as required and re-run."
   exit 1
 }
}

#-------------- r u n _ q e m u _ S E A L S ---------------------------
run_qemu_SEALS()
{
cd ${TOPDIR} || exit 1

echo

# Run it!
if [ ${KGDB_MODE} -eq 0 ]; then

  SMP_EMU=""
  if [ ${SMP_EMU_MODE} -eq 1 ]; then
    # Using the "-smp n,sockets=n" QEMU options lets us emulate n processors!
    # (can do this with n=2 for the ARM Cortex-A9)
     SMP_EMU="-smp 2,sockets=2"
  fi

	ShowTitle "Running qmeu-system-arm now ..."
	echo "qemu-system-arm -m 256 -M ${ARM_PLATFORM_OPT} ${SMP_EMU} -kernel ${IMAGES_FOLDER}/zImage -drive file=${IMAGES_FOLDER}/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic"
	echo
	qemu-system-arm -m 256 -M ${ARM_PLATFORM_OPT} ${SMP_EMU} -kernel ${IMAGES_FOLDER}/zImage -drive file=${IMAGES_FOLDER}/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic
else
	# KGDB/QEMU cmdline
	#  -just add the '-S' option [freeze CPU at startup (use 'c' to start execution)] to qemu cmdline
	ShowTitle "Running qemu-system-arm in KGDB mode now ..."
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

	qemu-system-arm -M ${ARM_PLATFORM_OPT} -kernel ${IMAGES_FOLDER}/zImage -initrd ${IMAGES_FOLDER}/rootfs.img.gz -append "console=ttyAMA0 rdinit=/sbin/init" -nographic -gdb tcp::1234 -s -S
fi
echo "
... and done."
} # end run_qemu_SEALS()

check_installed_pkg()
{
 which zenity > /dev/null 2>&1 || {
   FatalError "The zenity package does not seem to be installed! Aborting..."
 }
 which make > /dev/null 2>&1 || {
   FatalError "The GNU 'make' package does not seem to be installed! Aborting..."
 }
 which qemu-system-arm > /dev/null 2>&1 || {
   FatalError "QEMU packages do net seem to be installed! Pl Install qemu-system-arm and qemu-kvm and re-run .."
 }
 which ${CXX}gcc > /dev/null 2>&1 || {
   FatalError "Cross toolchain does not seem to be valid! PATH issue? 
Tip: This error can be thrown when you run the script with sudo (the 
env vars are not setup. So run from a root shell where the PATH is correctly setup).
Aborting..."
 }
 which mkfs.ext4 > /dev/null 2>&1 || {
   FatalError "mkfs.ext4 does not seem to be installed. Aborting..."
 }
 dpkg -l |grep libncurses5-dev > /dev/null 2>&1 || {
   FatalError "The libncurses5-dev dev library and headers does not seem to be installed.
(Required for kernel config UI).
Pl install the libncurses5-dev package (with apt-get) & re-run.  Aborting..."
 }
}
##----------------------------- Functions End -------------------------


### "main" here

unalias cp 2>/dev/null
check_installed_pkg

###
# !NOTE!
# The script expects that these folders are pre-populated with 
# appropriate content, i.e., the source code for their resp projects:
# KERNEL_FOLDER  : kernel source tree
# BB_FOLDER      : busybox source tree
###
check_folder_AIA ${STG}
[ ${BUILD_KERNEL} -eq 1 ] && check_folder_AIA ${KERNEL_FOLDER}
[ ${BUILD_ROOTFS} -eq 1 ] && check_folder_AIA ${BB_FOLDER}

check_folder_createIA ${ROOTFS}
check_folder_createIA ${IMAGES_FOLDER}
check_folder_createIA ${IMAGES_BKP_FOLDER}
check_folder_createIA ${CONFIGS_FOLDER}

report_config

### Which of the functions below run depends on the
# config specified in the Build Config file!
# So just set it there man ...
###
[ ${BUILD_KERNEL} -eq 1 ] && build_kernel $@
[ ${BUILD_ROOTFS} -eq 1 ] && build_rootfs $@
[ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && generate_rootfs_img_ext4
[ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && save_images_configs
[ ${RUN_QEMU} -eq 1 ] && run_qemu_SEALS

echo "
${name}: all done, exiting."
exit 0
