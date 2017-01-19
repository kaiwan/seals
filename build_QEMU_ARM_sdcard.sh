#!/bin/bash
#
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# Project URL:
# https://github.com/kaiwan/seals
#
# A helper script designed to build:
# a custom kernel + root filesystem for an "embedded" QEMU/ARM Linux system.
#
# According to the ARM platform selected, it builds a:
# a) Linux 3.1.5  (or 2.6.28.10) kernel for ARM platform Versatile PB 
#    platform, cpu arch ARM v5  -OR-
# b) Linux 3.10.24 kernel for ARM platform Versatile Express (A9) 
#    platform, cpu arch ARM v7.
#
# This version is better than the first script (1build_QEMU_ARM.sh):
# besides the "usual" stuff, it populates the root filesystem with
# shared object libraries (from the toolchain) and minimal device nodes.
# 
# Very good References (by 'Balau'): 
#  Kernel: 
#    http://balau82.wordpress.com/2012/03/31/compile-linux-kernel-3-2-for-arm-and-emulate-with-qemu/
# [OLDer LINK]: http://balau82.wordpress.com/2010/03/22/compiling-linux-kernel-for-qemu-arm-emulator/
#  Busybox: http://balau82.wordpress.com/2010/03/27/busybox-for-arm-on-qemu/
#
# (c) Kaiwan N Billimoria <kaiwan -at- kaiwantech -dot- com>
# (c) kaiwanTECH
# GPL v2
# 

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

PRJ_TITLE="SEALS: Simple Embedded ARM Linux System"

# TODO : ugly: change this...
#---Check for "wipe_*" parameters
if [ $# -ne 2 ]; then
  FatalError \
"\n\Usage: $name   wipe_kernel_config    wipe_busybox_config\n\
 Use y/n for each wipe-config option above.\n\
 \n\
 Eg\n\
 ${name} n y\n\
 means: do Not wipe kernel config, do wipe busybox config.\n\
"
fi


##-------------------- Functions Start --------------------------------
build_kernel()
{
#---Check for "wipe_*" parameters
if [ $# -ne 2 ]; then
  FatalError \
"Usage: $name wipe_kernel_config wipe_busybox_config\n\
 Use y/n for each wipe-config option above.\n\
 Eg\n\
 ${name} n y\n\
 means: do Not wipe kernel config, do wipe busybox config.\n\
"
fi

p1=${1}
p2=${2}
#Prompt "Params = ${#} = p1 = $1 p2 = $2 : p = ${@}"
[ ${p1} = "y" -o ${p1} = "Y" ] && export WIPE_PREV_KERNEL_CONFIG=y || export WIPE_PREV_KERNEL_CONFIG=n
[ ${p2} = "y" -o ${p2} = "Y" ] && export WIPE_PREV_BB_CONFIG=y || export WIPE_PREV_BB_CONFIG=n
echo "WIPE_PREV_KERNEL_CONFIG = ${WIPE_PREV_KERNEL_CONFIG} WIPE_PREV_BB_CONFIG = ${WIPE_PREV_BB_CONFIG}"
WIPE_PARAMS_CHECKED=1

cd ${KERNEL_FOLDER} || exit 1
ShowTitle "Building kernel ver ${KERNELVER} now ..."

if [ $WIPE_PREV_KERNEL_CONFIG = "y" ]; then
	ShowTitle "Kernel config for ARM ${ARM_PLATFORM_STR} platform:"
	make ARCH=arm ${ARM_PLATFORM}_defconfig || {
	   FatalError "Kernel config for ARM ${ARM_PLATFORM_STR} platform failed.."
	}
fi

ShowTitle "[Optional] Kernel manual Configuration:"
echo "Edit the kernel config if required, Save & Exit..."
echo
echo "Required & Recommended kernel configs:
 General Setup:
      [*] Kernel .config support
      [*]   Enable access to .config through /proc/config.gz
	  [*] Control Group Support --->
	       --- Control Group support                                                            
              [*]   Example debug cgroup subsystem                                                 
              [ ]   Freezer cgroup subsystem                                                       
              [ ]   Device controller for cgroups                                                  
              [*]   Cpuset support                                                                 
              [*]     Include legacy /proc/<pid>/cpuset file                                       
              [*]   Simple CPU accounting cgroup subsystem                                         
              [*]   Resource counters                                                              
              [*]     Memory Resource Controller for Control Groups 
                   [ ]       Memory Resource Controller Swap Extension                                  
              [ ]       Memory Resource Controller Kernel Memory accounting                        
              [ ]   Enable perf_event per-cpu per-container group (cgroup) monitoring              
              [*]   Group CPU scheduler  --->                                                      
              [ ]   Block IO controller           
      [*] KProbes
 -*- Enable the block layer  --->
       [*]   Support for large (2TB+) block devices and files     <<see note below>>  [MANDATORY]
 Kernel Features
      [ ] Tickless System (Dynamic Ticks)                 [RECOMMENDED]
      [*] Use the ARM EABI to compile the kernel          [MANDATORY]
          [*]   Allow old ABI binaries to run with this kernel (EXPERIMENTAL) (NEW)   [MANDATORY]
Filesystems
	 <*> The Extended 4 (ext4) filesystem                 [MANDATORY]
     [*]   Ext4 extended attributes (NEW)
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
          [*]   KGDB_KDB: include kdb frontend for kgdb (NEW)
"
echo "
MUST enable CONFIG_LBDAF (Block) to remount / as rw : 
...
The ext4 filesystem requires that this feature be enabled in order to support 
filesystems that have the huge_file feature enabled.  Otherwise, it will 
refuse to mount in the read-write mode any filesystems that use the huge_file 
feature, which is enabled by default by mke2fs.ext4.  ...  
"
echo "
The actual fact is that without the LBDAF setting, we cannot mount the ext4 
rootfs as read-write!
ARM # mount -o remount,rw /
EXT4-fs (mmcblk0): Filesystem with huge files cannot be mounted RDWR without CONFIG_LBDAF
...
"
echo "<< A suggestion: The above help screen will disappear once the kernel menu config 
menu comes up.
So, if you'd like to, copy/paste it into an editor... >>
"
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

CPU_CORES=$(getconf -a|grep _NPROCESSORS_ONLN|awk '{print $2}')
[ -z ${CPU_CORES} ] && CPU_CORES=2
#echo "--- # detected CPU cores is ${CPU_CORES}" ; read
CPU_OPT=$((${CPU_CORES}*2))

#Prompt
echo "Doing: make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all"
time make -j${CPU_OPT} ARCH=arm CROSS_COMPILE=${CXX} all || {
  FatalError "Kernel build failed! Aborting ..."
}

ShowTitle "Done!"
[ ! -f arch/arm/boot/zImage ] && {
  FatalError "Kernel build problem? image file zImage not existing!?? Aborting..."
}
ls -l arch/arm/boot/zImage
cd ${TOPDIR}
}

#
# NOTE: The root filesystem is now populated in the ${ROOTFS} folder under ${TOPDIR}
#
build_rootfs()
{
###---If not done already, check for "wipe_*" parameters
if [ ${WIPE_PARAMS_CHECKED} -eq 0 ]; then
 if [ $# -ne 2 ]; then
   FatalError \
"Usage: $name wipe_kernel_config wipe_busybox_config\n\
 Use y/n for each wipe-config option above.\n\
 Eg\n\
 ${name} n y\n\
 means: do Not wipe kernel config, do wipe busybox config.\n\
"
 fi

 p1=${1}
 p2=${2}
 #Prompt "Params = ${#} = p1 = $1 p2 = $2 : p = ${@}"
 [ ${p1} = "y" -o ${p1} = "Y" ] && export WIPE_PREV_KERNEL_CONFIG=y || export WIPE_PREV_KERNEL_CONFIG=n
 [ ${p2} = "y" -o ${p2} = "Y" ] && export WIPE_PREV_BB_CONFIG=y || export WIPE_PREV_BB_CONFIG=n
 echo "WIPE_PREV_KERNEL_CONFIG = ${WIPE_PREV_KERNEL_CONFIG} WIPE_PREV_BB_CONFIG = ${WIPE_PREV_BB_CONFIG}"
 WIPE_PARAMS_CHECKED=1
fi
###

cd ${BB_FOLDER} || exit 1

ShowTitle "Building Busybox now ..."
echo "+++ ROOTFS=$ROOTFS"
# safety check!
if [ -z ${ROOTFS} ]; then
	echo "ROOTFS has dangerous value of null or '/'. Aborting..."
	exit 1
fi

if [ $WIPE_PREV_BB_CONFIG = "y" ]; then
	ShowTitle "BusyBox default config:"
	make ARCH=arm CROSS_COMPILE=${CXX} defconfig

	ShowTitle "[Optional] BusyBox manual Configuration:"
	echo "Edit the BusyBox config if required, Save & Exit..."
	echo
	echo "[Enter] to continue..."
	read

	USE_QT=n   # make 'y' to use a GUI Qt configure environment
	if [ ${USE_QT} = "y" ]; then
		make ARCH=arm CROSS_COMPILE=${CXX} xconfig
	else
		make ARCH=arm CROSS_COMPILE=${CXX} menuconfig
	fi

	ShowTitle "BusyBox Build:"
	make -j${CPU_CORES} ARCH=arm CROSS_COMPILE=${CXX} install
fi

# Now copy the relevant folders to the rootfs location
unalias cp 2>/dev/null
cp -af ${BB_FOLDER}/_install/* ${ROOTFS}/ || {
 FatalError "Copying required folders from busybox _install/ failed! 
[Tip: Ensure busybox has been successfully built]. Aborting..."
}

#---------Generate other necessary pieces for the rootfs
ShowTitle "BusyBox Build: Manually generating required /etc files..."
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
echo "Done.."

#------------- Shlibs..
ShowTitle "BusyBox Build: Manually copying across shared objects /lib files..."

ARMLIBS=${CXX_LOC}/arm-none-linux-gnueabi/libc/lib/
if [ ! -d ${ARMLIBS} ]; then
	cd ${TOPDIR}
	FatalError "Toolchain shared library location invalid? Aborting..."
fi

# Quick solution: just copy _all_ the shared libraries from the toolchain into the rfs/lib
cp -a ${ARMLIBS}/* ${ROOTFS}/lib

# /lib/modules/`uname -r` required for rmmod to function
KDIR=$(echo $KERNELVER | cut -d'-' -f2)
mkdir -p ${ROOTFS}/lib/modules/${KDIR}  # for 'rmmod'

#---------- Device Nodes [static only]
ShowTitle "BusyBox Build: Manually generating required Device Nodes in /dev ..."
cd ${ROOTFS}/dev
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

# recommended slinks
ln -s /proc/self/fd fd
ln -s /proc/self/fd/0 stdin
ln -s /proc/self/fd/1 stdout
ln -s /proc/self/fd/2 stderr
#---------------------

#----------------------------------------------------------------
# To be copied into the RFS..any special cases
# strace, tcpdump, gdb[server], misc scripts (strace, gdb copied from buildroot build)
if [ -d ${TOPDIR}/xtras ]; then
	ShowTitle "Copying 'xtras' (goodies!) into the root filesystem..."
	cd ${TOPDIR}/xtras
	cp strace ${ROOTFS}/usr/bin
	cp tcpdump ${ROOTFS}/usr/sbin

	# for gdb on-board, we need libncurses* & libz* (for gdb v7.1)
	mkdir -p ${ROOTFS}/usr/lib
	cp -a libncurses* libz* ${ROOTFS}/usr/lib
	cp gdb* ${ROOTFS}/usr/bin

	# misc
	cp 0setup ${ROOTFS}/
	chmod +x procshow.sh
	#cp common.sh procshow.sh pidshow.sh ${ROOTFS}/${MYPRJ}

	# useful for k debug stuff
	cp ${KERNEL_FOLDER}/System.map ${ROOTFS}/
fi
#----------------------------------------------------------------

cd ${TOPDIR}/
ShowTitle "Done!"
ls -l ${ROOTFS}/
}

generate_rootfs_img_ext4()
{
cd ${ROOTFS} || exit 1

ShowTitle "Generating ext4 image now:"

# RFS should be the final one ie the one in images/
RFS=${IMAGES_FOLDER}/rfs.img
MNTPT=/mnt/tmp
RFS_SZ_MB=64

mkdir -p ${MNTPT} 2> /dev/null
# If RFS does not exist, create from scratch.
# If it does exist, just loop mount and update.
if [ ! -f ${RFS} ]; then
  #rm -f ${RFS} 2>/dev/null
  echo "*** Re-creating raw RFS image file now *** [dd, mkfs.ext4]"
  dd if=/dev/zero of=${RFS} bs=4096 count=16384
  mkfs.ext4 -F -L qemu_rootfs_knb ${RFS} || exit 1
fi

# Keep FORCE_RECREATE_RFS to 0 by default!!
# Alter at your Own Risk!!
FORCE_RECREATE_RFS=0

sync
umount ${MNTPT} 2> /dev/null
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
    dd if=/dev/zero of=${RFS} bs=4096 count=16384
    mkfs.ext4 -F -L qemu_rootfs_knb ${RFS} || exit 1
    mount -o loop ${RFS} ${MNTPT} || {
	  echo " !!! The loop mount RFS failed Again !!! Wow. Too bad. See ya :-/"
	  return
	}
  fi
 }

echo " Copying across rootfs data to ${RFS} ..."
cp -au ${ROOTFS}/* ${MNTPT}
umount ${MNTPT}
sync

ls -l ${RFS}
cd ${TOPDIR}
}

# fn to place final images in images/ and save imp config files as well...
save_images_configs()
{
ShowTitle "Saving and Backing up kernel/busybox images and config files now..."
cd ${TOPDIR}
unalias cp 2>/dev/null
cp -afu ${IMAGES_FOLDER}/ ${IMAGES_BKP_FOLDER} # backup!

[ ${BUILD_KERNEL} -eq 1 ] && {
  cp -u ${KERNEL_FOLDER}/arch/arm/boot/zImage ${IMAGES_FOLDER}/
  #cp ${TOPDIR}/rfs.img ${IMAGES_FOLDER}/
  ls -lt ${IMAGES_FOLDER}/

  cp ${KERNEL_FOLDER}/.config ${CONFIGS_FOLDER}/kernel_config
}
[ ${BUILD_ROOTFS} -eq 1 ] && {
  cp ${BB_FOLDER}/.config ${CONFIGS_FOLDER}/busybox_config
}
}

report_config()
{
 local msg1=""
 local msg2=""
 #grep "CONFIG_NAME_STR" ${BUILD_CONFIG_FILE} |awk -F"\"" '{print $2}'

 msg1="
-----------------------------------------------------------------------
Config file : ${BUILD_CONFIG_FILE}
Config name : ${CONFIG_NAME_STR}

Toolchain prefix : ${CXX}
Staging folder   : ${STG}

ARM CPU arch : ${ARM_CPU_ARCH}
ARM Platform : ${ARM_PLATFORM_STR}

Linux kernel to use            : ${KERNELVER}
Linux kernel codebase location : ${KERNEL_FOLDER}
-----------------------------------------------------------------------
"
 echo "${msg1}"
 #zenmsg "${PRJ_TITLE}" "${msg1}" "Next"
 zenity --question --title="${PRJ_TITLE}" --text="${msg1}" \
        --ok-label="Confirm" --cancel-label="Abort" 2>/dev/null
 [ $? -ne 0 ] && {
   echo "Aborting. Edit the config file ${BUILD_CONFIG_FILE} as required and retry."
   exit 1
 }

 local s1="Build kernel?                                      N"
 [ ${BUILD_KERNEL} -eq 1 ] && s1="Build kernel?                                      Y"
 local s2="Build root filesystem?                             N"
 [ ${BUILD_ROOTFS} -eq 1 ] && s2="Build root filesystem?                             Y"
 local s3="Generate ext4 rootfs image?                        N"
 [ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && s3="Generate ext4 rootfs image?               Y"
 local s4="Save/Backup kernel/busybox images and config files?     N"
 [ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && s4="Save/Backup kernel/busybox images and config files?     Y"
 local s5="Run QEMU ARM emulator?                             N"
 [ ${RUN_QEMU} -eq 1 ] && s5="Run QEMU ARM emulator?                             Y"

 msg2="--------------------- Script Build Options ----------------------------
${s1}
${s2}
${s3}
${s4}
${s5}
"
 echo "${msg2}"
 #zenmsg "${PRJ_TITLE}" "${msg2}" "Next"
 zenity --question --title="${PRJ_TITLE}" --text="${msg2}" \
        --ok-label="Confirm" --cancel-label="Abort" 2>/dev/null
 [ $? -ne 0 ] && {
   echo "Aborting. Edit the config file ${BUILD_CONFIG_FILE} as required and retry."
   exit 1
 }
}

run_it()
{
cd ${TOPDIR} || exit 1

#echo "----------------------------------------------------------------------"
#echo "Build done. Press [Enter] to run QEMU-ARM-Linux system, ^C to abort..."
#echo "----------------------------------------------------------------------"
#read

echo

# Run it!
if [ ${KGDB_MODE} -eq 0 ]; then

  SMP_EMU=""
  if [ ${SMP_EMU_MODE} -eq 1 ]; then
    # Using the "-smp n,sockets=n" QEMU options lets us emulate n processors!
    # (can do this with n=2 for the ARM Cortex-A9)
     SMP_EMU="-smp 2,sockets=2"
  fi

	ShowTitle "Running qmeu-system-arm now!"
	echo "qemu-system-arm -m 256 -M ${ARM_PLATFORM_OPT} ${SMP_EMU} -kernel ${IMAGES_FOLDER}/zImage -drive file=${IMAGES_FOLDER}/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic"
	echo
	qemu-system-arm -m 256 -M ${ARM_PLATFORM_OPT} ${SMP_EMU} -kernel ${IMAGES_FOLDER}/zImage -drive file=${IMAGES_FOLDER}/rfs.img,if=sd -append "console=ttyAMA0 root=/dev/mmcblk0 init=/sbin/init" -nographic
	 # rm 'root=/dev/ram' ; not really necessary as we always use a ramdisk & never a real rootfs..
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

	qemu-system-arm -M ${ARM_PLATFORM_OPT} -kernel ${IMAGES_FOLDER}/zImage -initrd ${IMAGES_FOLDER}/rootfs.img.gz -append "console=ttyAMA0 rdinit=/sbin/init" -nographic -gdb tcp::1234 -s -S
	 # rm 'root=/dev/ram' ; not really necessary as we always use a ramdisk & never a real rootfs..
fi
}

check_installed_pkg()
{
 which zenity > /dev/null 2>&1 || {
   FatalError "The zenity package does not seem to be installed! Aborting..."
 }
 which make > /dev/null 2>&1 || {
   FatalError "The GNU 'make' package does not seem to be installed! Aborting..."
 }
 which qemu-system-arm > /dev/null 2>&1 || {
   FatalError "QEMU packages do net seem to be installed! Pl Install qemu-system-arm and qemu-kvm and retry.."
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
Pl install the libncurses5-dev package (with apt-get) & retry.  Aborting..."
 }

 echo 
 echo "Verify toolchain :: "
 ${CXX}gcc --version
 Prompt "Is the above gcc ver, rather, toolchain ver, correct?"

 #ShowTitle "Using this config :: ${CONFIG_NAME_STR}"
}
##----------------------------- Functions End -------------------------

### "main" here

check_root_AIA
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
[ ${BUILD_ROOTFS} -eq 1 ] &&check_folder_AIA ${BB_FOLDER}

check_folder_createIA ${ROOTFS}
check_folder_createIA ${IMAGES_FOLDER}
check_folder_createIA ${IMAGES_BKP_FOLDER}
check_folder_createIA ${CONFIGS_FOLDER}

report_config
#exit 0

### Which of the functions below run depends on the
# config specified in the Build Config file!
# So just set it there man ...
###
[ ${BUILD_KERNEL} -eq 1 ] && build_kernel $@
[ ${BUILD_ROOTFS} -eq 1 ] && build_rootfs $@
[ ${GEN_EXT4_ROOTFS_IMAGE} -eq 1 ] && generate_rootfs_img_ext4
[ ${SAVE_BACKUP_IMG_CONFIGS} -eq 1 ] && save_images_configs
[ ${RUN_QEMU} -eq 1 ] && run_it
